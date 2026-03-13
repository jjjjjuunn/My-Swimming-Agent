"""개인화 피드백 시스템 (P4)"""
import logging
from typing import Optional
from datetime import datetime

logger = logging.getLogger(__name__)


class PersonalizationFeedback:
    """사용자 피드백 수집 및 학습 (P4)"""

    # ── 운영 기준값 (Startup-grade 안정성) ─────────────────────
    MIN_SAMPLES_FOR_LEVEL_CHANGE = 8
    MIN_SAMPLES_FOR_DOWNGRADE = 5
    UPSHIFT_RATIO_THRESHOLD = 0.70
    DOWNSHIFT_RATIO_THRESHOLD = 0.50
    MIN_COMPLETION_FOR_UPSHIFT = 90.0
    MAX_SKIPPED_FOR_UPSHIFT = 1.0
    LOW_COMPLETION_FOR_DOWNGRADE = 75.0
    UPSHIFT_CONFIRM_STREAK = 3
    DEFAULT_LEVEL_CHANGE_COOLDOWN_SESSIONS = 3

    # Firebase에 저장할 피드백 스키마
    FEEDBACK_SCHEMA = {
        "workout_id": str,  # 생성된 워크아웃 ID
        "user_id": str,
        "level": str,  # beginner/intermediate/advanced
        "training_goal": str,
        "created_at": datetime,
        "completed_at": Optional[datetime],
        "feedback": {
            "difficulty": str,  # 'too_easy', 'appropriate', 'too_hard'
            "pacing": str,  # 'too_slow', 'appropriate', 'too_fast'
            "volume": str,  # 'too_short', 'appropriate', 'too_long'
            "drill_relevance": int,  # 0~5 점수 (드릴의 실용성)
            "notes": str,  # 자유 피드백
            "completion_rate": float,  # 0~100 (%)
            "skipped_sets": int,  # 스킵한 세트 수
            "partial_completion_sets": int,  # 중도포기 세트 수
            "duration_minutes": int,  # 실제 소요 시간
        },
        "submitted_at": datetime,
    }

    @staticmethod
    def create_feedback_entry(
        workout_id: str,
        user_id: str,
        level: str,
        training_goal: str,
    ) -> dict:
        """새로운 피드백 엔트리 생성 (초기값)"""
        return {
            "workout_id": workout_id,
            "user_id": user_id,
            "level": level,
            "training_goal": training_goal,
            "created_at": datetime.utcnow().isoformat(),
            "feedback": {
                "difficulty": None,
                "pacing": None,
                "volume": None,
                "drill_relevance": 0,
                "notes": "",
                "completion_rate": 0.0,
                "skipped_sets": 0,
                "partial_completion_sets": 0,
                "duration_minutes": 0,
                # Optional runtime metadata for policy controls.
                # level_changed: 이번 세션 직전/직후 레벨 변경 적용 여부
                # cooldown_sessions: 변경 후 추가 레벨 변경 금지 세션 수
                "meta": {
                    "level_changed": False,
                    "cooldown_sessions": PersonalizationFeedback.DEFAULT_LEVEL_CHANGE_COOLDOWN_SESSIONS,
                },
            },
            "submitted_at": None,
        }

    @staticmethod
    def _count_valid_difficulty(feedback_list: list[dict]) -> int:
        count = 0
        for fb in feedback_list:
            d = fb.get("feedback", {}).get("difficulty")
            if d in {"too_easy", "too_hard", "appropriate"}:
                count += 1
        return count

    @staticmethod
    def _consecutive_difficulty_streak(feedback_list: list[dict], target: str) -> int:
        """최신 기록부터 target difficulty 연속 횟수 계산.

        feedback_list는 created_at DESC(최신순)이라고 가정.
        """
        streak = 0
        for fb in feedback_list:
            d = fb.get("feedback", {}).get("difficulty")
            if d == target:
                streak += 1
            else:
                break
        return streak

    @staticmethod
    def _sessions_since_last_level_change(feedback_list: list[dict]) -> int:
        """마지막 레벨 변경 이후 경과 세션 수 계산."""
        sessions = 0
        for fb in feedback_list:
            meta = fb.get("feedback", {}).get("meta", {})
            if meta.get("level_changed"):
                return sessions
            sessions += 1
        return sessions

    @staticmethod
    def analyze_feedback_patterns(
        feedback_list: list[dict], policy_state: Optional[dict] = None
    ) -> dict:
        """사용자 피드백 패턴 분석 → 난이도/볼륨 조정 가이드"""
        if not feedback_list:
            return {"actions": [], "confidence": 0.0}

        patterns = {
            "too_easy_count": 0,
            "too_hard_count": 0,
            "appropriate_count": 0,
            "avg_completion_rate": 0.0,
            "avg_skipped_sets": 0,
            "avg_duration_minutes": 0,
        }

        total_feedback = len(feedback_list)
        valid_difficulty_count = PersonalizationFeedback._count_valid_difficulty(feedback_list)

        for fb in feedback_list:
            feedback_data = fb.get("feedback", {})

            if feedback_data.get("difficulty") == "too_easy":
                patterns["too_easy_count"] += 1
            elif feedback_data.get("difficulty") == "too_hard":
                patterns["too_hard_count"] += 1
            elif feedback_data.get("difficulty") == "appropriate":
                patterns["appropriate_count"] += 1

            patterns["avg_completion_rate"] += feedback_data.get("completion_rate", 0)
            patterns["avg_skipped_sets"] += feedback_data.get("skipped_sets", 0)
            patterns["avg_duration_minutes"] += feedback_data.get("duration_minutes", 0)

        # 평균값 계산 — completion_rate > 0인 제출 완료 데이터만 분모로 사용
        completed_count = sum(
            1 for fb in feedback_list
            if fb.get("feedback", {}).get("completion_rate", 0) > 0
        )
        rate_denominator = completed_count if completed_count > 0 else total_feedback
        patterns["avg_completion_rate"] /= rate_denominator
        patterns["avg_skipped_sets"] /= total_feedback
        patterns["avg_duration_minutes"] /= total_feedback

        # 조정 가이드 생성
        actions = []
        confidence = 0.0

        denominator = valid_difficulty_count if valid_difficulty_count else total_feedback
        easy_ratio = patterns["too_easy_count"] / denominator
        hard_ratio = patterns["too_hard_count"] / denominator
        appropriate_ratio = patterns["appropriate_count"] / denominator

        too_easy_streak = PersonalizationFeedback._consecutive_difficulty_streak(
            feedback_list, "too_easy"
        )
        too_hard_streak = PersonalizationFeedback._consecutive_difficulty_streak(
            feedback_list, "too_hard"
        )

        sessions_since_change = PersonalizationFeedback._sessions_since_last_level_change(
            feedback_list
        )
        cooldown_sessions = feedback_list[0].get("feedback", {}).get("meta", {}).get(
            "cooldown_sessions", PersonalizationFeedback.DEFAULT_LEVEL_CHANGE_COOLDOWN_SESSIONS
        )
        in_cooldown = sessions_since_change < cooldown_sessions

        if policy_state:
            remaining = int(policy_state.get("cooldown_generations_remaining", 0) or 0)
            # 운영 상태가 있으면 우선 적용 (피드백 지연 입력 대비)
            if remaining > 0:
                in_cooldown = True
                cooldown_sessions = remaining
                sessions_since_change = 0

        upshift_candidate = (
            denominator >= PersonalizationFeedback.MIN_SAMPLES_FOR_LEVEL_CHANGE
            and easy_ratio >= PersonalizationFeedback.UPSHIFT_RATIO_THRESHOLD
            and patterns["avg_completion_rate"] >= PersonalizationFeedback.MIN_COMPLETION_FOR_UPSHIFT
            and patterns["avg_skipped_sets"] <= PersonalizationFeedback.MAX_SKIPPED_FOR_UPSHIFT
        )

        downshift_candidate = (
            denominator >= PersonalizationFeedback.MIN_SAMPLES_FOR_DOWNGRADE
            and (
                hard_ratio >= PersonalizationFeedback.DOWNSHIFT_RATIO_THRESHOLD
                or patterns["avg_completion_rate"] < PersonalizationFeedback.LOW_COMPLETION_FOR_DOWNGRADE
            )
        )

        # 안전 우선: 하향 신호가 있으면 상향보다 우선한다.
        if downshift_candidate:
            actions.append({
                "type": "decrease_difficulty",
                "reason": (
                    f"난이도 과부하 신호 감지 "
                    f"(hard_ratio={hard_ratio:.0%}, avg_completion={patterns['avg_completion_rate']:.1f}%)"
                ),
                "suggestion": "난이도 -1, 거리 -8~12%, 인터벌 완화",
                "safeguards": {
                    "denominator": denominator,
                    "too_hard_streak": too_hard_streak,
                },
            })
            confidence = max(hard_ratio, 1 - (patterns["avg_completion_rate"] / 100))

        elif upshift_candidate:
            if in_cooldown:
                actions.append({
                    "type": "maintain_level",
                    "reason": (
                        f"상향 조건 충족이나 쿨다운 중 "
                        f"({sessions_since_change}/{cooldown_sessions}세션 경과)"
                    ),
                    "suggestion": "현재 레벨 유지, 품질 지표 관찰",
                })
            elif too_easy_streak >= PersonalizationFeedback.UPSHIFT_CONFIRM_STREAK:
                actions.append({
                    "type": "increase_difficulty",
                    "reason": (
                        f"상향 조건 충족 "
                        f"(easy_ratio={easy_ratio:.0%}, completion={patterns['avg_completion_rate']:.1f}%, "
                        f"too_easy_streak={too_easy_streak})"
                    ),
                    "suggestion": "난이도 +1, 거리 +8~12%, 인터벌 소폭 단축",
                    "safeguards": {
                        "denominator": denominator,
                        "cooldown_passed": True,
                    },
                })
                confidence = easy_ratio
            else:
                actions.append({
                    "type": "increase_volume_only",
                    "reason": (
                        f"상향 전 단계: 조건 충족했지만 연속성 부족 "
                        f"(too_easy_streak={too_easy_streak}/{PersonalizationFeedback.UPSHIFT_CONFIRM_STREAK})"
                    ),
                    "suggestion": "레벨 유지 + 볼륨 8% 증가 후 재평가",
                })
                confidence = easy_ratio * 0.8

        else:
            actions.append({
                "type": "maintain_level",
                "reason": (
                    "레벨 변경 조건 미충족 "
                    f"(sample={denominator}, easy={easy_ratio:.0%}, hard={hard_ratio:.0%})"
                ),
                "suggestion": "현재 레벨 유지, 추가 피드백 확보",
            })

        has_difficulty_change = any(a["type"] in ("decrease_difficulty", "increase_difficulty") for a in actions)
        if patterns["avg_completion_rate"] < 70 and not has_difficulty_change:
            actions.append({
                "type": "reduce_volume",
                "reason": f"평균 완주율 {patterns['avg_completion_rate']:.0f}% (70% 미만)",
                "suggestion": "거리 -5~10% 또는 세트 수 감소",
            })

        if patterns["avg_skipped_sets"] > 2:
            actions.append({
                "type": "review_drill_selection",
                "reason": f"세션당 평균 {patterns['avg_skipped_sets']:.1f}개 세트 스킵",
                "suggestion": "특정 드릴 유형 재검토, 더 쉬운 드릴로 대체",
            })

        # pacing 피드백 반영
        too_fast_count = sum(
            1 for fb in feedback_list
            if fb.get("feedback", {}).get("pacing") == "too_fast"
        )
        too_slow_count = sum(
            1 for fb in feedback_list
            if fb.get("feedback", {}).get("pacing") == "too_slow"
        )
        if too_fast_count > total_feedback * 0.4:
            actions.append({
                "type": "adjust_pacing",
                "reason": f"사용자 {too_fast_count}/{total_feedback}회 '너무 빠르다' 응답",
                "suggestion": "사이클 타임 +5~10초 여유, Zone 한 단계 낮추기",
            })
        elif too_slow_count > total_feedback * 0.4:
            actions.append({
                "type": "adjust_pacing",
                "reason": f"사용자 {too_slow_count}/{total_feedback}회 '너무 느리다' 응답",
                "suggestion": "사이클 타임 -5~10초 단축, Zone 한 단계 올리기",
            })

        # volume 피드백 반영
        too_short_count = sum(
            1 for fb in feedback_list
            if fb.get("feedback", {}).get("volume") == "too_short"
        )
        too_long_count = sum(
            1 for fb in feedback_list
            if fb.get("feedback", {}).get("volume") == "too_long"
        )
        if too_short_count > total_feedback * 0.4:
            actions.append({
                "type": "increase_volume_hint",
                "reason": f"사용자 {too_short_count}/{total_feedback}회 '너무 짧다' 응답",
                "suggestion": "총 거리 +8~12% 또는 세트 추가",
            })
        elif too_long_count > total_feedback * 0.4:
            actions.append({
                "type": "decrease_volume_hint",
                "reason": f"사용자 {too_long_count}/{total_feedback}회 '너무 길다' 응답",
                "suggestion": "총 거리 -8~12% 또는 반복 횟수 감소",
            })

        return {
            "patterns": patterns,
            "actions": actions,
            "confidence": confidence,
            "sample_size": total_feedback,
            "valid_difficulty_count": valid_difficulty_count,
            "ratios": {
                "easy": easy_ratio,
                "hard": hard_ratio,
                "appropriate": appropriate_ratio,
            },
            "streaks": {
                "too_easy": too_easy_streak,
                "too_hard": too_hard_streak,
            },
            "cooldown": {
                "sessions_since_change": sessions_since_change,
                "required_sessions": cooldown_sessions,
                "in_cooldown": in_cooldown,
            },
        }

    @staticmethod
    def generate_next_program_hint(
        feedback_analysis: dict, current_level: str
    ) -> dict:
        """피드백 분석 결과 → 다음 프로그램 생성 힌트"""
        actions = feedback_analysis.get("actions", [])
        patterns = feedback_analysis.get("patterns", {})

        hints = {
            "suggested_level": current_level,
            "difficulty_adjustment": 0,  # -1, 0, +1
            "volume_adjustment_percent": 0.0,
            "focus_areas": [],
            "drill_constraints": [],
        }

        # 난이도 조정
        for action in actions:
            if action["type"] == "increase_difficulty":
                hints["suggested_level"] = {
                    "beginner": "intermediate",
                    "intermediate": "advanced",
                    "advanced": "advanced",  # 최대
                }.get(current_level, current_level)
                hints["difficulty_adjustment"] = 1
                hints["volume_adjustment_percent"] = 10.0

            elif action["type"] == "increase_volume_only":
                # 난이도 승급 전 완충 단계
                if hints["difficulty_adjustment"] == 0:
                    hints["volume_adjustment_percent"] = 8.0

            elif action["type"] == "decrease_difficulty":
                hints["suggested_level"] = {
                    "advanced": "intermediate",
                    "intermediate": "beginner",
                    "beginner": "beginner",  # 최소
                }.get(current_level, current_level)
                hints["difficulty_adjustment"] = -1
                hints["volume_adjustment_percent"] = -10.0

            elif action["type"] == "reduce_volume":
                if not hints["volume_adjustment_percent"]:
                    hints["volume_adjustment_percent"] = -8.0

            elif action["type"] == "review_drill_selection":
                hints["drill_constraints"].append(
                    "지난 워크아웃에서 스킵된 드릴 피하기"
                )

            elif action["type"] == "adjust_pacing":
                hints["focus_areas"].append(action["suggestion"])

            elif action["type"] == "increase_volume_hint":
                if hints["volume_adjustment_percent"] == 0:
                    hints["volume_adjustment_percent"] = 10.0

            elif action["type"] == "decrease_volume_hint":
                if hints["volume_adjustment_percent"] == 0:
                    hints["volume_adjustment_percent"] = -10.0

        # 포커스 영역 추가
        if patterns.get("avg_completion_rate", 100) < 80:
            hints["focus_areas"].append("완주율 개선 필수")
        if patterns.get("avg_skipped_sets", 0) > 1:
            hints["focus_areas"].append("드릴 난이도 재검토")

        return hints



class WeaknessAnalyzer:
    """사용자 약점 분석 — 운동 기록에서 종목별/거리별/일관성 패턴 감지."""

    _STROKE_KEYWORDS: dict[str, str] = {
        "자유형": "freestyle", "접영": "butterfly",
        "배영": "backstroke", "평영": "breaststroke",
        "혼영": "IM", "개인혼영": "IM",
        "킥보드": "kickboard",
    }

    _STROKE_LABELS: dict[str, str] = {
        "freestyle": "자유형", "butterfly": "접영",
        "backstroke": "배영", "breaststroke": "평영",
        "IM": "개인혼영", "kickboard": "킥보드",
    }

    _DISTANCE_RANGES: list[tuple[int, int, str]] = [
        (0, 50, "단거리(~50m)"),
        (51, 100, "중거리(51~100m)"),
        (101, 200, "장거리(101~200m)"),
        (201, 9999, "초장거리(200m+)"),
    ]

    @classmethod
    def _detect_stroke(cls, exercise: str) -> str:
        for label, code in cls._STROKE_KEYWORDS.items():
            if label in exercise:
                return code
        return "unknown"

    @classmethod
    def _distance_label(cls, distance: int) -> str:
        for lo, hi, label in cls._DISTANCE_RANGES:
            if lo <= distance <= hi:
                return label
        return "unknown"

    @classmethod
    def analyze(cls, workout_logs: list[dict], min_sessions: int = 3) -> dict:
        """운동 기록 리스트를 분석하여 약점/강점 리포트 생성.

        Args:
            workout_logs: Firebase workout_logs 문서 리스트
            min_sessions: 분석에 필요한 최소 세션 수

        Returns:
            weaknesses, strengths, summary, training_insight를 포함한 dict
        """
        if not workout_logs or len(workout_logs) < min_sessions:
            return {
                "weaknesses": [],
                "strengths": [],
                "summary": f"분석에 최소 {min_sessions}회 이상의 운동 기록이 필요합니다.",
                "training_insight": "",
                "has_enough_data": False,
            }

        stroke_stats: dict[str, dict] = {}
        distance_stats: dict[str, dict] = {}
        session_dates: list[str] = []
        completion_rates: list[float] = []
        total_sets = 0

        for log in workout_logs:
            date = str(log.get("started_at", ""))
            if date:
                session_dates.append(date)

            planned = log.get("planned_distance", 0)
            completed = log.get("completed_distance", 0)
            if planned > 0:
                completion_rates.append(completed / planned * 100)

            for s in log.get("sets", []):
                exercise = s.get("exercise", "")
                distance = s.get("distance", 0)
                status = s.get("status", "")
                completed_repeat = s.get("completed_repeat", 0)
                planned_repeat = s.get("repeat", 1)
                total_sets += 1

                stroke = cls._detect_stroke(exercise)
                dist_label = cls._distance_label(distance)

                is_skipped = status == "skipped" and completed_repeat == 0
                is_partial = status == "skipped" and completed_repeat > 0
                is_completed = status == "completed"

                for key, stats in [(stroke, stroke_stats), (dist_label, distance_stats)]:
                    if key == "unknown":
                        continue
                    if key not in stats:
                        stats[key] = {
                            "total": 0, "completed": 0,
                            "skipped": 0, "partial": 0,
                        }
                    stats[key]["total"] += 1
                    if is_completed:
                        stats[key]["completed"] += 1
                    elif is_skipped:
                        stats[key]["skipped"] += 1
                    elif is_partial:
                        stats[key]["partial"] += 1

        weaknesses = []
        strengths = []

        # ── 종목별 분석 ──
        for stroke_code, stats in stroke_stats.items():
            if stats["total"] < 3:
                continue
            fail_rate = (stats["skipped"] + stats["partial"]) / stats["total"]
            label = cls._STROKE_LABELS.get(stroke_code, stroke_code)

            if fail_rate >= 0.4:
                weaknesses.append({
                    "category": "stroke",
                    "detail": label,
                    "evidence": (
                        f"최근 {label} 세트 {stats['total']}개 중 "
                        f"스킵 {stats['skipped']}개, 중도포기 {stats['partial']}개 "
                        f"(실패율 {fail_rate:.0%})"
                    ),
                    "suggestion": cls._stroke_suggestion(stroke_code),
                    "severity": "high" if fail_rate >= 0.6 else "medium",
                })
            elif fail_rate <= 0.1 and stats["total"] >= 5:
                strengths.append({
                    "category": "stroke",
                    "detail": label,
                    "evidence": (
                        f"{label} 세트 완주율 "
                        f"{stats['completed']}/{stats['total']} "
                        f"({stats['completed']/stats['total']:.0%})"
                    ),
                })

        # ── 거리별 분석 ──
        for dist_label, stats in distance_stats.items():
            if stats["total"] < 3:
                continue
            fail_rate = (stats["skipped"] + stats["partial"]) / stats["total"]

            if fail_rate >= 0.35:
                weaknesses.append({
                    "category": "endurance",
                    "detail": dist_label,
                    "evidence": (
                        f"{dist_label} 세트 {stats['total']}개 중 "
                        f"미완료 {stats['skipped'] + stats['partial']}개 "
                        f"(실패율 {fail_rate:.0%})"
                    ),
                    "suggestion": cls._distance_suggestion(dist_label),
                    "severity": "high" if fail_rate >= 0.5 else "medium",
                })
            elif fail_rate <= 0.1 and stats["total"] >= 5:
                strengths.append({
                    "category": "endurance",
                    "detail": dist_label,
                    "evidence": f"{dist_label} 세트 완주율 {1-fail_rate:.0%}",
                })

        # ── 완주율 추세 분석 ──
        trend = ""
        if len(completion_rates) >= 4:
            half = len(completion_rates) // 2
            recent_avg = sum(completion_rates[:half]) / half
            older_avg = sum(completion_rates[half:]) / len(completion_rates[half:])
            diff = recent_avg - older_avg
            if diff >= 5:
                trend = "improving"
                strengths.append({
                    "category": "trend",
                    "detail": "완주율 상승 추세",
                    "evidence": (
                        f"최근 완주율 {recent_avg:.0f}% "
                        f"(이전 {older_avg:.0f}% 대비 +{diff:.0f}%p)"
                    ),
                })
            elif diff <= -5:
                trend = "declining"
                weaknesses.append({
                    "category": "trend",
                    "detail": "완주율 하락 추세",
                    "evidence": (
                        f"최근 완주율 {recent_avg:.0f}% "
                        f"(이전 {older_avg:.0f}% 대비 {diff:.0f}%p)"
                    ),
                    "suggestion": "훈련 강도를 낮추거나 회복 세션을 추가해보세요.",
                    "severity": "medium",
                })

        # ── 종목 편중 분석 ──
        if stroke_stats:
            total_stroke_sets = sum(s["total"] for s in stroke_stats.values())
            for stroke_code, stats in stroke_stats.items():
                ratio = stats["total"] / total_stroke_sets if total_stroke_sets > 0 else 0
                label = cls._STROKE_LABELS.get(stroke_code, stroke_code)
                if ratio >= 0.7 and len(stroke_stats) == 1:
                    weaknesses.append({
                        "category": "balance",
                        "detail": f"{label} 편중",
                        "evidence": (
                            f"전체 세트의 {ratio:.0%}가 {label} — "
                            f"다른 영법 경험이 부족합니다"
                        ),
                        "suggestion": (
                            "다양한 영법을 연습하면 전체적인 수영 능력이 향상됩니다. "
                            "배영이나 평영 드릴을 추가해보세요."
                        ),
                        "severity": "low",
                    })

        # ── 요약 생성 ──
        summary = cls._build_summary(weaknesses, strengths, completion_rates, trend)
        training_insight = cls._build_training_insight(
            weaknesses, stroke_stats, distance_stats, completion_rates
        )

        weaknesses.sort(key=lambda w: {"high": 0, "medium": 1, "low": 2}.get(w.get("severity", "low"), 3))

        return {
            "weaknesses": weaknesses,
            "strengths": strengths,
            "summary": summary,
            "training_insight": training_insight,
            "has_enough_data": True,
            "sessions_analyzed": len(workout_logs),
            "total_sets_analyzed": total_sets,
        }

    @staticmethod
    def _stroke_suggestion(stroke_code: str) -> str:
        suggestions = {
            "freestyle": "캐치업 드릴, 핑거팁 드래그 등 기초 드릴로 자세를 교정하고 점진적으로 거리를 늘려보세요.",
            "butterfly": "접영 바디 웨이브, 사이드 돌핀킥으로 기초를 다지세요. 25m 단위로 시작하는 게 좋습니다.",
            "backstroke": "배영 편팔 드릴, 6킥 스위치로 밸런스를 잡으세요. 배영은 킥이 핵심입니다.",
            "breaststroke": "평영 글라이드 드릴로 타이밍을 잡고, 킥 온 백으로 킥 기술을 개선해보세요.",
            "IM": "개인혼영은 가장 약한 영법이 전체 기록을 좌우합니다. 약한 영법 드릴에 집중하세요.",
            "kickboard": "킥보드 훈련이 힘들다면 핀(오리발)을 활용해 킥 감각부터 익혀보세요.",
        }
        return suggestions.get(stroke_code, "기초 드릴부터 차근차근 연습해보세요.")

    @staticmethod
    def _distance_suggestion(dist_label: str) -> str:
        suggestions = {
            "단거리(~50m)": "50m 이하 세트에서 힘들다면 기술적인 문제일 수 있습니다. 드릴로 효율을 높여보세요.",
            "중거리(51~100m)": "100m 세트를 완주하려면 페이스 조절이 핵심입니다. 처음 50m을 80% 강도로 시작해보세요.",
            "장거리(101~200m)": "지구력 구간이 약합니다. 빌드업(점진적 속도 증가) 훈련으로 체력을 키워보세요.",
            "초장거리(200m+)": "200m 이상은 페이스와 호흡 리듬이 핵심입니다. Zone 2 강도로 긴 거리를 천천히 늘려보세요.",
        }
        return suggestions.get(dist_label, "점진적으로 거리를 늘려보세요.")

    @classmethod
    def _build_summary(
        cls,
        weaknesses: list[dict],
        strengths: list[dict],
        completion_rates: list[float],
        trend: str,
    ) -> str:
        parts = []
        avg_rate = sum(completion_rates) / len(completion_rates) if completion_rates else 0

        high_weaknesses = [w for w in weaknesses if w.get("severity") == "high"]
        if high_weaknesses:
            details = ", ".join(w["detail"] for w in high_weaknesses)
            parts.append(f"주요 약점: {details}")
        elif weaknesses:
            details = ", ".join(w["detail"] for w in weaknesses[:2])
            parts.append(f"개선 필요: {details}")

        if strengths:
            details = ", ".join(s["detail"] for s in strengths[:2])
            parts.append(f"강점: {details}")

        if trend == "improving":
            parts.append("최근 실력이 향상되고 있습니다")
        elif trend == "declining":
            parts.append("최근 컨디션이 떨어지고 있어 회복이 필요합니다")

        if avg_rate >= 90:
            parts.append(f"평균 완주율 {avg_rate:.0f}%로 우수합니다")
        elif avg_rate < 70:
            parts.append(f"평균 완주율 {avg_rate:.0f}%로 프로그램 강도 조절이 필요합니다")

        return ". ".join(parts) + "." if parts else "아직 충분한 데이터가 없습니다."

    @classmethod
    def _build_training_insight(
        cls,
        weaknesses: list[dict],
        stroke_stats: dict,
        distance_stats: dict,
        completion_rates: list[float],
    ) -> str:
        insights = []

        stroke_weaknesses = [w for w in weaknesses if w["category"] == "stroke"]
        if stroke_weaknesses:
            strokes = ", ".join(w["detail"] for w in stroke_weaknesses)
            insights.append(
                f"{strokes} 영법에 대한 보강 훈련이 필요합니다. "
                f"해당 영법의 기초 드릴을 워밍업이나 메인 세트 초반에 배치하세요."
            )

        endurance_weaknesses = [w for w in weaknesses if w["category"] == "endurance"]
        if endurance_weaknesses:
            labels = ", ".join(w["detail"] for w in endurance_weaknesses)
            insights.append(
                f"{labels} 구간에서 실패율이 높습니다. "
                f"빌드업(점진적 속도 증가) 세트를 활용해 해당 거리에 적응하세요."
            )

        if not weaknesses:
            if completion_rates and sum(completion_rates)/len(completion_rates) >= 90:
                insights.append(
                    "현재 수준에서 안정적으로 훈련하고 있습니다. "
                    "새로운 도전(거리 증가, 새로운 영법, 강도 상향)을 시도해볼 시점입니다."
                )

        return " ".join(insights) if insights else ""


# Firebase 통합 예시
async def save_workout_feedback_to_firebase(
    firebase_service, user_id: str, feedback_data: dict
) -> bool:
    """Firebase에 피드백 저장"""
    try:
        from firebase_admin import firestore as fs

        db = fs.client()
        feedback_data["submitted_at"] = datetime.utcnow().isoformat()

        db.collection("users").document(user_id).collection("feedback").add(
            feedback_data
        )

        logger.info(f"사용자 {user_id}의 피드백 저장 완료")
        return True
    except Exception as e:
        logger.error(f"피드백 저장 실패: {e}")
        return False


async def get_user_feedback_history(
    firebase_service, user_id: str, limit: int = 20
) -> list[dict]:
    """Firebase에서 사용자 피드백 이력 조회"""
    try:
        from firebase_admin import firestore as fs

        db = fs.client()
        docs = (
            db.collection("users")
            .document(user_id)
            .collection("feedback")
            .order_by("created_at", direction=fs.Query.DESCENDING)
            .limit(limit)
            .stream()
        )

        feedback_list = [
            doc.to_dict() for doc in docs
            if doc.to_dict().get("submitted_at") is not None
        ]
        logger.info(f"사용자 {user_id}의 피드백 {len(feedback_list)}건 조회")
        return feedback_list
    except Exception as e:
        logger.error(f"피드백 조회 실패: {e}")
        return []


async def get_policy_state_from_firebase(firebase_service, user_id: str) -> dict:
    """Firebase에서 정책 상태(쿨다운/최근 레벨 변경) 조회"""
    try:
        from firebase_admin import firestore as fs

        db = fs.client()
        doc = (
            db.collection("users")
            .document(user_id)
            .collection("feedback_policy")
            .document("state")
            .get()
        )
        if doc.exists:
            data = doc.to_dict() or {}
            logger.info(f"사용자 {user_id} 정책 상태 조회 완료")
            return data
        return {}
    except Exception as e:
        logger.error(f"정책 상태 조회 실패: {e}")
        return {}


async def save_policy_state_to_firebase(
    firebase_service,
    user_id: str,
    *,
    previous_level: str,
    suggested_level: str,
    difficulty_adjustment: int,
    volume_adjustment_percent: float,
    previous_cooldown_remaining: int,
) -> bool:
    """정책 결정 결과를 Firebase에 저장 (레벨 변경 이벤트 영속화)."""
    try:
        from firebase_admin import firestore as fs

        db = fs.client()
        now_iso = datetime.utcnow().isoformat()

        level_changed = difficulty_adjustment != 0 and previous_level != suggested_level
        if level_changed:
            cooldown_remaining = PersonalizationFeedback.DEFAULT_LEVEL_CHANGE_COOLDOWN_SESSIONS
        else:
            cooldown_remaining = max(0, previous_cooldown_remaining - 1)

        payload = {
            "updated_at": now_iso,
            "previous_level": previous_level,
            "suggested_level": suggested_level,
            "difficulty_adjustment": difficulty_adjustment,
            "volume_adjustment_percent": volume_adjustment_percent,
            "level_changed": level_changed,
            "cooldown_generations_remaining": cooldown_remaining,
            "policy_version": "p4.v2",
        }

        (
            db.collection("users")
            .document(user_id)
            .collection("feedback_policy")
            .document("state")
            .set(payload)
        )

        logger.info(
            f"정책 상태 저장 완료 (user={user_id}, "
            f"level_changed={level_changed}, cooldown_remaining={cooldown_remaining})"
        )
        return True
    except Exception as e:
        logger.error(f"정책 상태 저장 실패: {e}")
        return False
