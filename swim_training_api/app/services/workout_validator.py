"""워크아웃 검증 모듈 — P0 (구조), P1 (사이클 타임), P2 (드릴정확도)"""
import logging
import re
from typing import Optional

logger = logging.getLogger(__name__)


class WorkoutValidator:
    """3단계 워크아웃 검증 (P0~P2)"""

    # ── P0: 워크아웃 구조 검증 ──────────────────────────────────

    @staticmethod
    def extract_zone_number(notes: str) -> Optional[int]:
        """notes에서 Zone 번호 추출. 범위 표현(Zone 2~3)이면 높은 값 사용."""
        range_match = re.search(r'Zone\s*([1-5])\s*[~\-]\s*([1-5])', notes)
        if range_match:
            return int(range_match.group(2))
        match = re.search(r'Zone\s([1-5])', notes)
        return int(match.group(1)) if match else None

    @classmethod
    def get_distance_variety_score(cls, distances: list[int]) -> float:
        """거리 배열의 다양성 점수 (0~1, 1=매우 다양)"""
        if not distances:
            return 0.0
        if len(distances) < 3:
            return 0.3

        unique_distances = len(set(distances))
        repetitions = len(distances)
        variety = min(1.0, unique_distances / repetitions)

        if variety < 0.33:
            return 0.2
        return variety

    @classmethod
    def check_zone_progression(cls, exercises: list[dict]) -> dict:
        """Zone 경사도 검증"""
        zone_path = []
        issues = []

        for i, ex in enumerate(exercises):
            zone = cls.extract_zone_number(ex.get("notes", ""))
            if zone:
                zone_path.append(zone)

        if not zone_path:
            return {
                "valid": False,
                "zone_path": [],
                "issues": ["Zone 정보 부족"],
            }

        max_jump = 0
        for i in range(1, len(zone_path)):
            jump = abs(zone_path[i] - zone_path[i - 1])
            max_jump = max(max_jump, jump)
            if jump > 2:
                issues.append(
                    f"세트 {i} ~ {i + 1}: Zone {zone_path[i-1]} → {zone_path[i]} "
                    f"(급격한 변화 주의)"
                )

        if len(zone_path) >= 2:
            if zone_path[0] > zone_path[-1]:
                issues.append(
                    f"Overall Zone 하강: {zone_path[0]} → {zone_path[-1]} "
                    f"(보통 강도↑ 후 회복하는 패턴이 권장)"
                )

        return {
            "valid": max_jump <= 2 and len(issues) == 0,
            "zone_path": zone_path,
            "issues": issues,
        }

    @classmethod
    def _ensure_section_not_empty(
        cls, level_data: dict, section: str, level_key: str
    ) -> int:
        """빈 섹션에 기본 운동을 삽입하여 최소 구조를 보장. 수정 횟수 반환."""
        exercises = level_data.get(section, [])
        if exercises:
            return 0
        stroke = "자유형"
        defaults = {
            "warmup": {
                "description": f"{stroke} 이지 수영",
                "distance": 100 if level_key != "advanced" else 200,
                "repeat": 1,
                "rest_seconds": 0,
                "cycle_time": "3:00",
                "notes": "Zone 1 (편하게 대화 가능한 강도), 심박수·체온 점진 상승",
            },
            "main_set": {
                "description": f"{stroke} 스윔",
                "distance": 50,
                "repeat": 4,
                "rest_seconds": 15,
                "cycle_time": "1:30",
                "notes": "Zone 2 (숨이 살짝 차는 강도), 일관된 페이스 유지",
            },
            "cooldown": {
                "description": f"{stroke} 이지 쿨다운",
                "distance": 100,
                "repeat": 1,
                "rest_seconds": 0,
                "cycle_time": "3:30",
                "notes": "Zone 1 (편하게 대화 가능한 강도), 젖산 제거, 심박수 정상화",
            },
        }
        level_data[section] = [defaults[section]]
        logger.warning(
            f"[{level_key}] {section} 비어있음 → 기본 운동 삽입"
        )
        return 1

    @classmethod
    def _fix_invalid_exercises(cls, exercises: list[dict], level_key: str) -> int:
        """distance<=0 또는 repeat<=0인 운동 항목 교정. 수정 횟수 반환."""
        fixes = 0
        for ex in exercises:
            if ex.get("distance", 0) <= 0:
                ex["distance"] = 50
                fixes += 1
                logger.warning(f"[{level_key}] distance<=0 → 50m으로 교정")
            if ex.get("repeat", 1) <= 0:
                ex["repeat"] = 1
                fixes += 1
                logger.warning(f"[{level_key}] repeat<=0 → 1로 교정")
            if ex.get("rest_seconds", 0) < 0:
                ex["rest_seconds"] = 0
                fixes += 1
        return fixes


    @classmethod
    def fix_pool_length_distances(cls, raw_result: dict, pool_length: int = 25) -> int:
        """모든 거리를 pool_length의 배수로 교정 (P0 확장).

        예: 50m 풀에서 75m → 100m로 반올림, 25m → 50m으로 올림.
        """
        fixes = 0
        for level_key in ("beginner", "intermediate", "advanced"):
            level_data = raw_result.get(level_key, {})
            for section in ("warmup", "main_set", "cooldown"):
                for ex in level_data.get(section, []):
                    dist = ex.get("distance", 0)
                    if dist <= 0:
                        continue
                    if dist % pool_length != 0:
                        corrected = max(pool_length, round(dist / pool_length) * pool_length)
                        logger.warning(
                            f"[{level_key}/{section}] 거리 {dist}m → {corrected}m "
                            f"({pool_length}m 풀 배수 교정)"
                        )
                        ex["distance"] = corrected
                        fixes += 1
        return fixes

    @classmethod
    def _ensure_minimum_main_set(cls, level_data: dict, level_key: str) -> int:
        """main_set가 3개 미만이면 기본 운동을 추가하여 최소 훈련 세션 보장."""
        main_set = level_data.get("main_set", [])
        if len(main_set) >= 3:
            return 0

        fillers = [
            {
                "description": "자유형 스윔",
                "distance": 50, "repeat": 4,
                "rest_seconds": 15, "cycle_time": "1:30",
                "notes": "Zone 2 (숨이 살짝 차는 강도), 일관된 페이스 유지",
            },
            {
                "description": "자유형 빌드업",
                "distance": 100, "repeat": 2,
                "rest_seconds": 20, "cycle_time": "3:30",
                "notes": "Zone 2~3, 점진적 속도 증가",
            },
            {
                "description": "자유형 킥",
                "distance": 50, "repeat": 4,
                "rest_seconds": 15, "cycle_time": "1:45",
                "notes": "Zone 2, 킥 강화 훈련",
            },
        ]

        added = 0
        existing_descs = {ex.get("description", "") for ex in main_set}
        for filler in fillers:
            if len(main_set) >= 3:
                break
            if filler["description"] not in existing_descs:
                main_set.append(dict(filler))
                added += 1

        if added:
            logger.warning(
                f"[{level_key}] main_set {len(main_set) - added}개 → "
                f"{len(main_set)}개 (최소 3개 보장)"
            )
        return added

    @classmethod
    def validate_structure(cls, raw_result: dict) -> dict:
        """워크아웃 구조 검증 및 자동 교정 (P0)"""
        warnings = []
        total_fixes = 0

        for level_key in ("beginner", "intermediate", "advanced"):
            level_data = raw_result.get(level_key, {})
            level_warnings = {"level": level_key, "issues": []}

            for section in ("warmup", "main_set", "cooldown"):
                total_fixes += cls._ensure_section_not_empty(
                    level_data, section, level_key
                )
                exercises = level_data.get(section, [])
                total_fixes += cls._fix_invalid_exercises(exercises, level_key)

                total_fixes += cls._ensure_minimum_main_set(level_data, level_key)

                min_count = {
                    "warmup": 2,
                    "main_set": 3,
                    "cooldown": 1,
                }.get(section, 1)
                if len(exercises) < min_count:
                    level_warnings["issues"].append(
                        f"{section}: {len(exercises)}개 세트 (최소 {min_count}개 권장)"
                    )

                if section != "cooldown":
                    distances = [ex.get("distance", 0) for ex in exercises]
                    variety = cls.get_distance_variety_score(distances)
                    if variety < 0.4:
                        level_warnings["issues"].append(
                            f"{section}: 거리 다양성 부족 ({distances}, 점수: {variety:.2f})"
                        )

            main_set = level_data.get("main_set", [])
            zone_check = cls.check_zone_progression(main_set)
            if not zone_check["valid"]:
                for issue in zone_check["issues"]:
                    level_warnings["issues"].append(f"Zone: {issue}")

            if level_warnings["issues"]:
                warnings.append(level_warnings)

        for warn in warnings:
            for issue in warn["issues"]:
                logger.warning(f"[{warn['level']}] 워크아웃 구조 이슈: {issue}")

        if total_fixes:
            logger.info(f"구조 검증: {total_fixes}건 자동 교정 완료")
        if warnings:
            logger.info(
                f"구조 검증 완료: {len(warnings)}개 레벨에서 이슈 감지"
            )

        return raw_result, total_fixes

    # ── P1: 사이클 타임 오류 검출 ──────────────────────────────

    _LABEL_TO_CODE: dict[str, str] = {
        "자유형": "freestyle",
        "접영": "butterfly",
        "배영": "backstroke",
        "평영": "breaststroke",
        "개인혼영": "IM",
        "혼영": "IM",
    }

    @staticmethod
    def detect_stroke_from_description(description: str) -> Optional[str]:
        """description에서 종목/도구를 감지하여 영어 코드 반환."""
        if "킥보드" in description:
            return "kickboard"
        for label, code in WorkoutValidator._LABEL_TO_CODE.items():
            if label in description:
                return code
        return None

    @staticmethod
    def estimate_swim_time(
        distance: int, level: str, stroke: str = "freestyle"
    ) -> float:
        """거리·레벨·종목 기반 예상 완주 시간(초) 계산"""
        base_speed_100m = {
            "beginner": 180,   # 100m = 3:00 (프롬프트 기준 통일)
            "intermediate": 130,  # 100m = 2:10
            "advanced": 90,    # 100m = 1:30
        }

        stroke_offset_100m = {
            "freestyle": 0,
            "backstroke": 8,
            "butterfly": 15,
            "breaststroke": 25,
            "IM": 10,
            "kickboard": 30,
        }

        base = base_speed_100m.get(level, 180)
        offset = stroke_offset_100m.get(stroke, 0)
        time_per_100m = base + offset
        return (distance / 100.0) * time_per_100m

    @staticmethod
    def calculate_rest_by_zone(zone: int, swim_time: float) -> float:
        """Zone별 권장 휴식 시간(초) 계산"""
        rest_ratio = {
            1: (0.2, 0.4),    # Zone 1: 완주시간 × 20~40%
            2: (0.2, 0.4),    # Zone 2: 완주시간 × 20~40%
            3: (0.1, 0.2),    # Zone 3: 완주시간 × 10~20%
            4: (0.08, 0.25),  # Zone 4 (VO₂max): 타이트한 인터벌, 8~25%
            5: (2.0, 3.0),    # Zone 5 (스프린트): ATP-PC 완전 회복, 200~300%
        }
        lo, hi = rest_ratio.get(zone, (0.2, 0.4))
        return swim_time * (lo + hi) / 2

    @staticmethod
    def parse_cycle_time(cycle_str: str) -> Optional[float]:
        """cycle_time 문자열(예: '1:45') → 초 변환"""
        try:
            parts = cycle_str.split(":")
            if len(parts) == 2:
                minutes, seconds = int(parts[0]), int(parts[1])
                return minutes * 60 + seconds
            return None
        except (ValueError, IndexError):
            return None

    @staticmethod
    def seconds_to_cycle_time(seconds: float) -> str:
        """초 → cycle_time 문자열(예: '1:45')"""
        minutes = int(seconds) // 60
        secs = int(seconds) % 60
        return f"{minutes}:{secs:02d}"

    @classmethod
    def validate_and_fix_cycle_times(
        cls, raw_result: dict, strokes: list[str]
    ) -> dict:
        """사이클 타임 오류 검출 및 교정 (P1)

        수정사항:
        - 종목 코드를 영어로 통일 (한국어 라벨 변환 버그 수정)
        - 운동별 description에서 종목을 감지하여 개별 계산
        """
        primary_stroke = strokes[0] if strokes else "freestyle"

        corrections = 0

        for level_key in ("beginner", "intermediate", "advanced"):
            level_data = raw_result.get(level_key, {})

            for section in ("warmup", "main_set", "cooldown"):
                exercises = level_data.get(section, [])

                for ex in exercises:
                    distance = ex.get("distance", 0)
                    if not distance:
                        continue

                    zone = cls.extract_zone_number(ex.get("notes", ""))
                    if not zone:
                        zone = {"warmup": 1, "cooldown": 1}.get(section, 2)

                    detected = cls.detect_stroke_from_description(
                        ex.get("description", "")
                    )
                    stroke_for_calc = detected or primary_stroke

                    is_drill = "드릴" in ex.get("description", "")
                    swim_time = cls.estimate_swim_time(
                        distance, level_key, stroke_for_calc
                    )

                    repeat = ex.get("repeat", 1)
                    rest_sec = ex.get("rest_seconds", 0)
                    is_single = repeat <= 1 and rest_sec == 0

                    if is_single:
                        rest_time = 0
                        expected_cycle = swim_time
                    else:
                        rest_time = cls.calculate_rest_by_zone(zone, swim_time)
                        if is_drill:
                            rest_time = max(rest_time, swim_time * 0.3)
                        expected_cycle = swim_time + rest_time

                    actual_cycle_str = ex.get("cycle_time", "")
                    actual_cycle = cls.parse_cycle_time(actual_cycle_str)

                    # 쿨다운은 반드시 Zone 1
                    if section == "cooldown" and zone > 1:
                        logger.warning(
                            f"[{level_key}/cooldown] Zone {zone} → Zone 1 강제 교정"
                        )
                        zone = 1
                        ex["notes"] = cls._downgrade_zone_notes(ex.get("notes", ""), target_zone=1)
                        if not is_single:
                            rest_time = cls.calculate_rest_by_zone(zone, swim_time)
                            expected_cycle = swim_time + rest_time

                    tolerance = max(15, swim_time * 0.12)
                    if is_single:
                        tolerance = swim_time * 0.5

                    if actual_cycle and abs(actual_cycle - expected_cycle) > tolerance:
                        corrected = cls.seconds_to_cycle_time(expected_cycle)
                        logger.warning(
                            f"[{level_key}/{section}] {distance}m "
                            f"({stroke_for_calc}) cycle_time 오류: "
                            f"'{actual_cycle_str}'({actual_cycle:.0f}s) "
                            f"→ '{corrected}'({expected_cycle:.0f}s)"
                        )
                        ex["cycle_time"] = corrected
                        ex["rest_seconds"] = max(0, int(rest_time))
                        corrections += 1
                    elif not actual_cycle and distance > 0:
                        corrected = cls.seconds_to_cycle_time(expected_cycle)
                        logger.warning(
                            f"[{level_key}/{section}] {distance}m cycle_time 누락 "
                            f"→ '{corrected}' 자동 설정"
                        )
                        ex["cycle_time"] = corrected
                        ex["rest_seconds"] = max(0, int(rest_time))
                        corrections += 1

        if corrections:
            logger.info(f"총 {corrections}개 cycle_time 오류 교정 완료")
        return raw_result, corrections



    _ZONE_NOTE_DESCRIPTIONS: dict[int, str] = {
        1: "편하게 대화 가능한 강도",
        2: "숨이 살짝 차는 강도",
        3: "대화 어려운 강도, 젖산역치",
        4: "VO₂max, 매우 높은 강도",
        5: "전력 스프린트, ATP-PC 회복",
    }

    _HIGH_INTENSITY_REPLACEMENTS: list[tuple[str, str]] = [
        ("전력 질주", "빠른 페이스"),
        ("전력 스프린트", "빠른 페이스"),
        ("최대 파워 발휘", "파워 유지"),
        ("최대 파워", "안정적 파워"),
        ("최대 노력", "높은 집중"),
        ("VO₂max 인터벌", "젖산역치 인터벌"),
        ("VO2max 인터벌", "젖산역치 인터벌"),
        ("VO₂max", "젖산역치"),
        ("VO2max", "젖산역치"),
        ("올아웃", "강한 페이스"),
        ("ALL-OUT", "강한 페이스"),
        ("ATP-PC 회복", "적절한 회복"),
        ("ATP-PC", "유산소"),
    ]

    @classmethod
    def _downgrade_zone_notes(cls, notes: str, target_zone: int) -> str:
        """Zone 하향 시 숫자와 문구를 모두 target_zone에 맞게 교체."""
        # 범위 표현 처리: "Zone 2~3" → "Zone {target_zone}"
        result = re.sub(r'Zone\s*[2-5]\s*[~\-]\s*[2-5]', f'Zone {target_zone}', notes)
        # 단일 Zone 표현 처리: "Zone 3" → "Zone {target_zone}"
        result = re.sub(r'Zone\s*[2-5]', f'Zone {target_zone}', result)

        zone_desc = cls._ZONE_NOTE_DESCRIPTIONS.get(target_zone, "")
        # Zone 4/5 관련 설명 교체
        result = re.sub(
            r'\((?:전력 스프린트|VO[₂2]max|올아웃|ALL-OUT)[^)]*\)',
            f'({zone_desc})',
            result,
        )
        # Zone 2/3 관련 설명 교체
        result = re.sub(
            r'\((?:숨이 살짝 차는 강도|대화 어려운 강도|말하기 힘든 강도|레이스 강도|레이스 페이스)[^)]*\)',
            f'({zone_desc})',
            result,
        )

        if target_zone <= 3:
            for old_phrase, new_phrase in cls._HIGH_INTENSITY_REPLACEMENTS:
                result = result.replace(old_phrase, new_phrase)

        return result

    # ── P3: 강도 안전성 검증 ─────────────────────────────────────

    @classmethod
    def validate_intensity_safety(cls, raw_result: dict) -> tuple[dict, int]:
        """운동 강도 안전성 검증 (P3)

        - 초급: Zone 4-5 → Zone 3 강제 하향 (부상 방지)
        - 중급: Zone 5 총 거리가 main_set의 15% 초과 시 Zone 4로 하향
        """
        corrections = 0

        # ── 초급: Zone 4-5 완전 차단 ──
        beginner = raw_result.get("beginner", {})
        for section in ("warmup", "main_set", "cooldown"):
            for ex in beginner.get(section, []):
                zone = cls.extract_zone_number(ex.get("notes", ""))
                if zone and zone >= 4:
                    ex["notes"] = cls._downgrade_zone_notes(
                        ex.get("notes", ""), target_zone=3
                    )
                    corrections += 1
                    logger.warning(
                        f"[beginner/{section}] Zone {zone} → Zone 3 "
                        f"(초급자 고강도 차단)"
                    )

        # ── 중급: Zone 5 비율 main_set 15% 이하 ──
        intermediate = raw_result.get("intermediate", {})
        main_set = intermediate.get("main_set", [])
        if main_set:
            total_main = sum(
                ex.get("distance", 0) * ex.get("repeat", 1) for ex in main_set
            )
            if total_main > 0:
                z5_exercises = []
                z5_total = 0
                for ex in main_set:
                    zone = cls.extract_zone_number(ex.get("notes", ""))
                    if zone == 5:
                        dist = ex.get("distance", 0) * ex.get("repeat", 1)
                        z5_exercises.append((ex, dist))
                        z5_total += dist

                max_z5 = total_main * 0.15
                if z5_total > max_z5 and z5_exercises:
                    for ex, ex_dist in reversed(z5_exercises):
                        if z5_total <= max_z5:
                            break
                        ex["notes"] = cls._downgrade_zone_notes(
                            ex.get("notes", ""), target_zone=4
                        )
                        z5_total -= ex_dist
                        corrections += 1
                        logger.warning(
                            "[intermediate/main_set] Zone 5 비율 초과 → Zone 4 하향"
                        )

        # ── 고급: Zone 5 비율 main_set 25% 이하 ──
        advanced = raw_result.get("advanced", {})
        adv_main_set = advanced.get("main_set", [])
        if adv_main_set:
            total_adv_main = sum(
                ex.get("distance", 0) * ex.get("repeat", 1) for ex in adv_main_set
            )
            if total_adv_main > 0:
                adv_z5_exercises = []
                adv_z5_total = 0
                for ex in adv_main_set:
                    zone = cls.extract_zone_number(ex.get("notes", ""))
                    if zone == 5:
                        dist = ex.get("distance", 0) * ex.get("repeat", 1)
                        adv_z5_exercises.append((ex, dist))
                        adv_z5_total += dist

                max_adv_z5 = total_adv_main * 0.25
                if adv_z5_total > max_adv_z5 and adv_z5_exercises:
                    for ex, ex_dist in reversed(adv_z5_exercises):
                        if adv_z5_total <= max_adv_z5:
                            break
                        ex["notes"] = cls._downgrade_zone_notes(
                            ex.get("notes", ""), target_zone=4
                        )
                        adv_z5_total -= ex_dist
                        corrections += 1
                        logger.warning(
                            "[advanced/main_set] Zone 5 비율 초과 → Zone 4 하향"
                        )

        if corrections:
            logger.info(f"강도 안전성 검증: {corrections}건 교정")
        return raw_result, corrections

    @classmethod
    def validate_cross_level_consistency(cls, raw_result: dict) -> dict:
        """레벨 간 거리 일관성 검증 (경고 전용).

        beginner < intermediate < advanced 거리 순서가 지켜지는지 확인.
        """
        distances = {}
        for level_key in ("beginner", "intermediate", "advanced"):
            level = raw_result.get(level_key, {})
            total = 0
            for section in ("warmup", "main_set", "cooldown"):
                for ex in level.get(section, []):
                    total += ex.get("distance", 0) * ex.get("repeat", 1)
            distances[level_key] = total

        if distances.get("beginner", 0) >= distances.get("intermediate", 0):
            logger.warning(
                f"레벨 거리 역전: beginner({distances['beginner']}m) "
                f">= intermediate({distances['intermediate']}m)"
            )
        if distances.get("intermediate", 0) >= distances.get("advanced", 0):
            logger.warning(
                f"레벨 거리 역전: intermediate({distances['intermediate']}m) "
                f">= advanced({distances['advanced']}m)"
            )
        return raw_result

    # ── P2: 드릴명 정확도 (환각 감지 강화) ─────────────────────

    @staticmethod
    def check_drill_name_accuracy(description: str, valid_drills_set: set) -> bool:
        """드릴명 정확도: 유효한 드릴이 포함되어 있는가?"""
        for drill in valid_drills_set:
            if drill in description:
                return True

        safe_standalone = {"이지", "스윔", "수영", "킥", "스프린트", "빌드업", "디센딩", "쿨다운"}
        if any(t in description for t in safe_standalone):
            return True

        if "드릴" in description:
            known_prefixes = {
                "캐치업", "핑거팁", "지퍼", "사이드킥", "편팔", "스컬링",
                "피스트", "원암", "돌핀", "바디", "웨이브", "타이밍",
                "글라이드", "내로우킥", "헤드업", "분리", "스핀", "스노클",
            }
            return any(p in description for p in known_prefixes)

        return False

