from pydantic import BaseModel, Field
from typing import Optional


class ProgramRequest(BaseModel):
    """프로그램 생성 요청 모델"""

    user_id: Optional[str] = Field(
        default=None,
        description="Firebase 사용자 ID (검색 이력 분석용)",
    )
    training_goal: str = Field(
        ...,
        description="훈련 목표: speed, endurance, technique, overall",
        examples=["speed"],
    )
    strokes: list[str] = Field(
        ...,
        min_length=1,
        description="집중 종목 리스트: freestyle, butterfly, backstroke, breaststroke, IM",
        examples=[["freestyle", "butterfly"]],
    )
    equipment: Optional[list[str]] = Field(
        default=None,
        description="사용 가능한 도구 리스트: fins, snorkel, paddles, kickboard, pull_buoy",
        examples=[["fins", "paddles"]],
    )
    purpose: Optional[str] = Field(
        default=None,
        description="수영 목적: competition, hobby, fitness, diet",
        examples=["competition"],
    )


class FeedbackRequest(BaseModel):
    """AI 피드백 요청 모델"""

    workout_logs: list[dict] = Field(
        ...,
        description="최근 운동 기록 리스트",
    )
    purpose: Optional[str] = Field(
        default=None,
        description="수영 목적: competition, hobby, fitness, diet",
    )
    user_message: Optional[str] = Field(
        default=None,
        description="사용자의 구체적인 고민 또는 질문",
    )
    user_id: Optional[str] = Field(
        default=None,
        description="Firebase 사용자 ID (검색 이력 조회용)",
    )


class FeedbackToProgramRequest(BaseModel):
    """피드백 텍스트 → 구조화된 프로그램 변환 요청 모델"""

    feedback_text: str = Field(
        ...,
        description="AI 피드백 전체 텍스트 (다음 훈련 처방 포함)",
    )
    training_goal: Optional[str] = Field(
        default=None,
        description="훈련 목표: speed, endurance, technique, overall",
    )
    strokes: Optional[list[str]] = Field(
        default=None,
        description="집중 종목 리스트",
    )
