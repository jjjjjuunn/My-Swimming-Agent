"""Swimming Coach Agent — Tool 정의

Agent가 자율적으로 선택하여 사용하는 도구들.
각 Tool은 LangChain @tool 데코레이터로 정의되어 LLM이 직접 호출합니다.
"""

import json
import logging
from typing import Optional

from langchain_core.tools import tool

from app.services.firebase_service import FirebaseService, _init_firebase

logger = logging.getLogger(__name__)

# Firebase 클라이언트 (Lazy init)
_firebase_service: Optional[FirebaseService] = None


def _get_firebase():
    global _firebase_service
    if _firebase_service is None:
        _firebase_service = FirebaseService()
    return _firebase_service


def _get_firestore_client():
    """Firestore 클라이언트 직접 가져오기"""
    _init_firebase()
    from firebase_admin import firestore
    return firestore.client()


# ──────────────────────────────────────────────
# Tool 1: 사용자 프로필 조회
# ──────────────────────────────────────────────
@tool
def get_user_profile(user_id: str) -> str:
    """사용자의 수영 프로필을 조회합니다.
    레벨, 목표, 선호 영법, 수영 목적 등의 정보를 반환합니다.
    프로그램 생성이나 피드백 전에 반드시 호출하세요."""

    try:
        db = _get_firestore_client()
        doc = db.collection("users").document(user_id).get()

        if not doc.exists:
            return json.dumps({"error": "사용자 정보를 찾을 수 없습니다."}, ensure_ascii=False)

        data = doc.to_dict()
        profile = {
            "displayName": data.get("displayName", ""),
            "level": data.get("level", "미설정"),
            "purpose": data.get("purpose", "미설정"),
            "favoriteStrokes": data.get("favoriteStrokes", []),
            "goals": data.get("goals", []),
            "onboardingCompleted": data.get("onboardingCompleted", False),
        }
        logger.info(f"프로필 조회 완료: {user_id}")
        return json.dumps(profile, ensure_ascii=False)

    except Exception as e:
        logger.error(f"프로필 조회 실패: {e}")
        return json.dumps({"error": f"프로필 조회 실패: {str(e)}"}, ensure_ascii=False)


# ──────────────────────────────────────────────
# Tool 2: 운동 기록 조회
# ──────────────────────────────────────────────
@tool
def get_workout_history(user_id: str, limit: int = 7) -> str:
    """사용자의 최근 운동 기록을 조회합니다.
    최근 N건의 수영 훈련 기록을 반환합니다.
    각 기록에는 날짜, 거리, 완주율, 소요시간, 종목, 세트별 완료/스킵 현황, 메모, 피드백이 포함됩니다.
    이 데이터를 바탕으로 사용자의 실력, 컨디션, 훈련 패턴을 분석하세요."""

    try:
        db = _get_firestore_client()
        docs = (
            db.collection("users")
            .document(user_id)
            .collection("workout_logs")
            .order_by("started_at", direction="DESCENDING")
            .limit(limit)
            .stream()
        )

        logs = []
        total_completed_distance = 0
        total_planned_distance = 0
        stroke_counts: dict[str, int] = {}
        goal_counts: dict[str, int] = {}

        for doc in docs:
            data = doc.to_dict()

            # 세트별 상세 분석
            sets = data.get("sets", [])
            completed_sets = sum(1 for s in sets if s.get("status") == "completed")
            partial_sets = sum(
                1 for s in sets
                if s.get("status") == "skipped" and s.get("completed_repeat", 0) > 0
            )
            skipped_sets = sum(
                1 for s in sets
                if s.get("status") == "skipped" and s.get("completed_repeat", 0) == 0
            )

            planned = data.get("planned_distance", 0)
            completed = data.get("completed_distance", 0)
            total_planned_distance += planned
            total_completed_distance += completed

            # 종목/목표 빈도
            for s in data.get("strokes", []):
                stroke_counts[s] = stroke_counts.get(s, 0) + 1
            goal = data.get("training_goal", "")
            if goal:
                goal_counts[goal] = goal_counts.get(goal, 0) + 1

            log_entry = {
                "id": doc.id,
                "date": data.get("started_at", ""),
                "planned_distance": planned,
                "completed_distance": completed,
                "completion_rate": round(completed / planned * 100, 1) if planned > 0 else 0,
                "duration_minutes": data.get("duration_minutes", 0),
                "training_goal": goal,
                "strokes": data.get("strokes", []),
                "level": data.get("level_label", ""),
                "total_sets": len(sets),
                "completed_sets": completed_sets,
                "partial_sets": partial_sets,
                "skipped_sets": skipped_sets,
                "memo": data.get("memo", ""),
                "feedback": data.get("feedback", ""),
            }
            logs.append(log_entry)

        if not logs:
            return json.dumps({"message": "운동 기록이 없습니다.", "logs": []}, ensure_ascii=False)

        # 전체 통계 요약
        avg_completion = round(total_completed_distance / total_planned_distance * 100, 1) if total_planned_distance > 0 else 0
        avg_distance = round(total_completed_distance / len(logs))

        result = {
            "total_count": len(logs),
            "summary": {
                "avg_completion_rate": avg_completion,
                "avg_distance_per_session": avg_distance,
                "total_distance_recent": total_completed_distance,
                "most_trained_strokes": sorted(stroke_counts.items(), key=lambda x: -x[1]),
                "most_trained_goals": sorted(goal_counts.items(), key=lambda x: -x[1]),
                "training_frequency": f"{len(logs)}회 (최근 조회 범위)",
            },
            "logs": logs,
        }
        logger.info(f"운동 기록 {len(logs)}건 조회: {user_id}")
        return json.dumps(result, ensure_ascii=False, default=str)

    except Exception as e:
        logger.error(f"운동 기록 조회 실패: {e}")
        return json.dumps({"error": f"운동 기록 조회 실패: {str(e)}"}, ensure_ascii=False)


# ──────────────────────────────────────────────
# Tool 3: 프로그램 생성
# ──────────────────────────────────────────────
@tool
async def generate_program(
    training_goal: str,
    strokes: str,
    equipment: str = "",
    purpose: str = "",
    user_level: str = "",
    user_context: str = "",
    user_id: str = "",
) -> str:
    """사용자 맞춤 수영 훈련 프로그램을 생성합니다.
    training_goal: speed, endurance, technique, overall 중 하나
    strokes: 쉼표로 구분된 종목 (예: "freestyle,butterfly")
    equipment: 쉼표로 구분된 장비 (예: "fins,paddles") 없으면 빈 문자열
    purpose: competition, hobby, fitness, diet 중 하나. 없으면 빈 문자열
    user_level: 사용자 실력 수준 (beginner, intermediate, advanced). 프로필과 운동기록을 종합 판단하여 전달
    user_context: 사용자 개인화 정보 요약. 아래 항목을 포함하여 자유 형식으로 작성:
      - 최근 운동 패턴 (주당 빈도, 평균 거리, 주로 사용한 영법)
      - 완주율 (프로그램을 끝까지 하는지, 중간에 스킵하는지)
      - 컨디션/피로도 (사용자가 언급한 내용 + 기록 기반 추론)
      - 개선이 필요한 부분 (부족한 영법, 지구력/스피드 밸런스 등)
      - 사용자가 대화에서 언급한 특별 요청이나 고민
    user_id: 사용자 ID (검색 이력 조회 등에 활용). 시스템 프롬프트의 [현재 사용자 ID: ...]에서 가져오세요.

    반드시 get_user_profile과 get_workout_history 결과를 분석하여 user_level과 user_context를 채워주세요.
    3단계(초급/중급/고급) 프로그램을 생성합니다."""

    try:
        from app.services.program_generator import ProgramGenerator

        # ── training_goal 정규화 ──────────────────────────────────────
        _goal_map = {
            "competition": "speed", "race": "speed", "sprint": "speed",
            "speed_technique": "speed",
            "fitness": "endurance", "cardio": "endurance", "stamina": "endurance",
            "aerobic": "endurance",
            "skill": "technique", "drill": "technique", "form": "technique",
            "general": "overall", "mixed": "overall", "full": "overall",
            "balanced": "overall", "all": "overall",
        }
        training_goal = _goal_map.get(training_goal.lower(), training_goal.lower())
        if training_goal not in {"speed", "endurance", "technique", "overall"}:
            logger.warning(f"알 수 없는 training_goal '{training_goal}' → 'overall'로 대체")
            training_goal = "overall"

        # ── strokes 정규화 ────────────────────────────────────────────
        _stroke_map = {
            "자유형": "freestyle", "배영": "backstroke", "평영": "breaststroke",
            "접영": "butterfly", "혼영": "IM", "개인혼영": "IM",
            "individual_medley": "IM", "medley": "IM", "im": "IM",
            "free": "freestyle", "back": "backstroke",
            "breast": "breaststroke", "fly": "butterfly",
            # 흔한 오타·변형
            "평형": "breaststroke", "배형": "backstroke",
            "접형": "butterfly", "자유영": "freestyle",
            "프리": "freestyle", "프리스타일": "freestyle",
            "백스트로크": "backstroke", "브레스트": "breaststroke",
            "버터플라이": "butterfly", "버터": "butterfly",
            "크롤": "freestyle",
        }
        _valid_strokes = {"freestyle", "butterfly", "backstroke", "breaststroke", "IM"}
        strokes_list = []
        for s in strokes.split(","):
            s = s.strip()
            if not s:
                continue
            # 대소문자 무시 매핑
            normalized = _stroke_map.get(s.lower(), s)
            # 유효한 값과 대소문자 무시 비교
            matched = next(
                (vs for vs in _valid_strokes if vs.lower() == normalized.lower()),
                None,
            )
            if matched:
                strokes_list.append(matched)
            else:
                logger.warning(f"알 수 없는 stroke '{s}' 무시됨")
        if not strokes_list:
            logger.warning("유효한 stroke 없음 → 'freestyle'로 대체")
            strokes_list = ["freestyle"]

        generator = ProgramGenerator()
        equipment_list = [e.strip() for e in equipment.split(",") if e.strip()] or None

        result = await generator.generate(
            training_goal=training_goal,
            strokes=strokes_list,
            user_id=user_id or None,
            equipment=equipment_list,
            purpose=purpose or None,
            user_level=user_level or None,
            user_context=user_context or None,
        )

        program_dict = result.model_dump()
        logger.info(f"프로그램 생성 완료: {training_goal}, {strokes_list}")
        return json.dumps(program_dict, ensure_ascii=False)

    except Exception as e:
        logger.error(f"프로그램 생성 실패: {e}")
        return json.dumps({"error": f"프로그램 생성 실패: {str(e)}"}, ensure_ascii=False)


# ──────────────────────────────────────────────
# Tool 4: 피드백 분석
# ──────────────────────────────────────────────
@tool
async def analyze_feedback(
    workout_logs_json: str,
    purpose: str = "",
    user_message: str = "",
) -> str:
    """사용자의 운동 기록을 분석하여 AI 코칭 피드백을 제공합니다.
    workout_logs_json: 운동 기록 JSON 문자열 (get_workout_history 결과를 그대로 전달)
    purpose: 수영 목적 (competition, hobby, fitness, diet)
    user_message: 사용자의 추가 질문이나 고민"""

    try:
        from app.services.llm_service import LLMService

        logs_data = json.loads(workout_logs_json)
        logs = logs_data.get("logs", logs_data) if isinstance(logs_data, dict) else logs_data

        llm = LLMService()
        system_prompt = """당신은 전문 수영 코치입니다. 사용자의 운동 기록을 분석하여 피드백을 제공합니다.

피드백은 다음을 포함하세요:
1. 최근 훈련 패턴 분석 (거리, 빈도, 종목 균형)
2. 잘한 점과 개선할 점
3. 다음 훈련에 대한 구체적 제안
4. 컨디션/피로도 판단

한국어로 자연스럽게 대화하듯 작성하세요."""

        user_prompt = f"운동 기록:\n{json.dumps(logs, ensure_ascii=False, indent=2)}"
        if purpose:
            user_prompt += f"\n수영 목적: {purpose}"
        if user_message:
            user_prompt += f"\n사용자 질문: {user_message}"

        feedback = await llm.generate_text(system_prompt, user_prompt)
        logger.info("피드백 분석 완료")
        return feedback

    except Exception as e:
        logger.error(f"피드백 분석 실패: {e}")
        return f"피드백 분석에 실패했습니다: {str(e)}"


# ──────────────────────────────────────────────
# Tool 5: 검색 이력 조회
# ──────────────────────────────────────────────
@tool
def get_search_history(user_id: str) -> str:
    """사용자의 최근 수영 관련 검색 이력을 조회합니다.
    사용자의 관심사와 고민을 파악하는 데 활용하세요."""

    try:
        import asyncio
        firebase = _get_firebase()
        # 동기 컨텍스트에서 비동기 호출
        try:
            loop = asyncio.get_running_loop()
        except RuntimeError:
            loop = None

        if loop and loop.is_running():
            import concurrent.futures
            with concurrent.futures.ThreadPoolExecutor() as pool:
                history = pool.submit(
                    asyncio.run, firebase.get_search_history(user_id)
                ).result()
        else:
            history = asyncio.run(firebase.get_search_history(user_id))

        summary = firebase.analyze_search_patterns(history)
        return summary or "검색 이력이 없습니다."

    except Exception as e:
        logger.error(f"검색 이력 조회 실패: {e}")
        return f"검색 이력 조회 실패: {str(e)}"


# ──────────────────────────────────────────────
# 전체 Tool 목록 (Graph에서 사용)
# ──────────────────────────────────────────────
ALL_TOOLS = [
    get_user_profile,
    get_workout_history,
    generate_program,
    analyze_feedback,
    get_search_history,
]
