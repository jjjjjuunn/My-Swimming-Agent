import logging
import re
import random
from typing import Optional

from app.models.response import ProgramResponse
from app.services.llm_service import LLMService
from app.services.rag_service import RAGService
from app.services.firebase_service import FirebaseService
from app.services.workout_validator import WorkoutValidator
from app.services.personalization_feedback import (
    PersonalizationFeedback,
    WeaknessAnalyzer,
    get_user_feedback_history,
    get_policy_state_from_firebase,
    save_policy_state_to_firebase,
)
from app.prompts.program_prompts import SYSTEM_PROMPT, build_user_prompt

logger = logging.getLogger(__name__)

# ── 운동 description 검증용 어휘 ─────────────────────────────────
# SYSTEM_PROMPT 섹션 5 드릴 라이브러리 + 운동 유형 + 영법 + 도구에서 추출.
# description에 나타날 수 있는 모든 한국어 2글자 이상 단어.
_VALID_DESC_WORDS: set[str] = {
    # 영법
    "자유형", "접영", "배영", "평영", "혼영", "개인혼영",
    # 운동 유형
    "이지", "수영", "스윔", "스프린트", "드릴", "쿨다운", "워밍업",
    "빌드업", "디센딩", "교대", "순환",
    # 도구
    "킥보드", "풀부이", "스노클", "패들", "오리발",
    # 자유형 드릴
    "캐치업", "핑거팁", "드래그", "스트로크", "편팔",
    "지퍼", "사이드킥", "프런트", "스컬링", "피스트",
    "네거티브", "스플릿", "양측", "호흡", "카운트",
    # 접영 드릴
    "원암", "돌핀킥", "사이드", "돌핀", "바디", "웨이브",
    "타이밍", "풀아웃",
    # 배영 드릴
    "스위치", "더블암", "스핀", "깃발", "피하기",
    "머리", "킥아웃",
    # 평영 드릴
    "글라이드", "풀만", "내로우킥", "헤드업",
    "브레스트", "분리", "동작",
    # 공통 훈련
    "타바타", "언더워터", "라운드",
    # description에 흔히 등장하는 수식어
    "홀수", "짝수", "정점", "하강", "진입", "후반", "전반",
    "가속", "감속", "리셋",
}

# 최소 하나 이상 포함해야 하는 핵심 키워드 (영법 · 운동 유형 · 드릴명)
_CORE_TERMS: set[str] = {
    # 영법
    "자유형", "접영", "배영", "평영", "혼영", "개인혼영", "IM",
    # 운동 유형
    "이지", "스윔", "스프린트", "킥", "드릴", "쿨다운",
    "빌드업", "디센딩",
    # 도구 유형
    "킥보드", "풀부이", "핀", "스노클", "패들", "오리발",
    # 드릴 핵심어
    "캐치업", "핑거팁", "돌핀킥", "편팔", "지퍼", "스컬링",
    "피스트", "원암", "더블암", "타바타", "언더워터",
    "풀아웃", "글라이드", "내로우킥", "헤드업", "분리",
    "네거티브", "스플릿", "양측", "DPS",
}

_STROKE_LABELS: dict[str, str] = {
    "freestyle": "자유형",
    "butterfly": "접영",
    "backstroke": "배영",
    "breaststroke": "평영",
    "IM": "개인혼영",
}

_ALL_STROKE_LABELS: set[str] = {"자유형", "접영", "배영", "평영", "개인혼영", "혼영"}

# 종목별 전용 드릴/표현. description에 이 표현이 있으면 해당 종목에서만 허용한다.
_STROKE_SPECIFIC_PHRASES: dict[str, set[str]] = {
    "자유형": {
        "캐치업",
        "핑거팁 드래그",
        "6킥 1스트로크",
        "프리스타일 편팔",
        "지퍼",
        "프런트 스컬링",
        "피스트 스윔",
        "네거티브 스플릿",
        "양측 호흡",
        "DPS 카운트 수영",
    },
    "접영": {
        "접영 원암",
        "3-3-3 접영",
        "언더워터 돌핀킥",
        "사이드 돌핀킥",
        "접영 바디 웨이브",
        "접영 타이밍",
        "핀 돌핀킥",
        "언더워터 풀아웃",
    },
    "배영": {
        "배영 편팔",
        "6킥 스위치",
        "더블암 배영",
        "배영 사이드킥",
        "배영 스핀",
        "깃발 피하기",
        "배영 머리 위 킥보드 킥",
        "배영 언더워터 킥아웃",
    },
    "평영": {
        "평영 2킥 1풀",
        "평영 글라이드",
        "평영 풀만",
        "평영 킥 온 백",
        "평영 내로우킥",
        "평영 헤드업",
        "브레스트 스컬링",
        "평영 풀아웃",
        "평영 분리 동작",
    },
}


class ProgramGenerator:
    """수영 프로그램 생성 메인 서비스 — 모든 서비스를 조율"""

    def __init__(self):
        self.llm = LLMService()
        self.rag = RAGService()
        self.firebase = FirebaseService()

    async def generate(
        self,
        training_goal: str,
        strokes: list[str],
        user_id: Optional[str] = None,
        equipment: Optional[list[str]] = None,
        purpose: Optional[str] = None,
        user_level: Optional[str] = None,
        user_context: Optional[str] = None,
        pool_length: int = 25,
        pool_unit: str = "m",
    ) -> ProgramResponse:
        """3개 레벨 모두 포함된 하루 운동 프로그램 생성"""

        # 입력 검증
        self._validate_input(training_goal, strokes, equipment)

        logger.info(
            f"프로그램 생성 시작 (3개 레벨) - 목표: {training_goal}, 종목: {strokes}"
        )

        # 0. user_id가 있지만 개인화 정보가 없으면 자동으로 가져옴
        #    (직접 API 호출 경로에서도 개인화 보장)
        target_distance: Optional[int] = None
        if user_id and not user_level and not user_context:
            user_level, user_context, target_distance = await self._build_personalization(user_id)

        # 0-1. 이전 피드백 분석 (P4) — 난이도 조정
        feedback_hint = None
        if user_id:
            # 최소 표본(>=8) 판단을 위해 최근 12회 조회
            feedback_history = await get_user_feedback_history(self.firebase, user_id, limit=12)
            if feedback_history:
                policy_state = await get_policy_state_from_firebase(self.firebase, user_id)
                analysis = PersonalizationFeedback.analyze_feedback_patterns(
                    feedback_history,
                    policy_state=policy_state,
                )
                logger.info(
                    "피드백 분석: "
                    f"sample={analysis.get('sample_size')}, "
                    f"valid_difficulty={analysis.get('valid_difficulty_count')}, "
                    f"ratios={analysis.get('ratios')}, "
                    f"streaks={analysis.get('streaks')}, "
                    f"cooldown={analysis.get('cooldown')}"
                )
                feedback_hint = PersonalizationFeedback.generate_next_program_hint(
                    analysis, user_level or "beginner"
                )
                previous_level = user_level or "beginner"
                if feedback_hint["difficulty_adjustment"] != 0:
                    logger.info(
                        f"피드백 기반 난이도 조정: {feedback_hint['suggested_level']}, "
                        f"거리 {feedback_hint['volume_adjustment_percent']:+.0f}%"
                    )
                    user_level = feedback_hint["suggested_level"]
                elif feedback_hint.get("volume_adjustment_percent", 0) > 0:
                    logger.info(
                        "피드백 기반 단계적 상향: "
                        f"레벨 유지, 거리 {feedback_hint['volume_adjustment_percent']:+.0f}%"
                    )

                # 볼륨 조정 실반영: target_distance가 없으면 레벨 중앙값에서 시작
                volume_delta = float(feedback_hint.get("volume_adjustment_percent", 0.0) or 0.0)
                if volume_delta != 0:
                    effective_level = user_level or previous_level
                    target_distance = self._apply_volume_adjustment(
                        target_distance,
                        effective_level,
                        volume_delta,
                    )
                    logger.info(
                        f"피드백 기반 target_distance 적용: {target_distance}m "
                        f"({volume_delta:+.0f}%)"
                    )

                # 정책 상태 저장: 레벨 변경 이벤트/쿨다운 카운트 영속화
                await save_policy_state_to_firebase(
                    self.firebase,
                    user_id,
                    previous_level=previous_level,
                    suggested_level=user_level or previous_level,
                    difficulty_adjustment=int(feedback_hint.get("difficulty_adjustment", 0) or 0),
                    volume_adjustment_percent=volume_delta,
                    previous_cooldown_remaining=int(
                        (policy_state or {}).get("cooldown_generations_remaining", 0) or 0
                    ),
                )

        # 1. 사용자 검색 이력 분석 (선택)
        search_summary = None
        if user_id:
            history = await self.firebase.get_search_history(user_id)
            search_summary = self.firebase.analyze_search_patterns(history)
            if search_summary:
                logger.info(f"검색 이력 분석: {search_summary}")

        # 2. RAG 관련 문서 검색 (선택)
        rag_context = await self.rag.search_relevant_docs(
            training_goal, strokes
        )
        if rag_context:
            logger.info("RAG 컨텍스트 확보 완료")

        # 3. LLM으로 프로그램 생성 (3개 레벨)
        user_prompt = build_user_prompt(
            training_goal=training_goal,
            strokes=strokes,
            equipment=equipment,
            purpose=purpose,
            search_history_summary=search_summary,
            rag_context=rag_context,
            user_level=user_level,
            user_context=user_context,
            target_distance=target_distance,
            pool_length=pool_length,
            pool_unit=pool_unit,
        )

        raw_result = await self.llm.generate_program_json(
            system_prompt=SYSTEM_PROMPT,
            user_prompt=user_prompt,
        )

        # 3-0. LLM 응답 필수 키 검증
        required_levels = ("beginner", "intermediate", "advanced")
        for lvl in required_levels:
            if lvl not in raw_result or not isinstance(raw_result[lvl], dict):
                logger.warning(f"LLM 응답에 '{lvl}' 누락 → 빈 구조 삽입")
                raw_result[lvl] = {
                    "level": lvl,
                    "level_label": {"beginner": "초급", "intermediate": "중급", "advanced": "고급"}[lvl],
                    "description": "",
                    "warmup": [], "main_set": [], "cooldown": [],
                    "total_distance": 0, "estimated_minutes": 0,
                }

        # 3-1. 환각 드릴명 후처리 검증 & 대체 (장비 description 면제)
        raw_result = self._sanitize_descriptions(raw_result, strokes)

        # 3-2. 워크아웃 구조 검증 및 자동 교정 (P0)
        raw_result, structure_fixes = WorkoutValidator.validate_structure(raw_result)

        # 3-2b. 수영장 길이 거리 교정 — pool_length의 배수가 아닌 거리 보정
        pool_fixes = WorkoutValidator.fix_pool_length_distances(raw_result, pool_length)
        if pool_fixes:
            logger.info(f"수영장 길이 교정: {pool_fixes}건 ({pool_length}{pool_unit} 풀)")

        # 3-3. 강도 안전성 검증 (P3) — 초급 Zone 4-5 차단, 중급 Zone 5 제한
        raw_result, intensity_fixes = WorkoutValidator.validate_intensity_safety(raw_result)

        # 3-4. 사이클 타임 교정 (P1) — 안전 Zone 기준으로 미세 조정
        raw_result, cycle_fixes = WorkoutValidator.validate_and_fix_cycle_times(raw_result, strokes)
        logger.info(
            f"후처리 교정: 구조 {structure_fixes}건, 강도 {intensity_fixes}건, 사이클 {cycle_fixes}건"
        )

        # 3-5. 거리 트리밍 (장비 삽입 전에 실행 → 장비 보호)
        raw_result = self._fix_total_distance(raw_result)

        # 3-6. 장비 포함 여부 검증 & 누락 시 삽입 (트리밍 후)
        raw_result = self._validate_equipment_usage(raw_result, equipment)

        # 3-7. 거리 재확인 (장비 삽입이 상한을 초과시킨 경우 비-장비 운동에서 보상 트리밍)
        if equipment:
            raw_result = self._rebalance_after_equipment(raw_result, equipment)

        # 3-8. estimated_minutes 재계산
        raw_result = self._fix_estimated_minutes(raw_result)

        # 3-9. 레벨 간 거리 일관성 검증 (경고 전용)
        raw_result = WorkoutValidator.validate_cross_level_consistency(raw_result)

        # 3-10. 최종 구조 재검증 (트리밍 후 구조 깨짐 방지)
        raw_result, final_fixes = WorkoutValidator.validate_structure(raw_result)
        if final_fixes:
            logger.info(f"최종 구조 재검증: {final_fixes}건 추가 교정")

        # 4. 응답 모델로 변환 & 검증
        response = ProgramResponse(
            training_goal=training_goal,
            strokes=strokes,
            beginner=raw_result["beginner"],
            intermediate=raw_result["intermediate"],
            advanced=raw_result["advanced"],
        )

        logger.info(
            f"프로그램 생성 완료 (3개 레벨) - "
            f"초급: {response.beginner.total_distance}m, "
            f"중급: {response.intermediate.total_distance}m, "
            f"고급: {response.advanced.total_distance}m"
        )

        return response

    async def _build_personalization(
        self, user_id: str
    ) -> tuple[Optional[str], Optional[str], Optional[int]]:
        """user_id로 Firestore에서 프로필+운동기록을 조회하여 개인화 정보 자동 생성.
        
        Returns:
            (user_level, user_context, target_distance) 튜플
        """
        try:
            from firebase_admin import firestore as fs
            db = fs.client()

            # 프로필 조회
            profile_doc = db.collection("users").document(user_id).get()
            profile = profile_doc.to_dict() if profile_doc.exists else {}

            # 최근 운동 기록 7건 조회
            logs_ref = (
                db.collection("users")
                .document(user_id)
                .collection("workout_logs")
                .order_by("started_at", direction=fs.Query.DESCENDING)
                .limit(7)
            )
            logs = []
            total_planned = 0
            total_completed = 0
            stroke_counts: dict[str, int] = {}
            goal_counts: dict[str, int] = {}

            for doc in logs_ref.stream():
                data = doc.to_dict()
                planned = data.get("planned_distance", 0)
                completed = data.get("completed_distance", 0)
                total_planned += planned
                total_completed += completed

                for s in data.get("strokes", []):
                    stroke_counts[s] = stroke_counts.get(s, 0) + 1
                goal = data.get("training_goal", "")
                if goal:
                    goal_counts[goal] = goal_counts.get(goal, 0) + 1

                sets = data.get("sets", [])
                skipped = sum(
                    1 for s in sets
                    if s.get("status") == "skipped" and s.get("completed_repeat", 0) == 0
                )
                partial = sum(
                    1 for s in sets
                    if s.get("status") == "skipped" and s.get("completed_repeat", 0) > 0
                )
                # 최근 세트 설명 (중복 방지용 — 최대 2회분)
                set_descriptions = [
                    f"{s.get('exercise', '')} {s.get('distance',0)}m×{s.get('repeat',0)}회"
                    for s in sets
                    if s.get("exercise") and s.get("status") != "skipped"
                ]
                logs.append({
                    "date": str(data.get("started_at", "")),
                    "planned": planned,
                    "completed": completed,
                    "level": data.get("level_label", ""),
                    "goal": goal,
                    "skipped_sets": skipped,
                    "partial_sets": partial,
                    "set_descriptions": set_descriptions,
                })

            # ── user_level 결정 ──
            profile_level = profile.get("level", "").lower()
            if logs:
                avg_dist = total_completed / len(logs)
                avg_completion = (total_completed / total_planned * 100) if total_planned > 0 else 0

                if avg_dist >= 2000 and avg_completion >= 85:
                    computed_level = "advanced"
                elif avg_dist >= 800 and avg_completion >= 60:
                    computed_level = "intermediate"
                else:
                    computed_level = "beginner"

                # 실제 기록 기반 레벨 우선, 프로필은 참고
                user_level = computed_level

                # ── target_distance 계산 ──
                _level_ranges = {
                    "beginner": (800, 1200),
                    "intermediate": (1500, 2500),
                    "advanced": (2500, 4000),
                }
                if avg_completion >= 90:
                    growth = 0.10   # 잘 수행 → 10% 성장 유도
                elif avg_completion >= 70:
                    growth = 0.0    # 적절 → 유지
                else:
                    growth = -0.10  # 힘들어함 → 10% 감소
                raw_target = round(avg_dist * (1 + growth))
                lo, hi = _level_ranges.get(computed_level, (800, 4000))
                target_distance = max(lo, min(hi, raw_target))
            else:
                user_level = profile_level if profile_level in {"beginner", "intermediate", "advanced"} else None
                target_distance = None

            # ── user_context 구성 ──
            context_parts = []

            if profile.get("displayName"):
                context_parts.append(f"이름: {profile['displayName']}")
            if profile.get("purpose"):
                context_parts.append(f"수영 목적: {profile['purpose']}")
            if profile.get("favoriteStrokes"):
                context_parts.append(f"선호 영법: {', '.join(profile['favoriteStrokes'])}")
            if profile.get("goals"):
                context_parts.append(f"목표: {', '.join(profile['goals'])}")

            if logs:
                avg_dist = round(total_completed / len(logs))
                avg_comp = round(total_completed / total_planned * 100, 1) if total_planned > 0 else 0
                context_parts.append(f"최근 {len(logs)}회 훈련, 세션당 평균 {avg_dist}m 완주")
                context_parts.append(f"평균 완주율 {avg_comp}%")

                if stroke_counts:
                    top_strokes = sorted(stroke_counts.items(), key=lambda x: -x[1])
                    stroke_text = ", ".join(f"{s}({c}회)" for s, c in top_strokes)
                    context_parts.append(f"종목 분포: {stroke_text}")

                if goal_counts:
                    top_goals = sorted(goal_counts.items(), key=lambda x: -x[1])
                    goal_text = ", ".join(f"{g}({c}회)" for g, c in top_goals)
                    context_parts.append(f"최근 훈련 목표: {goal_text}")

                # 스킵/중도포기 패턴 분석
                total_skipped = sum(l["skipped_sets"] for l in logs)
                total_partial = sum(l["partial_sets"] for l in logs)
                if total_skipped > 3:
                    context_parts.append(f"전체 스킵한 세트 {total_skipped}개 — 난이도 조절 필요")
                if total_partial > 0:
                    context_parts.append(f"중도포기(일부만 완료) 세트 {total_partial}개 — 해당 운동 강도 재검토 권장")

                # 약점 분석 요약 (코치 맞춤 프로그램을 위한 핵심 정보)
                try:
                    raw_logs = []
                    for doc in logs_ref.stream():
                        raw_logs.append(doc.to_dict())
                    if raw_logs:
                        weakness_report = WeaknessAnalyzer.analyze(raw_logs)
                        if weakness_report.get("has_enough_data"):
                            summary = weakness_report.get("summary", "")
                            insight = weakness_report.get("training_insight", "")
                            if summary:
                                context_parts.append(f"약점 분석: {summary}")
                            if insight:
                                context_parts.append(f"훈련 제안: {insight}")
                except Exception as e:
                    logger.debug(f"약점 분석 스킵: {e}")

                # 최근 2회 훈련의 세트 구성 (중복 방지용)
                recent_sets_info = []
                for i, log in enumerate(logs[:2]):
                    descs = log.get("set_descriptions", [])
                    if descs:
                        label = ["가장 최근", "2회 전"][i]
                        recent_sets_info.append(f"  [{label}] 목표={log['goal']}: {', '.join(descs[:6])}")
                if recent_sets_info:
                    context_parts.append(
                        "최근 훈련 세트 구성 (이와 다른 구성으로 변화를 줄 것):\n" + "\n".join(recent_sets_info)
                    )
            else:
                context_parts.append("운동 기록 없음 — 신규 사용자, 보수적으로 설계 권장")

            user_context = "\n".join(context_parts) if context_parts else None

            logger.info(f"자동 개인화 생성: level={user_level}, target_distance={target_distance}")
            return user_level, user_context, target_distance

        except Exception as e:
            logger.warning(f"개인화 정보 자동 생성 실패 (무시): {e}")
            return None, None, None

    # ── 환각 드릴명 검증 ──────────────────────────────────────────

    @staticmethod
    def _extract_korean_words(text: str) -> list[str]:
        """텍스트에서 한국어 2글자 이상 단어 추출"""
        return re.findall(r"[가-힣]{2,}", text)

    @staticmethod
    def _requested_stroke_labels(strokes: list[str]) -> set[str]:
        """요청 종목 코드를 한국어 라벨 집합으로 변환."""
        labels = {_STROKE_LABELS[s] for s in strokes if s in _STROKE_LABELS}
        if "개인혼영" in labels:
            return set(_ALL_STROKE_LABELS)
        return labels

    @staticmethod
    def _description_stroke_labels(description: str) -> set[str]:
        """description에 직접 언급된 영법 라벨 추출."""
        found = {label for label in _ALL_STROKE_LABELS if label in description}
        if "개인혼영" in found or "혼영" in found:
            return set(_ALL_STROKE_LABELS)
        return found

    @staticmethod
    def _matched_phrase_strokes(description: str) -> set[str]:
        """description에 포함된 종목 전용 드릴이 어떤 영법 소속인지 추출."""
        matched: set[str] = set()
        for stroke_label, phrases in _STROKE_SPECIFIC_PHRASES.items():
            if any(phrase in description for phrase in phrases):
                matched.add(stroke_label)
        return matched

    @classmethod
    def _is_stroke_compatible(cls, description: str, strokes: list[str]) -> bool:
        """종목 전용 드릴이 요청 종목/명시 종목과 호환되는지 검증."""
        matched_strokes = cls._matched_phrase_strokes(description)
        if not matched_strokes:
            return True

        explicit_strokes = cls._description_stroke_labels(description)
        context_strokes = explicit_strokes or cls._requested_stroke_labels(strokes)
        if not context_strokes:
            return True

        return matched_strokes.issubset(context_strokes)

    _EQUIPMENT_KEYWORDS = {"킥보드", "풀부이", "핀", "오리발", "스노클", "패들"}

    @classmethod
    def _is_valid_description(cls, description: str, strokes: list[str]) -> bool:
        """description이 드릴 라이브러리·운동 유형 어휘에 부합하는지 검증. (P2 강화)

        조건 0: 장비 키워드 포함 시 면제 (사용자 요청 장비는 환각이 아님)
        조건 1: 핵심 키워드(영법/운동유형/드릴명) 최소 1개 포함
        조건 2: 한국어 단어 중 60% 이상이 인식된 어휘 (개선)
        조건 3: 종목 전용 드릴은 해당 종목과만 조합 가능
        조건 4: 드릴명 정확도 검사 (P2 신규)
        """
        if any(eq in description for eq in cls._EQUIPMENT_KEYWORDS):
            return True

        # 조건 1 — 핵심 키워드 존재
        has_core = any(term in description for term in _CORE_TERMS)
        if not has_core:
            return False

        # 조건 2 — 미인식 한국어 비율 체크
        korean_words = cls._extract_korean_words(description)
        if not korean_words:
            return has_core

        unknown = [w for w in korean_words if w not in _VALID_DESC_WORDS]
        # 미인식 단어가 40% 초과 → 환각 가능성 (개선)
        if len(unknown) > len(korean_words) * 0.4:
            return False

        # 조건 3 — 종목 호환성
        if not cls._is_stroke_compatible(description, strokes):
            return False

        # 조건 4 — 드릴명 정확도 (P2 신규)
        all_valid_drills = set()
        for phrases in _STROKE_SPECIFIC_PHRASES.values():
            all_valid_drills.update(phrases)
        
        return WorkoutValidator.check_drill_name_accuracy(description, all_valid_drills)

    def _sanitize_descriptions(
        self, raw_result: dict, strokes: list[str]
    ) -> dict:
        """LLM 생성 결과의 모든 exercise description을 검증하고,
        환각 드릴명이 발견되면 같은 종목의 유효한 드릴로 치환."""

        stroke_labels = {
            "freestyle": "자유형", "butterfly": "접영",
            "backstroke": "배영", "breaststroke": "평영",
            "IM": "개인혼영",
        }
        primary_stroke = stroke_labels.get(
            strokes[0] if strokes else "freestyle", "자유형"
        )

        replaced_count = 0
        for level_key in ("beginner", "intermediate", "advanced"):
            level_data = raw_result.get(level_key, {})
            for section in ("warmup", "main_set", "cooldown"):
                exercises = level_data.get(section, [])
                for ex in exercises:
                    desc = ex.get("description", "")
                    if not self._is_valid_description(desc, strokes):
                        fallback = self._smart_fallback_description(
                            desc, section, primary_stroke, strokes
                        )
                        logger.warning(
                            f"환각 description 감지 [{level_key}/{section}]: "
                            f"'{desc}' → '{fallback}'"
                        )
                        ex["description"] = fallback
                        replaced_count += 1

        if replaced_count:
            logger.info(f"총 {replaced_count}개 환각 description 대체 완료")
        return raw_result

    @staticmethod
    def _get_valid_drills_for_stroke(stroke: str) -> list[str]:
        """종목별 유효한 드릴 목록 반환."""
        return sorted(list(_STROKE_SPECIFIC_PHRASES.get(stroke, [])))

    _WARMUP_SAFE_DRILLS: dict[str, list[str]] = {
        "자유형": ["캐치업", "핑거팁 드래그", "사이드킥 드릴", "양측 호흡 드릴"],
        "접영": ["접영 바디 웨이브 드릴", "사이드 돌핀킥"],
        "배영": ["배영 편팔 드릴", "배영 사이드킥"],
        "평영": ["평영 글라이드 드릴", "평영 킥 온 백 드릴"],
    }

    @classmethod
    def _smart_fallback_description(
        cls, original: str, section: str, stroke: str, strokes: list[str]
    ) -> str:
        """섹션 맥락을 고려하여 적절한 폴백 description 선택."""
        if section == "warmup":
            safe = cls._WARMUP_SAFE_DRILLS.get(stroke, [])
            if safe:
                return f"{stroke} {random.choice(safe)}"
            return f"{stroke} 이지 수영"
        elif section == "cooldown":
            return f"{stroke} 이지 쿨다운"
        else:
            valid_drills = cls._get_valid_drills_for_stroke(stroke)
            if valid_drills:
                return f"{stroke} {random.choice(valid_drills)}"
            return f"{stroke} 스윔"

    _LEVEL_DISTANCE_RANGES: dict[str, tuple[int, int]] = {
        "beginner": (800, 1200),
        "intermediate": (1500, 2500),
        "advanced": (2500, 4000),
    }

    @classmethod
    def _compute_level_distance(cls, level: dict) -> int:
        """레벨 내 모든 운동의 총 거리 계산."""
        total = 0
        for section in ("warmup", "main_set", "cooldown"):
            for ex in level.get(section, []):
                total += ex.get("distance", 0) * ex.get("repeat", 1)
        return total

    @classmethod
    def _trim_main_set(
        cls, main_set: list[dict], excess: int,
        protected_keywords: set[str] | None = None,
    ) -> int:
        """main_set에서 excess 거리만큼 트리밍. protected_keywords가 있으면 해당 운동은 보호.
        Returns: 실제 트리밍한 거리."""
        protected = protected_keywords or set()
        trimmed = 0

        trimmable = [
            ex for ex in reversed(main_set)
            if not any(kw in ex.get("description", "") for kw in protected)
        ]

        for ex in trimmable:
            if trimmed >= excess:
                break
            dist = ex.get("distance", 0)
            rpt = ex.get("repeat", 1)
            while rpt > 1 and trimmed < excess:
                rpt -= 1
                trimmed += dist
            ex["repeat"] = rpt
            if rpt <= 1 and trimmed < excess and len(main_set) > 3:
                trimmed += dist
                main_set.remove(ex)

        return trimmed

    @classmethod
    def _fix_total_distance(cls, raw_result: dict) -> dict:
        """total_distance를 실제 합산으로 교정. 상한 초과 시 강제 트리밍 + 하드 클램프."""
        for level_key in ("beginner", "intermediate", "advanced"):
            level = raw_result.get(level_key, {})
            computed = cls._compute_level_distance(level)
            old_val = level.get("total_distance")
            if old_val != computed:
                logger.info(
                    f"[{level_key}] total_distance 교정: "
                    f"LLM={old_val}m → 실제={computed}m"
                )

            lo, hi = cls._LEVEL_DISTANCE_RANGES.get(level_key, (0, 99999))

            if computed > hi:
                excess = computed - hi
                main_set = level.get("main_set", [])
                trimmed = cls._trim_main_set(main_set, excess)
                computed -= trimmed

                if computed > hi:
                    remaining = computed - hi
                    for ex in reversed(main_set):
                        if remaining <= 0:
                            break
                        dist = ex.get("distance", 0)
                        rpt = ex.get("repeat", 1)
                        while rpt > 1 and remaining > 0:
                            rpt -= 1
                            remaining -= dist
                        ex["repeat"] = rpt
                    computed = cls._compute_level_distance(level)

                logger.warning(
                    f"[{level_key}] total_distance {old_val}m → "
                    f"{computed}m (상한 {hi}m 적용)"
                )

            if computed < lo:
                logger.warning(
                    f"[{level_key}] total_distance {computed}m — "
                    f"권장 하한({lo}m) 미달, 볼륨 부족 가능"
                )

            level["total_distance"] = computed
        return raw_result

    @classmethod
    def _rebalance_after_equipment(
        cls, raw_result: dict, equipment: list[str] | None
    ) -> dict:
        """장비 삽입 후 상한 초과 시, 장비 운동을 보호하면서 비-장비 운동만 트리밍."""
        if not equipment:
            return raw_result

        eq_keywords = {"킥보드", "풀부이", "핀", "오리발", "스노클", "패들"}

        for level_key in ("beginner", "intermediate", "advanced"):
            level = raw_result.get(level_key, {})
            computed = cls._compute_level_distance(level)
            _, hi = cls._LEVEL_DISTANCE_RANGES.get(level_key, (0, 99999))

            if computed > hi:
                excess = computed - hi
                main_set = level.get("main_set", [])
                trimmed = cls._trim_main_set(main_set, excess, eq_keywords)
                computed -= trimmed
                if trimmed:
                    logger.info(
                        f"[{level_key}] 장비 삽입 후 보상 트리밍: "
                        f"{trimmed}m 감소 → {computed}m"
                    )

            level["total_distance"] = computed
        return raw_result

    @staticmethod
    def _fix_estimated_minutes(raw_result: dict) -> dict:
        """cycle_time 합산 기반으로 estimated_minutes 재계산."""
        for level_key in ("beginner", "intermediate", "advanced"):
            level = raw_result.get(level_key, {})
            total_seconds = 0
            for section in ("warmup", "main_set", "cooldown"):
                for ex in level.get(section, []):
                    ct = ex.get("cycle_time", "")
                    repeat = ex.get("repeat", 1)
                    parsed = WorkoutValidator.parse_cycle_time(ct) if ct else None
                    if parsed:
                        total_seconds += parsed * repeat
                    else:
                        dist = ex.get("distance", 0)
                        total_seconds += (dist / 100.0) * 150 * repeat
            computed_minutes = max(1, round(total_seconds / 60))
            old = level.get("estimated_minutes")
            if old and abs(old - computed_minutes) > 5:
                logger.info(
                    f"[{level_key}] estimated_minutes 교정: "
                    f"LLM={old}분 → 계산={computed_minutes}분"
                )
            level["estimated_minutes"] = computed_minutes
        return raw_result

    @staticmethod
    def _validate_equipment_usage(
        raw_result: dict,
        equipment: list[str] | None,
    ) -> dict:
        """요청된 장비가 description에 포함되었는지 검증, 누락 시 삽입."""
        if not equipment:
            return raw_result

        _eq_keywords: dict[str, list[str]] = {
            "fins": ["핀", "오리발"],
            "snorkel": ["스노클"],
            "paddles": ["패들"],
            "kickboard": ["킥보드"],
            "pull_buoy": ["풀부이"],
        }
        _eq_exercises: dict[str, dict] = {
            "fins": {
                "description": "핀 스윔",
                "distance": 50, "repeat": 4,
                "rest_seconds": 15, "cycle_time": "1:15",
                "notes": "Zone 2 (숨이 살짝 차는 강도), 오리발로 고속 감각 훈련, 킥 파워 향상",
            },
            "snorkel": {
                "description": "스노클 드릴",
                "distance": 50, "repeat": 4,
                "rest_seconds": 15, "cycle_time": "1:20",
                "notes": "Zone 1~2, 호흡 제거로 자세·스트로크 집중",
            },
            "paddles": {
                "description": "패들 자유형",
                "distance": 50, "repeat": 4,
                "rest_seconds": 15, "cycle_time": "1:15",
                "notes": "Zone 2~3, catch 면적 확대로 근력·감각 향상",
            },
            "kickboard": {
                "description": "킥보드 킥",
                "distance": 50, "repeat": 4,
                "rest_seconds": 15, "cycle_time": "1:40",
                "notes": "Zone 2 (숨이 살짝 차는 강도), 킥 고립 훈련, 고관절 시작",
            },
            "pull_buoy": {
                "description": "풀부이 자유형",
                "distance": 50, "repeat": 4,
                "rest_seconds": 15, "cycle_time": "1:15",
                "notes": "Zone 2, 다리 고정 상체 풀 집중, 상체 근지구력",
            },
        }

        for eq in equipment:
            keywords = _eq_keywords.get(eq, [])
            if not keywords:
                continue

            for level_key in ("beginner", "intermediate", "advanced"):
                level_data = raw_result.get(level_key, {})
                found = False
                for section in ("warmup", "main_set", "cooldown"):
                    for ex in level_data.get(section, []):
                        desc = ex.get("description", "")
                        if any(kw in desc for kw in keywords):
                            found = True
                            break
                    if found:
                        break

                if not found and eq in _eq_exercises:
                    level_data.setdefault("main_set", []).append(
                        dict(_eq_exercises[eq])
                    )
                    logger.warning(
                        f"[{level_key}] 장비 '{eq}' 누락 → "
                        f"'{_eq_exercises[eq]['description']}' 삽입"
                    )
        return raw_result

    def _validate_input(
        self, training_goal: str, strokes: list[str], equipment: Optional[list[str]] = None
    ):
        """입력값 검증"""

        valid_goals = {"speed", "endurance", "technique", "overall"}
        valid_strokes = {
            "freestyle", "butterfly", "backstroke", "breaststroke", "IM",
        }
        valid_equipment = {
            "fins", "snorkel", "paddles", "kickboard", "pull_buoy",
        }

        if training_goal not in valid_goals:
            raise ValueError(
                f"유효하지 않은 훈련 목표: {training_goal}. "
                f"허용: {valid_goals}"
            )

        invalid_strokes = set(strokes) - valid_strokes
        if invalid_strokes:
            raise ValueError(
                f"유효하지 않은 종목: {invalid_strokes}. "
                f"허용: {valid_strokes}"
            )

        if equipment:
            invalid_equipment = set(equipment) - valid_equipment
            if invalid_equipment:
                raise ValueError(
                    f"유효하지 않은 도구: {invalid_equipment}. "
                    f"허용: {valid_equipment}"
                )

    @staticmethod
    def _level_distance_range(level: Optional[str]) -> tuple[int, int]:
        ranges = {
            "beginner": (800, 1200),
            "intermediate": (1500, 2500),
            "advanced": (2500, 4000),
        }
        return ranges.get(level or "beginner", (800, 1200))

    @classmethod
    def _apply_volume_adjustment(
        cls,
        base_target_distance: Optional[int],
        level: Optional[str],
        adjustment_percent: float,
    ) -> int:
        """피드백 기반 볼륨 조정값을 목표 거리로 반영하고 레벨 범위로 클램프."""
        lo, hi = cls._level_distance_range(level)
        base = base_target_distance if base_target_distance is not None else round((lo + hi) / 2)
        adjusted = round(base * (1 + (adjustment_percent / 100.0)))
        return max(lo, min(hi, adjusted))
