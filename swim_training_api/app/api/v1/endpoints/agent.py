"""Swimming Coach Agent — API 엔드포인트

POST /agent/chat — SSE 스트리밍 응답
"""

import asyncio
import json
import logging
from typing import Optional, Union

from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field
from langchain_core.messages import HumanMessage, AIMessage

from app.agent.graph import get_graph
from app.agent.state import AgentState

logger = logging.getLogger(__name__)


def _extract_text(content: Union[str, list, None]) -> str:
    """AIMessage.content가 str 또는 list일 수 있으므로 안전하게 문자열로 변환"""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for block in content:
            if isinstance(block, str):
                parts.append(block)
            elif isinstance(block, dict) and "text" in block:
                parts.append(block["text"])
        return "".join(parts)
    return str(content) if content is not None else ""

router = APIRouter(prefix="/agent", tags=["agent"])


class ChatRequest(BaseModel):
    message: str = Field(..., description="사용자 메시지")
    user_id: Optional[str] = Field(None, description="Firebase UID")
    chat_history: Optional[list[dict]] = Field(
        default=None,
        description="이전 대화 히스토리 [{role, content}, ...]",
    )


class ChatResponse(BaseModel):
    response: str = Field(..., description="Agent 응답 텍스트")
    tool_calls: Optional[list[dict]] = Field(
        default=None, description="사용된 Tool 목록"
    )


@router.post("/chat")
async def agent_chat(request: ChatRequest):
    """Agent와 대화 — 일반 JSON 응답"""
    try:
        graph = get_graph()

        # 대화 히스토리 구성
        messages = []
        if request.chat_history:
            for msg in request.chat_history[-10:]:  # 최근 10턴만
                role = msg.get("role", "")
                content = msg.get("content", "")
                if role == "user":
                    messages.append(HumanMessage(content=content))
                elif role == "assistant":
                    messages.append(AIMessage(content=content))

        messages.append(HumanMessage(content=request.message))

        # Agent 상태 초기화
        initial_state: AgentState = {
            "messages": messages,
            "user_id": request.user_id,
            "user_profile": None,
            "workout_history": None,
            "current_intent": None,
            "generated_program": None,
            "tool_results": None,
        }

        # 그래프 실행
        result = await graph.ainvoke(initial_state)

        # 마지막 AI 메시지 추출
        ai_messages = [
            m for m in result["messages"]
            if isinstance(m, AIMessage) and m.content
        ]

        if not ai_messages:
            raise HTTPException(status_code=500, detail="Agent가 응답을 생성하지 못했습니다.")

        final_response = _extract_text(ai_messages[-1].content)

        # 사용된 Tool 정보 수집
        used_tools = []
        for m in result["messages"]:
            if isinstance(m, AIMessage) and hasattr(m, "tool_calls") and m.tool_calls:
                for tc in m.tool_calls:
                    used_tools.append({
                        "name": tc.get("name", ""),
                        "args": tc.get("args", {}),
                    })

        return ChatResponse(
            response=final_response,
            tool_calls=used_tools if used_tools else None,
        )

    except Exception as e:
        logger.error(f"Agent 오류: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Agent 오류: {str(e)}")


@router.post("/chat/stream")
async def agent_chat_stream(request: ChatRequest):
    """Agent와 대화 — SSE 스트리밍 응답"""

    async def event_generator():
        try:
            graph = get_graph()

            messages = []
            if request.chat_history:
                for msg in request.chat_history[-10:]:
                    role = msg.get("role", "")
                    content = msg.get("content", "")
                    if role == "user":
                        messages.append(HumanMessage(content=content))
                    elif role == "assistant":
                        messages.append(AIMessage(content=content))

            messages.append(HumanMessage(content=request.message))

            initial_state: AgentState = {
                "messages": messages,
                "user_id": request.user_id,
                "user_profile": None,
                "workout_history": None,
                "current_intent": None,
                "generated_program": None,
                "tool_results": None,
            }

            # ── Keepalive: iOS는 60초 이상 데이터 없으면 연결을 끊음.
            #    asyncio.Queue로 이벤트를 수신하되, 20초마다 SSE comment 전송.
            _KEEPALIVE_INTERVAL = 20  # seconds
            queue: asyncio.Queue = asyncio.Queue(maxsize=200)

            async def _fill_queue():
                try:
                    async for ev in graph.astream_events(initial_state, version="v2"):
                        await queue.put(("event", ev))
                except Exception as e:
                    await queue.put(("error", e))
                finally:
                    await queue.put(("done", None))

            producer_task = asyncio.create_task(_fill_queue())

            suppress_tokens = False  # generate_program 시작 시점부터 LLM 토큰 차단
            has_streamed_text = False  # 이미 텍스트를 클라이언트에 전송했는지 추적

            try:
                while True:
                    try:
                        kind_tag, payload = await asyncio.wait_for(
                            queue.get(), timeout=_KEEPALIVE_INTERVAL
                        )
                    except asyncio.TimeoutError:
                        # 연결 유지용 SSE comment (클라이언트는 무시)
                        yield ": keepalive\n\n"
                        continue

                    if kind_tag == "done":
                        break
                    if kind_tag == "error":
                        raise payload

                    event = payload
                    kind = event.get("event", "")

                    # ── 2회 연속 응답 방지 ───────────────────────────
                    # 이미 텍스트를 전송한 후 LLM이 다시 호출되면
                    # (redirect 등으로 인한 재호출) 토큰을 차단
                    if kind == "on_chat_model_start" and has_streamed_text:
                        suppress_tokens = True

                    # ── LLM 토큰 스트리밍 ──────────────────────────────
                    if kind == "on_chat_model_stream":
                        if suppress_tokens:
                            continue

                        chunk = event.get("data", {}).get("chunk")
                        if not chunk:
                            continue

                        if hasattr(chunk, "tool_call_chunks") and chunk.tool_call_chunks:
                            continue

                        if hasattr(chunk, "content") and chunk.content:
                            content = _extract_text(chunk.content)
                            stripped = content.strip()
                            if stripped:
                                first_char = stripped[0]
                                if first_char in ('{', '}', '[', ']') or (
                                    first_char == '"' and any(
                                        k in stripped for k in (
                                            '"level"', '"warmup"', '"main_set"', '"cooldown"',
                                            '"description":', '"distance":', '"repeat":',
                                            '"cycle_time"', '"rest_seconds"', '"total_distance"',
                                            '"beginner"', '"intermediate"', '"advanced"',
                                            '"level_label"', '"estimated_minutes"', '"notes":',
                                        )
                                    )
                                ):
                                    continue

                            has_streamed_text = True
                            data = json.dumps(
                                {"type": "token", "content": content},
                                ensure_ascii=False,
                            )
                            yield f"data: {data}\n\n"

                    # ── Tool 호출 시작 ─────────────────────────────────
                    elif kind == "on_tool_start":
                        tool_name = event.get("name", "")
                        if tool_name == "generate_program":
                            suppress_tokens = True
                        data = json.dumps(
                            {"type": "tool_start", "tool": tool_name},
                            ensure_ascii=False,
                        )
                        yield f"data: {data}\n\n"

                    # ── Tool 완료 ──────────────────────────────────────
                    elif kind == "on_tool_end":
                        tool_name = event.get("name", "")
                        event_data: dict = {"type": "tool_end", "tool": tool_name}

                        if tool_name == "generate_program":
                            output = event.get("data", {}).get("output")
                            if output:
                                raw = output.content if hasattr(output, "content") else str(output)
                                try:
                                    parsed = json.loads(raw)
                                    if "error" in parsed:
                                        # 프로그램 생성 실패 → 클라이언트에 에러 이벤트 전송
                                        logger.error(f"generate_program 실패: {parsed['error']}")
                                        err = json.dumps(
                                            {"type": "error", "content": "프로그램을 생성하지 못했어요. 다시 시도해주세요. 🙏"},
                                            ensure_ascii=False,
                                        )
                                        yield f"data: {err}\n\n"
                                        producer_task.cancel()
                                        return
                                    event_data["program_data"] = parsed
                                except (json.JSONDecodeError, TypeError):
                                    pass

                        data = json.dumps(event_data, ensure_ascii=False)
                        yield f"data: {data}\n\n"

            finally:
                producer_task.cancel()

            # 완료 신호
            yield f"data: {json.dumps({'type': 'done'})}\n\n"

        except Exception as e:
            logger.error(f"스트리밍 오류: {e}", exc_info=True)
            error_data = json.dumps(
                {"type": "error", "content": str(e)},
                ensure_ascii=False,
            )
            yield f"data: {error_data}\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )
