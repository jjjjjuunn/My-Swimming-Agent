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


def _now_iso() -> str:
    from datetime import datetime, timezone
    return datetime.now(timezone.utc).isoformat()


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

        data = doc.to_dict() or {}
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
            if data is None:
                continue

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
                "sets_detail": [
                    {
                        "exercise": s.get("exercise", ""),
                        "distance": s.get("distance", 0),
                        "repeat": s.get("repeat", 0),
                        "completed_repeat": s.get("completed_repeat", 0),
                        "status": s.get("status", ""),
                        "duration_seconds": s.get("duration_seconds", 0),
                        "cycle_time": s.get("cycle_time", ""),
                    }
                    for s in sets
                ],
                "memo": data.get("memo", ""),
                "feedback": data.get("feedback", ""),
            }
            logs.append(log_entry)

        if not logs:
            return json.dumps({"message": "운동 기록이 없습니다.", "logs": []}, ensure_ascii=False)

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
    pool_length: int = 25,
    pool_unit: str = "m",
) -> str:
    """사용자 맞춤 수영 훈련 프로그램을 생성합니다.
    training_goal: speed, endurance, technique, overall 중 하나
    strokes: 쉼표로 구분된 종목 (예: "freestyle,butterfly")
    equipment: 쉼표로 구분된 장비 (예: "fins,paddles") 없으면 빈 문자열
    purpose: competition, hobby, fitness, diet 중 하나. 없으면 빈 문자열
    user_level: 사용자 실력 수준 (beginner, intermediate, advanced). 프로필과 운동기록을 종합 판단하여 전달
    user_context: 사용자 개인화 정보 요약
    user_id: 사용자 ID. 시스템 프롬프트의 [현재 사용자 ID: ...]에서 가져오세요.
    pool_length: 수영장 길이 (25 또는 50). 사용자 프로필의 pool_length 사용. 기본값 25
    pool_unit: 수영장 단위 ("m" 또는 "yd"). 사용자 프로필의 pool_unit 사용. 기본값 "m"

    반드시 get_user_profile과 get_workout_history 결과를 분석하여 user_level과 user_context를 채워주세요.
    3단계(초급/중급/고급) 프로그램을 생성합니다."""

    try:
        from app.services.program_generator import ProgramGenerator

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

        _stroke_map = {
            "자유형": "freestyle", "배영": "backstroke", "평영": "breaststroke",
            "접영": "butterfly", "혼영": "IM", "개인혼영": "IM",
            "individual_medley": "IM", "medley": "IM", "im": "IM",
            "free": "freestyle", "back": "backstroke",
            "breast": "breaststroke", "fly": "butterfly",
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
            normalized = _stroke_map.get(s.lower(), s)
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
            pool_length=pool_length,
            pool_unit=pool_unit if pool_unit in ("m", "yd") else "m",
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
async def get_search_history(user_id: str) -> str:
    """사용자의 최근 수영 관련 검색 이력을 조회합니다.
    사용자의 관심사와 고민을 파악하는 데 활용하세요."""

    try:
        firebase = _get_firebase()
        history = await firebase.get_search_history(user_id)
        summary = firebase.analyze_search_patterns(history)
        return summary or "검색 이력이 없습니다."

    except Exception as e:
        logger.error(f"검색 이력 조회 실패: {e}")
        return f"검색 이력 조회 실패: {str(e)}"




# ──────────────────────────────────────────────
# Tool 6: 약점 분석
# ──────────────────────────────────────────────
@tool
def get_weakness_analysis(user_id: str) -> str:
    """사용자의 운동 기록을 분석하여 약점과 강점을 진단합니다.
    종목별 실패율, 거리별 완주율, 훈련 추세를 분석하여 구체적인 개선 방향을 제시합니다.
    프로그램 생성 전이나 사용자가 "내가 뭐가 부족해?", "약점이 뭐야?" 같은 질문을 할 때 호출하세요."""

    try:
        from app.services.personalization_feedback import WeaknessAnalyzer

        db = _get_firestore_client()
        docs = (
            db.collection("users")
            .document(user_id)
            .collection("workout_logs")
            .order_by("started_at", direction="DESCENDING")
            .limit(12)
            .stream()
        )

        logs = [d for doc in docs if (d := doc.to_dict()) is not None]
        if not logs:
            return json.dumps(
                {"message": "운동 기록이 없어 약점 분석이 불가합니다."},
                ensure_ascii=False,
            )

        result = WeaknessAnalyzer.analyze(logs)
        logger.info(f"약점 분석 완료: {user_id}, {len(result.get('weaknesses', []))}개 약점 감지")
        return json.dumps(result, ensure_ascii=False)

    except Exception as e:
        logger.error(f"약점 분석 실패: {e}")
        return json.dumps({"error": f"약점 분석 실패: {str(e)}"}, ensure_ascii=False)



# ──────────────────────────────────────────────
# Tool 7: 장비 저장
# ──────────────────────────────────────────────
@tool
def save_user_equipment(user_id: str, available_equipment: str) -> str:
    """사용자가 보유한 수영 장비를 저장합니다.
    available_equipment: 쉼표로 구분된 장비 목록 (예: "킥보드,풀부이,핀,패들")
    사용자가 장비에 대해 말할 때 호출하세요."""

    try:
        db = _get_firestore_client()
        equipment_list = [e.strip() for e in available_equipment.split(",") if e.strip()]
        db.collection("users").document(user_id).set(
            {"equipment": equipment_list, "equipment_updated_at": _now_iso()},
            merge=True,
        )
        labels = ", ".join(equipment_list) if equipment_list else "없음"
        logger.info(f"장비 저장 완료: {user_id} → {labels}")
        return json.dumps(
            {"saved": True, "equipment": equipment_list, "message": f"장비 저장 완료: {labels}"},
            ensure_ascii=False,
        )
    except Exception as e:
        logger.error(f"장비 저장 실패: {e}")
        return json.dumps({"error": str(e)}, ensure_ascii=False)


# ──────────────────────────────────────────────
# Tool 8: 장비 조회
# ──────────────────────────────────────────────
@tool
def get_user_equipment(user_id: str) -> str:
    """사용자가 저장한 보유 장비 목록을 조회합니다.
    프로그램 생성 전에 사용자의 장비를 확인할 때 호출하세요."""

    try:
        db = _get_firestore_client()
        doc = db.collection("users").document(user_id).get()
        if not doc.exists:
            return json.dumps({"equipment": [], "message": "등록된 장비가 없습니다."}, ensure_ascii=False)

        data = doc.to_dict() or {}
        equipment = data.get("equipment", [])
        if not equipment:
            return json.dumps({"equipment": [], "message": "등록된 장비가 없습니다."}, ensure_ascii=False)

        return json.dumps(
            {"equipment": equipment, "message": f"보유 장비: {', '.join(equipment)}"},
            ensure_ascii=False,
        )
    except Exception as e:
        logger.error(f"장비 조회 실패: {e}")
        return json.dumps({"error": str(e)}, ensure_ascii=False)


# ──────────────────────────────────────────────
# Tool 9: 컨디션 저장
# ──────────────────────────────────────────────
@tool
def save_condition(user_id: str, condition_level: str, notes: str = "") -> str:
    """사용자의 오늘 컨디션을 저장합니다.
    condition_level: 'great' (최상), 'good' (좋음), 'normal' (보통), 'tired' (피곤), 'exhausted' (매우 피곤) 중 하나
    notes: 추가 메모 (예: "어깨가 좀 아프다", "어제 늦게 잤다")
    사용자가 컨디션, 피로도, 몸 상태에 대해 말할 때 호출하세요."""

    try:
        from datetime import datetime, timezone

        db = _get_firestore_client()
        today = datetime.now(timezone.utc).strftime("%Y-%m-%d")

        valid_levels = {"great", "good", "normal", "tired", "exhausted"}
        if condition_level not in valid_levels:
            condition_level = "normal"

        condition_data = {
            "condition_level": condition_level,
            "notes": notes,
            "recorded_at": _now_iso(),
            "date": today,
        }

        db.collection("users").document(user_id)           .collection("conditions").document(today).set(condition_data)

        level_labels = {
            "great": "최상 💪", "good": "좋음 😊", "normal": "보통 😐",
            "tired": "피곤 😓", "exhausted": "매우 피곤 😩",
        }
        label = level_labels.get(condition_level, condition_level)
        logger.info(f"컨디션 저장 완료: {user_id} → {label}")
        return json.dumps(
            {"saved": True, "condition": condition_level, "label": label, "notes": notes},
            ensure_ascii=False,
        )
    except Exception as e:
        logger.error(f"컨디션 저장 실패: {e}")
        return json.dumps({"error": str(e)}, ensure_ascii=False)


# ──────────────────────────────────────────────
# Tool 10: 컨디션 조회
# ──────────────────────────────────────────────
@tool
def get_today_condition(user_id: str) -> str:
    """사용자의 오늘 컨디션 기록을 조회합니다.
    프로그램 생성 전에 컨디션을 확인하여 강도를 조절할 때 사용합니다."""

    try:
        from datetime import datetime, timezone

        db = _get_firestore_client()
        today = datetime.now(timezone.utc).strftime("%Y-%m-%d")

        doc = db.collection("users").document(user_id)               .collection("conditions").document(today).get()

        if not doc.exists:
            return json.dumps(
                {"has_condition": False, "message": "오늘 컨디션 기록이 없습니다."},
                ensure_ascii=False,
            )

        data = doc.to_dict() or {}
        return json.dumps(
            {
                "has_condition": True,
                "condition_level": data.get("condition_level"),
                "notes": data.get("notes", ""),
                "recorded_at": data.get("recorded_at", ""),
            },
            ensure_ascii=False,
        )
    except Exception as e:
        logger.error(f"컨디션 조회 실패: {e}")
        return json.dumps({"error": str(e)}, ensure_ascii=False)


# ──────────────────────────────────────────────
# Tool 11: 운동 후 메모 저장
# ──────────────────────────────────────────────
@tool
def save_workout_memo(
    user_id: str,
    memo: str,
    difficulty: str = "",
    pain_areas: str = "",
    mood: str = "",
    skipped: str = "",
    skip_reason: str = "",
) -> str:
    """운동 후 사용자의 메모와 피드백을 저장합니다. 운동을 건너뛴 경우에도 사용합니다.
    memo: 자유 메모 (예: "오늘 접영이 많이 좋아졌다", "턴 연습 더 해야겠다")
    difficulty: 체감 난이도 — 'too_easy', 'appropriate', 'too_hard' 중 하나. 없으면 빈 문자열
    pain_areas: 통증 부위 (예: "어깨,허리"). 없으면 빈 문자열
    mood: 운동 후 기분 — 'great', 'good', 'tired', 'frustrated' 중 하나. 없으면 빈 문자열
    skipped: 운동을 건너뛴 경우 "true". 실제로 운동한 경우 빈 문자열
    skip_reason: 스킵 이유 — 'tired', 'busy', 'injured', 'weather', 'other' 중 하나. 없으면 빈 문자열
    운동이 끝난 후 소감/피드백 또는 운동을 하지 않았다고 말할 때 호출하세요."""

    try:
        from datetime import datetime, timezone

        db = _get_firestore_client()
        now = datetime.now(timezone.utc)
        today = now.strftime("%Y-%m-%d")

        is_skipped = skipped.lower().strip() == "true"

        memo_data = {
            "memo": memo,
            "difficulty": difficulty if difficulty in {"too_easy", "appropriate", "too_hard"} else "",
            "pain_areas": [a.strip() for a in pain_areas.split(",") if a.strip()] if pain_areas else [],
            "mood": mood if mood in {"great", "good", "tired", "frustrated"} else "",
            "skipped": is_skipped,
            "recorded_at": _now_iso(),
            "date": today,
        }

        if is_skipped:
            valid_reasons = {"tired", "busy", "injured", "weather", "other"}
            memo_data["skip_reason"] = skip_reason if skip_reason in valid_reasons else "other"

        db.collection("users").document(user_id) \
          .collection("workout_memos").add(memo_data)

        if is_skipped:
            logger.info(f"운동 스킵 기록 저장: {user_id} (사유: {memo_data.get('skip_reason', '')})")
            return json.dumps(
                {"saved": True, "skipped": True, "message": "스킵 기록이 저장되었습니다."},
                ensure_ascii=False,
            )

        logger.info(f"운동 메모 저장 완료: {user_id}")
        return json.dumps(
            {"saved": True, "message": "운동 메모가 저장되었습니다."},
            ensure_ascii=False,
        )
    except Exception as e:
        logger.error(f"운동 메모 저장 실패: {e}")
        return json.dumps({"error": str(e)}, ensure_ascii=False)

# ──────────────────────────────────────────────
# 전체 Tool 목록 (Graph에서 사용)
# ──────────────────────────────────────────────
ALL_TOOLS = [
    get_user_profile,
    get_workout_history,
    generate_program,
    analyze_feedback,
    get_search_history,
    get_weakness_analysis,
    save_user_equipment,
    get_user_equipment,
    save_condition,
    get_today_condition,
    save_workout_memo,
]
