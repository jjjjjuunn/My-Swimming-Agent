from pydantic import BaseModel, Field


class Exercise(BaseModel):
    """개별 운동 항목"""

    description: str = Field(..., description="운동 설명 (예: '자유형 50m x 4')")
    distance: int = Field(..., ge=10, le=1000, description="거리 (미터, 10~1000)")
    repeat: int = Field(default=1, ge=1, le=30, description="반복 횟수 (1~30)")
    rest_seconds: int = Field(default=0, ge=0, le=600, description="세트 간 휴식 (초, 0~600)")
    notes: str = Field(default="", description="추가 설명 / 코칭 포인트")
    cycle_time: str | None = Field(default=None, description="사이클 타임 (예: '2:15')")


class ProgramLevel(BaseModel):
    """하나의 레벨 프로그램"""

    level: str = Field(..., description="beginner, intermediate, advanced")
    level_label: str = Field(..., description="레벨 표시명 (초급, 중급, 고급)")
    description: str = Field(..., description="프로그램 요약 설명")
    warmup: list[Exercise] = Field(..., description="워밍업 세트")
    main_set: list[Exercise] = Field(..., description="메인 세트")
    cooldown: list[Exercise] = Field(..., description="쿨다운 세트")
    total_distance: int = Field(..., ge=0, description="총 거리 (미터)")
    estimated_minutes: int = Field(..., ge=1, le=180, description="예상 소요 시간 (분, 1~180)")


class ProgramResponse(BaseModel):
    """3-레벨 프로그램 응답 (하루 운동 계획)"""

    training_goal: str = Field(..., description="훈련 목표")
    strokes: list[str] = Field(..., description="선택한 종목")
    beginner: ProgramLevel = Field(..., description="초급 프로그램")
    intermediate: ProgramLevel = Field(..., description="중급 프로그램")
    advanced: ProgramLevel = Field(..., description="고급 프로그램")


class ErrorResponse(BaseModel):
    """에러 응답"""

    detail: str
    error_code: str = "UNKNOWN_ERROR"
