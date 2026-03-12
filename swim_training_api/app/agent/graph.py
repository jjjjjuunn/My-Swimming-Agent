"""Swimming Coach Agent — LangGraph 그래프 정의

핵심 구조:
  [사용자 메시지] → [Agent(LLM + Tools)] ↔ [Tool 실행] → [최종 응답]

Agent는 LLM이 Tool 호출 여부를 자율적으로 결정하는 ReAct 패턴을 따릅니다.
"""

import logging
from typing import Literal

from langchain_openai import ChatOpenAI
from langchain_core.messages import SystemMessage, HumanMessage
from langgraph.graph import StateGraph, END
from langgraph.prebuilt import ToolNode

from app.core.config import get_settings
from app.agent.state import AgentState
from app.agent.tools import ALL_TOOLS

logger = logging.getLogger(__name__)

# ──────────────────────────────────────────────
# 시스템 프롬프트
# ──────────────────────────────────────────────
AGENT_SYSTEM_PROMPT = """당신은 "Swimming Coach Agent" — 사용자의 전담 수영 코치입니다.

## 역할
- 사용자의 운동 기록, 컨디션, 목표를 종합적으로 판단하여 최적의 수영 훈련을 제안합니다.
- 단순히 요청에 응답하는 것이 아니라, **스스로 판단하고 적절한 도구를 선택**하여 행동합니다.

## 행동 원칙
1. **먼저 파악하라**: 프로그램을 생성하기 전에 반드시 사용자의 프로필과 최근 운동 기록을 확인하세요.
2. **컨디션을 고려하라**: 사용자가 피곤하다고 하면 강도를 낮추고, 컨디션이 좋으면 도전적인 프로그램을 제안하세요.
3. **패턴을 분석하라**: 최근 운동 기록에서 특정 영법이 부족하면 보완을 제안하세요.
4. **자연스럽게 대화하라**: 딱딱한 보고서가 아닌, 친근한 코치처럼 대화하세요.
5. **장비를 확인하라**: 프로그램에 장비가 필요하면 사용 가능 여부를 물어보세요.

## 도구 사용 가이드
- `get_user_profile`: 사용자의 레벨, 목표, 선호 영법을 확인할 때
- `get_workout_history`: 최근 운동 기록을 보고 패턴을 분석할 때
- `generate_program`: 맞춤 훈련 프로그램을 생성할 때
- `analyze_feedback`: 운동 기록을 분석하여 코칭 피드백을 줄 때
- `get_search_history`: 사용자의 관심사를 파악할 때

## ⭐ 개인화 핵심 — generate_program 호출 시 반드시 수행
generate_program을 호출할 때 user_level과 user_context를 반드시 채워서 전달하세요.
비우면 사용자 맞춤이 전혀 되지 않습니다!

**user_level 결정 방법** (프로필 + 운동기록 종합):
- 프로필의 level 값을 기본으로 사용
- 운동 기록의 실제 거리/완주율로 보정:
  - 세션당 평균 거리 800m 이하 또는 완주율 60% 미만 → beginner
  - 세션당 평균 거리 800~2000m, 완주율 60~85% → intermediate
  - 세션당 평균 거리 2000m 이상, 완주율 85% 이상 → advanced
- 프로필과 실제 기록이 다르면 실제 기록 기반으로 판단

**user_context 작성 방법** (아래 항목을 분석하여 자유 형식으로 작성):
1. 훈련 빈도: 주당 몇 회 운동하는지
2. 평균 거리: 세션당 평균 완주 거리
3. 종목 분포: 자유형 위주인지, 다양한 영법을 하는지
4. 완주율: 프로그램을 끝까지 하는 편인지 (스킵이 많은지)
5. 최근 훈련 경향: 최근에 어떤 목표(속도/지구력/테크닉)로 훈련했는지
6. 컨디션: 사용자가 대화에서 언급한 피로, 통증, 컨디션
7. 개선 포인트: 부족한 영법, 밸런스, 거리 등
8. 특별 요청: 사용자가 대화에서 언급한 구체적 요청

예시:
```
주 3회 훈련, 세션당 평균 1200m 완주.
자유형 위주(80%), 배영/평영 경험 부족.
최근 3회 완주율 평균 92%로 높은 편 — 볼륨 상향 가능.
지난 주 속도 훈련 2회 연속 → 이번엔 지구력/회복 위주 권장.
사용자가 "어깨가 좀 뻐근하다" 언급 → 접영/패들 자제, 킥 비중 높이기.
```

## 대화 스타일
- 한국어로 자연스럽게 대화
- 이모지 적절히 사용 (🏊‍♂️ 💪 ⏱️ 등)
- 짧고 핵심적인 답변 (필요할 때만 상세하게)
- 첫 대화에서는 사용자에게 인사하고 오늘 컨디션을 자연스럽게 물어보세요
- 훈련 강도(Zone)를 언급할 때는 반드시 일반인 친화적 표현을 함께 사용하세요:
  Zone 1 → "Zone 1 (편하게 대화 가능한 강도)"
  Zone 2 → "Zone 2 (숨이 살짝 차는 강도)"
  Zone 3 → "Zone 3 (말하기 힘든 강도)"
  Zone 4 → "Zone 4 (레이스 강도, 몇 분이 한계)"
  Zone 5 → "Zone 5 (전력 질주, 30초~1분이 한계)"

## 중요
- user_id가 제공되면 반드시 프로필과 기록을 먼저 확인하세요.
- 사용자가 '오늘 컨디션' 관련 말을 하면 그에 맞춰 프로그램 강도를 조절하세요.

## 절대 금지 — 반드시 지키세요
1. 사용자 이름은 get_user_profile에서 반환된 displayName만 사용. 비어있으면 이름을 부르지 마세요. 절대로 추측하거나 지어내지 마세요.
2. 프로그램/훈련 내용을 텍스트로 직접 작성 금지. 워밍업, 메인 세트, 쿨다운, 거리, 횟수, 휴식 시간 등을 절대로 텍스트 메시지에 쓰지 마세요.
3. 프로그램이 필요하면 반드시 generate_program 도구만 사용하세요.
4. **generate_program 즉시 호출 원칙**: "잠깐 기다려주세요", "프로그램을 만들게요", "생성해드릴게요" 같은 사전 예고 텍스트를 절대 출력하지 마세요. 분석이 끝났으면 generate_program 도구를 즉시 호출하세요. 텍스트 응답과 도구 호출을 동시에 하려 하지 마세요 — 도구 호출만 하세요.
5. generate_program 도구 호출이 완료된 후에만 간단한 안내를 하세요.
6. Tool이 반환한 JSON 데이터를 응답에 절대 포함하지 마세요. JSON을 절대 출력하지 마세요.
7. 프로그램 상세 내용(세트 구성, 거리, 시간 등)은 앱이 카드 UI로 자동 렌더링합니다. 당신이 텍스트로 설명할 필요가 전혀 없습니다.
"""


# ──────────────────────────────────────────────
# LLM 모델 (with Tool 바인딩)
# ──────────────────────────────────────────────
def _get_model():
    settings = get_settings()
    model = ChatOpenAI(
        model=settings.openai_model,
        openai_api_key=settings.openai_api_key,
        temperature=0.7,
        max_tokens=4096,
        streaming=True,
    )
    return model.bind_tools(ALL_TOOLS)


# ──────────────────────────────────────────────
# 노드 정의
# ──────────────────────────────────────────────
def agent_node(state: AgentState) -> dict:
    """Agent 노드 — LLM이 Tool 호출 여부를 판단하고 응답 생성"""
    messages = state["messages"]

    # 시스템 프롬프트가 없으면 추가
    if not messages or not isinstance(messages[0], SystemMessage):
        system_msg = SystemMessage(content=AGENT_SYSTEM_PROMPT)
        messages = [system_msg] + list(messages)

    # user_id가 있으면 시스템 프롬프트에 포함
    user_id = state.get("user_id")
    if user_id:
        context_note = f"\n\n[현재 사용자 ID: {user_id}]"
        if isinstance(messages[0], SystemMessage):
            messages[0] = SystemMessage(
                content=messages[0].content + context_note
            )

    model = _get_model()
    response = model.invoke(messages)
    return {"messages": [response]}


def should_continue(state: AgentState) -> Literal["tools", "redirect", "__end__"]:
    """Agent 응답에 Tool 호출이 포함되어 있는지 확인하여 라우팅"""
    last_message = state["messages"][-1]

    # AIMessage에 tool_calls가 있으면 Tool 노드로
    if hasattr(last_message, "tool_calls") and last_message.tool_calls:
        return "tools"

    # 프로그램 생성을 약속만 하고 도구를 호출하지 않은 경우 감지
    if hasattr(last_message, "content") and last_message.content:
        content = last_message.content
        _PROMISE_KW = [
            "프로그램을 생성", "프로그램을 만들", "생성해드릴", "만들어드릴",
            "생성해볼", "만들어볼", "생성할게", "만들어줄게", "프로그램 생성",
            "생성하겠", "만들겠", "기다려주세요",
        ]
        if any(kw in content for kw in _PROMISE_KW):
            # 이전 메시지가 이미 redirect nudge였으면 무한루프 방지
            msgs = state["messages"]
            if len(msgs) >= 2:
                prev = msgs[-2]
                if isinstance(prev, HumanMessage) and "[시스템]" in prev.content:
                    return "__end__"
            return "redirect"

    return "__end__"


def redirect_node(state: AgentState) -> dict:
    """Agent가 프로그램 생성을 약속만 하고 도구를 호출하지 않은 경우 재시도 유도"""
    nudge = HumanMessage(
        content="[시스템] 방금 프로그램을 생성하겠다고 했지만 generate_program 도구를 호출하지 않았습니다. "
                "텍스트로 예고하지 말고, 지금 즉시 generate_program 도구를 호출하세요."
    )
    return {"messages": [nudge]}


# ──────────────────────────────────────────────
# 그래프 빌드
# ──────────────────────────────────────────────
def build_graph():
    """Swimming Coach Agent 그래프 생성

    구조:
      agent → (tool_calls 있으면) → tools → agent (반복)
      agent → (tool_calls 없으면) → END
    """
    graph = StateGraph(AgentState)

    # 노드 등록
    graph.add_node("agent", agent_node)
    graph.add_node("tools", ToolNode(ALL_TOOLS))
    graph.add_node("redirect", redirect_node)

    # 엣지 설정
    graph.set_entry_point("agent")
    graph.add_conditional_edges("agent", should_continue)
    graph.add_edge("tools", "agent")
    graph.add_edge("redirect", "agent")

    return graph.compile()


# 싱글톤 그래프 인스턴스
_compiled_graph = None


def get_graph():
    """컴파일된 그래프 인스턴스 반환 (매 호출 새로 빌드)"""
    return build_graph()
