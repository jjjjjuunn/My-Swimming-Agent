"""Swimming Coach Agent — 상태 정의"""

from typing import Annotated, Optional
from typing_extensions import TypedDict

from langgraph.graph.message import add_messages
from langchain_core.messages import BaseMessage


class AgentState(TypedDict):
    """LangGraph Agent의 상태

    Attributes:
        messages: 대화 히스토리 (HumanMessage, AIMessage 등)
        user_id: Firebase UID
        user_profile: Firestore에서 가져온 사용자 프로필
        workout_history: 최근 운동 기록
        current_intent: 라우터가 판단한 사용자 의도
        generated_program: 생성된 프로그램 (JSON)
        tool_results: Tool 실행 결과 임시 저장
    """

    messages: Annotated[list[BaseMessage], add_messages]
    user_id: Optional[str]
    user_profile: Optional[dict]
    workout_history: Optional[list[dict]]
    current_intent: Optional[str]
    generated_program: Optional[dict]
    tool_results: Optional[dict]
