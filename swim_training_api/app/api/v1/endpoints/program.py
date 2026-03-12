from fastapi import APIRouter, HTTPException
import logging

from app.models.request import ProgramRequest, FeedbackRequest, FeedbackToProgramRequest
from app.models.response import ProgramResponse, ErrorResponse, Exercise, ProgramLevel
from app.services.program_generator import ProgramGenerator
from app.services.llm_service import LLMService
from app.services.firebase_service import FirebaseService

router = APIRouter(tags=["program"])
logger = logging.getLogger(__name__)


@router.post(
    "/test-llm",
    summary="LLM API 연결 테스트 (최소 토큰)",
    description="간단한 프롬프트로 LLM API가 정상 작동하는지 확인 (토큰 20-30개 사용)",
)
async def test_llm_connection():
    """
    LLM API 연결 테스트 - 실제 generate_program_json 경로 사용
    매우 간단한 JSON 생성으로 전체 파이프라인 검증
    """
    try:
        from app.services.llm_service import LLMService
        from app.core.config import get_settings
        
        llm = LLMService()
        settings = get_settings()
        
        # 실제 경로 테스트: generate_program_json 사용
        system_prompt = "You are a test assistant. Respond in JSON."
        user_prompt = '{"task": "Say hello"}'
        
        response = await llm.generate_program_json(
            system_prompt=system_prompt,
            user_prompt=user_prompt
        )
        
        return {
            "status": "success",
            "message": "LLM API and full pipeline working",
            "model": getattr(llm.model, "model_name", None) or getattr(llm.model, "model", None) or settings.openai_model,
            "response_keys": list(response.keys()) if isinstance(response, dict) else "not_dict",
            "sample": str(response)[:200]  # 처음 200자만
        }
    except Exception as e:
        logger.error(f"LLM connection test failed: {str(e)}")
        raise HTTPException(status_code=500, detail=f"LLM API 연결 실패: {str(e)}")


@router.post(
    "/test-program",
    response_model=ProgramResponse,
    summary="테스트용 프로그램 (LLM 호출 없음)",
    description="Mock 데이터 반환 - API 할당량 절약용",
)
async def test_program_generation(request: ProgramRequest):
    """
    테스트용 엔드포인트 - LLM 호출 없이 Mock 데이터 반환
    API 할당량 절약을 위해 테스트 시 사용
    """
    
    # 레벨별 Mock 데이터
    mock_programs = {
        "beginner": ProgramLevel(
            level="beginner",
            level_label="초급",
            description="초급자를 위한 기본 수영 프로그램",
            warmup=[
                Exercise(
                    description="워밍업 - 편한 속도로 자유형",
                    distance=200,
                    repeat=1,
                    rest_seconds=0,
                    notes="편하게 몸 풀기"
                ),
            ],
            main_set=[
                Exercise(
                    description="메인세트 - 자유형 기본 연습",
                    distance=50,
                    repeat=4,
                    rest_seconds=30,
                    notes="일정한 페이스 유지"
                ),
            ],
            cooldown=[
                Exercise(
                    description="쿨다운 - 편안하게 자유형",
                    distance=100,
                    repeat=1,
                    rest_seconds=0,
                    notes="천천히 마무리"
                ),
            ],
            total_distance=500,
            estimated_minutes=20
        ),
        "intermediate": ProgramLevel(
            level="intermediate",
            level_label="중급",
            description="중급자를 위한 인터벌 트레이닝",
            warmup=[
                Exercise(
                    description="워밍업 - 자유형 + 배영",
                    distance=400,
                    repeat=1,
                    rest_seconds=0,
                    notes="다양한 영법으로 준비"
                ),
            ],
            main_set=[
                Exercise(
                    description="메인세트 - 인터벌 트레이닝",
                    distance=100,
                    repeat=6,
                    rest_seconds=20,
                    notes="목표 시간 내 완료"
                ),
            ],
            cooldown=[
                Exercise(
                    description="쿨다운 - 느리게 자유형",
                    distance=200,
                    repeat=1,
                    rest_seconds=0,
                    notes="호흡 정리"
                ),
            ],
            total_distance=1200,
            estimated_minutes=40
        ),
        "advanced": ProgramLevel(
            level="advanced",
            level_label="고급",
            description="고급자를 위한 고강도 트레이닝",
            warmup=[
                Exercise(
                    description="워밍업 - 혼합 종목",
                    distance=600,
                    repeat=1,
                    rest_seconds=0,
                    notes="충분한 워밍업"
                ),
            ],
            main_set=[
                Exercise(
                    description="메인세트 - 고강도 인터벌",
                    distance=200,
                    repeat=5,
                    rest_seconds=15,
                    notes="최고 강도 유지"
                ),
            ],
            cooldown=[
                Exercise(
                    description="쿨다운 - 편안한 자유형",
                    distance=300,
                    repeat=1,
                    rest_seconds=0,
                    notes="충분한 회복"
                ),
            ],
            total_distance=1900,
            estimated_minutes=60
        ),
    }
    
    return ProgramResponse(
        training_goal=request.training_goal,
        strokes=request.strokes,
        beginner=mock_programs["beginner"],
        intermediate=mock_programs["intermediate"],
        advanced=mock_programs["advanced"],
    )


@router.post(
    "/generate-program",
    response_model=ProgramResponse,
    responses={
        500: {"model": ErrorResponse, "description": "서버 에러"},
    },
    summary="AI 수영 프로그램 생성",
    description="훈련 목표와 집중 종목을 기반으로 3가지 레벨의 하루 운동 프로그램을 생성합니다.",
)
async def generate_program(request: ProgramRequest):
    try:
        generator = ProgramGenerator()
        result = await generator.generate(
            training_goal=request.training_goal,
            strokes=request.strokes,
            user_id=request.user_id,
            equipment=request.equipment,
            purpose=request.purpose,
        )
        return result

    except ValueError as e:
        logger.warning(f"잘못된 요청: {e}")
        raise HTTPException(status_code=400, detail=str(e))

    except Exception as e:
        logger.error(f"프로그램 생성 실패: {e}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail="프로그램 생성 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.",
        )


@router.post(
    "/ai-feedback",
    summary="AI 운동 피드백",
    description="최근 운동 기록을 분석하여 AI 피드백을 제공합니다.",
)
async def ai_feedback(request: FeedbackRequest):
    try:
        llm = LLMService()

        purpose_labels = {
            "competition": "대회 준비",
            "hobby": "취미 생활",
            "fitness": "체력 향상",
            "diet": "다이어트",
        }
        purpose_text = purpose_labels.get(request.purpose or "", "")

        # 검색 이력 조회
        search_section = ""
        if request.user_id:
            firebase = FirebaseService()
            history = await firebase.get_search_history(request.user_id)
            search_summary = firebase.analyze_search_patterns(history)
            if search_summary:
                search_section = f"\n## 사용자 검색 이력 기반 관심사\n{search_summary}\n"

        logs_summary = ""
        for i, log in enumerate(request.workout_logs, 1):
            sets_detail = "\n".join([
                f"      • {s.get('exercise', '')} {s.get('distance', 0)}m×{s.get('repeat', 1)} [{s.get('status', '')}]"
                for s in log.get('sets', [])
            ])
            logs_summary += f"""
[운동 {i}]
- 프로그램: {log.get('program_title', '알 수 없음')} ({log.get('level_label', '')})
- 훈련 목표: {log.get('training_goal', '')}
- 완료: {log.get('completed_distance', 0)}m / 계획: {log.get('planned_distance', 0)}m ({log.get('completion_rate', 0):.0f}%)
- 소요 시간: {log.get('duration_minutes', 0)}분
- 세트 내역:
{sets_detail if sets_detail else '      (세트 정보 없음)'}
"""

        # 사용자 메시지 유무에 따라 분석 방향 결정
        user_concern = request.user_message or ""
        concern_section = f"\n## 사용자의 고민\n{user_concern}\n" if user_concern else ""

        system_prompt = """당신은 경험 많은 수영 전문 코치입니다. 사용자의 실제 운동 세트 기록을 면밀히 분석하여 실질적인 피드백을 제공합니다.

**분석 지침:**
1. 세트 내역에서 어떤 드릴/종목이 포함됐는지 파악하세요
2. 사용자의 검색 이력 관심사가 있다면, 그 키워드와 관련된 드릴이 훈련에 있었는지 확인하고 없다면 다음 훈련에 구체적으로 시쓰세요
3. 사용자의 직접 고민이 있다면, 성범 기록에서 그 고민과 관련된 부분을 찾아 연결하세요
4. 부족한 부분은 구체적인 드릴 이름과 거리/반복 횟수까지 제안하세요
5. 수치 근거를 들어 설명하세요 (예: "3회 중 돌핀킥 드릴이 0회 포함됨")

**출력 형식 (마크다운 없이 텍스트만):**
[패턴 분석]
최근 운동에서 발견한 구체적 패턴 (2-3줄)

[잘하고 있는 점]
구체적인 칭찬 1-2가지

[개선 포인트]
고민/약점과 연결된 구체적 개선 제안

[다음 훈련 처방]
구체적인 드릴/세트 제안 (예: 돌핀킥 드릴 25m×6, 킥보드 사용, 30초 휴식)
따뜻하지만 전문적인 톤으로 작성하세요."""

        user_prompt = f"""## 피드백 요청{concern_section}{search_section}
{'수영 목적: ' + purpose_text if purpose_text else ''}

## 운동 기록 전체
{logs_summary}

위 기록을 바탕으로 맞춤형 피드백을 제공해주세요."""

        response = await llm.generate_text(
            system_prompt=system_prompt,
            user_prompt=user_prompt,
        )

        return {"feedback": response}

    except Exception as e:
        logger.error(f"AI 피드백 생성 실패: {e}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail="피드백 생성 중 오류가 발생했습니다.",
        )


@router.post(
    "/feedback-to-program",
    summary="AI 피드백 → 구조화된 프로그램 변환",
    description="AI 피드백의 다음 훈련 처방을 실제 운동 프로그램 JSON으로 변환합니다.",
)
async def feedback_to_program(request: FeedbackToProgramRequest):
    try:
        llm = LLMService()

        # ── 개인화 정보 자동 조회 ──
        personalization_section = ""
        if request.user_id:
            try:
                from app.services.program_generator import ProgramGenerator
                gen = ProgramGenerator()
                user_level, user_context = await gen._build_personalization(request.user_id)
                if user_level or user_context:
                    personalization_section = "\n## 사용자 개인화 정보 (반드시 반영!)\n"
                    if user_level:
                        level_labels = {
                            "beginner": "초급", "intermediate": "중급", "advanced": "고급",
                        }
                        personalization_section += f"- 실력 수준: {level_labels.get(user_level, user_level)}\n"
                        personalization_section += f"  → 이 사용자 수준({user_level})에 맞게 거리, 반복, 강도를 조절하세요.\n"
                    if user_context:
                        personalization_section += f"\n### 사용자 현황\n{user_context}\n"
                        personalization_section += "→ 완주율, 영법 분포, 컨디션을 고려하여 프로그램 설계\n"
            except Exception as e:
                logger.warning(f"feedbackToProgram 개인화 조회 실패 (무시): {e}")

        system_prompt = """당신은 수영 코치입니다. AI 피드백에서 "다음 훈련 처방" 섹션을 읽고 이를 구조화된 JSON 운동 프로그램으로 변환하세요.

출력은 반드시 아래 JSON 형식만 반환하세요 (마크다운 코드블록 없이):
{
  "level": "ai_custom",
  "level_label": "AI 처방",
  "description": "AI 피드백 기반 맞춤 훈련",
  "warmup": [
    {"description": "운동 설명", "distance": 100, "repeat": 2, "rest_seconds": 30, "notes": "주의사항"}
  ],
  "main_set": [
    {"description": "운동 설명", "distance": 50, "repeat": 4, "rest_seconds": 20, "notes": "주의사항"}
  ],
  "cooldown": [
    {"description": "운동 설명", "distance": 200, "repeat": 1, "rest_seconds": 0, "notes": ""}
  ],
  "total_distance": 600,
  "estimated_minutes": 45
}

규칙:
- warmup: 준비운동 (없으면 자유형 200m×1, 30초 휴식)
- main_set: 피드백의 처방 세트들 (핵심)
- cooldown: 정리운동 (없으면 자유형 이지 200m×1)
- rest_seconds: 30초=30, 1분=60, 명시 없으면 30
- total_distance: 모든 (distance×repeat) 합계
- estimated_minutes: 총 거리/분 기준 적절히 계산
- JSON만 반환, 다른 텍스트 없음"""

        user_prompt = f"""다음 AI 피드백에서 훈련 프로그램을 JSON으로 변환해주세요:

{request.feedback_text}

훈련 목표: {request.training_goal or '전반적 향상'}
주 종목: {', '.join(request.strokes) if request.strokes else '피드백에서 파악'}
{personalization_section}"""

        response_text = await llm.generate_text(
            system_prompt=system_prompt,
            user_prompt=user_prompt,
        )

        import json as json_module
        # JSON 파싱
        text = response_text.strip()
        if text.startswith("```"):
            text = text.split("```")[1]
            if text.startswith("json"):
                text = text[4:]
        text = text.strip()

        program_data = json_module.loads(text)

        return {"program": program_data}

    except Exception as e:
        logger.error(f"피드백 → 프로그램 변환 실패: {e}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail="프로그램 변환 중 오류가 발생했습니다.",
        )
