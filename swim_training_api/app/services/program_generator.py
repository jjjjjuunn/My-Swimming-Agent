import logging
import re
from typing import Optional

from app.models.response import ProgramResponse
from app.services.llm_service import LLMService
from app.services.rag_service import RAGService
from app.services.firebase_service import FirebaseService
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
    "타비아타", "언더워터", "라운드",
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
    "피스트", "원암", "더블암", "타비아타", "언더워터",
    "풀아웃", "글라이드", "내로우킥", "헤드업", "분리",
    "네거티브", "스플릿", "양측", "DPS",
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
        )

        raw_result = await self.llm.generate_program_json(
            system_prompt=SYSTEM_PROMPT,
            user_prompt=user_prompt,
        )

        # 3-1. 환각 드릴명 후처리 검증 & 대체
        raw_result = self._sanitize_descriptions(raw_result, strokes)

        # 3-2. total_distance 재계산 (LLM 산술 오류 보정)
        raw_result = self._fix_total_distance(raw_result)

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
                    f"{s.get('exercise', '')} {s.get('distance',0)}m×{s.get('repeat',0)}웸"
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

    @classmethod
    def _is_valid_description(cls, description: str) -> bool:
        """description이 드릴 라이브러리·운동 유형 어휘에 부합하는지 검증.

        조건 1: 핵심 키워드(영법/운동유형/드릴명) 최소 1개 포함
        조건 2: 한국어 단어 중 50% 이상이 인식된 어휘
        """
        # 조건 1 — 핵심 키워드 존재
        has_core = any(term in description for term in _CORE_TERMS)
        if not has_core:
            return False

        # 조건 2 — 미인식 한국어 비율 체크
        korean_words = cls._extract_korean_words(description)
        if not korean_words:
            return has_core  # 한국어 없이 영어/숫자만(예: "IM") → 조건1 통과면 OK

        unknown = [w for w in korean_words if w not in _VALID_DESC_WORDS]
        # 미인식 단어가 절반 초과 → 환각 가능성
        if len(unknown) > len(korean_words) * 0.5:
            return False

        return True

    def _sanitize_descriptions(
        self, raw_result: dict, strokes: list[str]
    ) -> dict:
        """LLM 생성 결과의 모든 exercise description을 검증하고,
        환각 드릴명이 발견되면 안전한 대체 텍스트로 교체."""

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
                    if not self._is_valid_description(desc):
                        fallback = self._fallback_description(
                            section, primary_stroke
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
    def _fallback_description(section: str, stroke: str) -> str:
        """환각 description에 대한 안전한 대체 텍스트"""
        if section == "warmup":
            return f"{stroke} 이지 수영"
        elif section == "cooldown":
            return f"{stroke} 이지 쿨다운"
        else:
            return f"{stroke} 스윔"

    @staticmethod
    def _fix_total_distance(raw_result: dict) -> dict:
        """LLM이 출력한 total_distance를 실제 exercise 합산으로 교정."""
        for level_key in ("beginner", "intermediate", "advanced"):
            level = raw_result.get(level_key, {})
            computed = 0
            for section in ("warmup", "main_set", "cooldown"):
                for ex in level.get(section, []):
                    computed += ex.get("distance", 0) * ex.get("repeat", 1)
            old = level.get("total_distance")
            if old != computed:
                logger.info(
                    f"[{level_key}] total_distance 교정: "
                    f"LLM={old}m → 실제={computed}m"
                )
            level["total_distance"] = computed
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
