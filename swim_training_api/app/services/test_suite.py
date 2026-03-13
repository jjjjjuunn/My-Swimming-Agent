"""워크아웃 신뢰성 테스트 데이터셋 (P3)"""

# P3: 프로토타입 테스트를 위한 사용자 사이클 시뮬레이션
TEST_USER_SCENARIOS = [
    {
        "user_id": "test_beginner_001",
        "level": "beginner",
        "strokes": ["freestyle"],
        "training_goal": "endurance",
        "equipment": [],
        "expected_distance": 800,
        "scenario": "신규 사용자, 체계적 기초 훈련",
        "expected_difficulty": "적절",
    },
    {
        "user_id": "test_beginner_002",
        "level": "beginner",
        "strokes": ["freestyle", "backstroke"],
        "training_goal": "technique",
        "equipment": ["kickboard"],
        "expected_distance": 1000,
        "scenario": "기초 다지기, 드릴 비중 높음",
        "expected_difficulty": "적절",
    },
    {
        "user_id": "test_intermediate_001",
        "level": "intermediate",
        "strokes": ["freestyle"],
        "training_goal": "speed",
        "equipment": ["fins", "snorkel"],
        "expected_distance": 1800,
        "scenario": "중급자, 고강도 스프린트",
        "expected_difficulty": "도전적",
    },
    {
        "user_id": "test_intermediate_002",
        "level": "intermediate",
        "strokes": ["freestyle", "butterfly", "backstroke"],
        "training_goal": "overall",
        "equipment": ["pull_buoy", "paddles"],
        "expected_distance": 2200,
        "scenario": "다중 종목 종합 훈련",
        "expected_difficulty": "적절",
    },
    {
        "user_id": "test_advanced_001",
        "level": "advanced",
        "strokes": ["freestyle"],
        "training_goal": "speed",
        "equipment": ["fins"],
        "expected_distance": 3200,
        "scenario": "고급자, 최대 강도 훈련",
        "expected_difficulty": "도전적",
    },
    {
        "user_id": "test_advanced_002",
        "level": "advanced",
        "strokes": ["IM"],
        "training_goal": "overall",
        "equipment": ["kickboard", "pull_buoy", "snorkel"],
        "expected_distance": 3500,
        "scenario": "경쟁력 있는 수준, 개인혼영 집중",
        "expected_difficulty": "도전적",
    },
]

# 각 테스트에서 확인할 항목
TEST_CRITERIA = {
    "structure_validation": {
        "warmup_min_sets": 3,
        "main_set_min_sets": 5,
        "cooldown_min_sets": 1,
        "distance_variety_threshold": 0.35,
    },
    "cycle_time_accuracy": {
        "max_error_seconds": 10,
        "zone_progression_valid": True,
        "max_zone_jump": 2,
    },
    "drill_accuracy": {
        "valid_drill_ratio": 0.95,
        "hallucination_rate_max": 0.05,
    },
    "personalization": {
        "difficulty_alignment": True,
        "volume_within_range": True,
        "progressive_improvement": True,
    },
}


import unittest
from app.services.workout_validator import WorkoutValidator
from app.services.personalization_feedback import WeaknessAnalyzer


class TestWorkoutValidator(unittest.TestCase):
    """WorkoutValidator 핵심 로직 단위 테스트"""

    def test_estimate_swim_time_beginner_freestyle(self):
        t = WorkoutValidator.estimate_swim_time(100, "beginner", "freestyle")
        self.assertAlmostEqual(t, 180.0)

    def test_estimate_swim_time_intermediate_breaststroke(self):
        t = WorkoutValidator.estimate_swim_time(100, "intermediate", "breaststroke")
        self.assertAlmostEqual(t, 155.0)

    def test_estimate_swim_time_advanced(self):
        t = WorkoutValidator.estimate_swim_time(100, "advanced", "freestyle")
        self.assertAlmostEqual(t, 90.0)

    def test_estimate_swim_time_kickboard(self):
        t = WorkoutValidator.estimate_swim_time(100, "beginner", "kickboard")
        self.assertAlmostEqual(t, 210.0)

    def test_detect_stroke_from_description(self):
        self.assertEqual(
            WorkoutValidator.detect_stroke_from_description("자유형 이지 수영"),
            "freestyle",
        )
        self.assertEqual(
            WorkoutValidator.detect_stroke_from_description("접영 원암 드릴"),
            "butterfly",
        )
        self.assertEqual(
            WorkoutValidator.detect_stroke_from_description("킥보드 킥"),
            "kickboard",
        )
        self.assertIsNone(
            WorkoutValidator.detect_stroke_from_description("이지 스윔")
        )

    def test_parse_cycle_time(self):
        self.assertEqual(WorkoutValidator.parse_cycle_time("1:30"), 90)
        self.assertEqual(WorkoutValidator.parse_cycle_time("2:15"), 135)
        self.assertEqual(WorkoutValidator.parse_cycle_time("0:45"), 45)
        self.assertIsNone(WorkoutValidator.parse_cycle_time("invalid"))

    def test_seconds_to_cycle_time(self):
        self.assertEqual(WorkoutValidator.seconds_to_cycle_time(90), "1:30")
        self.assertEqual(WorkoutValidator.seconds_to_cycle_time(135), "2:15")

    def test_validate_structure_empty_section(self):
        raw = {
            "beginner": {"warmup": [], "main_set": [], "cooldown": []},
            "intermediate": {"warmup": [], "main_set": [], "cooldown": []},
            "advanced": {"warmup": [], "main_set": [], "cooldown": []},
        }
        result, _ = WorkoutValidator.validate_structure(raw)
        for lk in ("beginner", "intermediate", "advanced"):
            self.assertTrue(len(result[lk]["warmup"]) >= 1)
            self.assertTrue(len(result[lk]["main_set"]) >= 1)
            self.assertTrue(len(result[lk]["cooldown"]) >= 1)

    def test_fix_invalid_exercises(self):
        exercises = [
            {"distance": 0, "repeat": -1, "rest_seconds": -5},
            {"distance": 50, "repeat": 3, "rest_seconds": 10},
        ]
        fixes = WorkoutValidator._fix_invalid_exercises(exercises, "test")
        self.assertEqual(exercises[0]["distance"], 50)
        self.assertEqual(exercises[0]["repeat"], 1)
        self.assertEqual(exercises[0]["rest_seconds"], 0)
        self.assertTrue(fixes >= 3)

    def test_validate_and_fix_cycle_times_stroke_detection(self):
        raw = {
            "beginner": {
                "warmup": [],
                "main_set": [
                    {
                        "description": "평영 스윔",
                        "distance": 100,
                        "repeat": 1,
                        "rest_seconds": 15,
                        "cycle_time": "2:00",
                        "notes": "Zone 2 (숨이 살짝 차는 강도)",
                    }
                ],
                "cooldown": [],
            },
            "intermediate": {"warmup": [], "main_set": [], "cooldown": []},
            "advanced": {"warmup": [], "main_set": [], "cooldown": []},
        }
        result, _ = WorkoutValidator.validate_and_fix_cycle_times(raw, ["freestyle"])
        ex = result["beginner"]["main_set"][0]
        cycle_secs = WorkoutValidator.parse_cycle_time(ex["cycle_time"])
        self.assertGreater(cycle_secs, 200)

    def test_cycle_time_levels_are_distinct(self):
        """레벨별 cycle_time이 beginner > intermediate > advanced 순서인지 확인."""
        for stroke in ("freestyle", "backstroke", "breaststroke", "butterfly"):
            b = WorkoutValidator.estimate_swim_time(100, "beginner", stroke)
            i = WorkoutValidator.estimate_swim_time(100, "intermediate", stroke)
            a = WorkoutValidator.estimate_swim_time(100, "advanced", stroke)
            self.assertGreater(b, i, f"{stroke}: beginner should be slower than intermediate")
            self.assertGreater(i, a, f"{stroke}: intermediate should be slower than advanced")

    def test_zone4_rest_ratio_is_tight(self):
        """Zone 4 (VO2max) 사이클 타임이 프롬프트 레벨별 예시와 대략 일치하는지 확인."""
        swim = WorkoutValidator.estimate_swim_time(100, "intermediate", "freestyle")
        rest = WorkoutValidator.calculate_rest_by_zone(4, swim)
        cycle = swim + rest
        self.assertGreater(cycle, 140, "intermediate 100m Z4 cycle > 2:20")
        self.assertLess(cycle, 170, "intermediate 100m Z4 cycle < 2:50")

    def test_zone5_rest_ratio_sprint(self):
        """Zone 5 (스프린트) 사이클 타임이 프롬프트 예시 범위 내인지 확인."""
        swim = WorkoutValidator.estimate_swim_time(25, "advanced", "freestyle")
        rest = WorkoutValidator.calculate_rest_by_zone(5, swim)
        cycle = swim + rest
        self.assertGreater(cycle, 40, "advanced 25m Z5 cycle > 0:40")
        self.assertLess(cycle, 85, "advanced 25m Z5 cycle < 1:25")

    def test_cooldown_zone_forced_to_1(self):
        """쿨다운 Zone이 1보다 높으면 강제 교정되는지 확인 (multi-rep)."""
        raw = {
            "beginner": {
                "warmup": [{"description": "자유형 이지", "distance": 100, "repeat": 1,
                            "rest_seconds": 0, "cycle_time": "3:00", "notes": "Zone 1"}],
                "main_set": [{"description": "자유형 스윔", "distance": 50, "repeat": 4,
                              "rest_seconds": 15, "cycle_time": "1:30", "notes": "Zone 2"}],
                "cooldown": [{"description": "자유형 이지", "distance": 50, "repeat": 2,
                              "rest_seconds": 10, "cycle_time": "1:00", "notes": "Zone 3 (잘못된)"}],
            },
            "intermediate": {"warmup": [], "main_set": [], "cooldown": []},
            "advanced": {"warmup": [], "main_set": [], "cooldown": []},
        }
        result, _ = WorkoutValidator.validate_and_fix_cycle_times(raw, ["freestyle"])
        cd = result["beginner"]["cooldown"][0]
        cycle_secs = WorkoutValidator.parse_cycle_time(cd["cycle_time"])
        swim = WorkoutValidator.estimate_swim_time(50, "beginner", "freestyle")
        rest_z1 = WorkoutValidator.calculate_rest_by_zone(1, swim)
        expected = swim + rest_z1
        self.assertAlmostEqual(cycle_secs, expected, delta=1)


    def test_beginner_zone4_downgraded_to_zone3(self):
        """초급자의 Zone 4-5 운동이 Zone 3으로 하향되고, 고강도 문구도 교체되는지 확인."""
        raw = {
            "beginner": {
                "warmup": [{"description": "자유형 이지", "distance": 100, "repeat": 1,
                            "rest_seconds": 0, "cycle_time": "3:00", "notes": "Zone 1"}],
                "main_set": [
                    {"description": "자유형 스프린트", "distance": 50, "repeat": 4,
                     "rest_seconds": 30, "cycle_time": "1:30",
                     "notes": "Zone 4 (VO2max 인터벌), 최대 파워 발휘"},
                    {"description": "자유형 스윔", "distance": 100, "repeat": 3,
                     "rest_seconds": 15, "cycle_time": "2:30", "notes": "Zone 2"},
                    {"description": "자유형 전력", "distance": 25, "repeat": 6,
                     "rest_seconds": 60, "cycle_time": "2:00",
                     "notes": "Zone 5 (전력 스프린트), 전력 질주"},
                ],
                "cooldown": [{"description": "자유형 이지", "distance": 100, "repeat": 1,
                              "rest_seconds": 0, "cycle_time": "3:00", "notes": "Zone 1"}],
            },
            "intermediate": {"warmup": [], "main_set": [], "cooldown": []},
            "advanced": {"warmup": [], "main_set": [], "cooldown": []},
        }
        result, corrections = WorkoutValidator.validate_intensity_safety(raw)
        self.assertEqual(corrections, 2)
        z4_notes = result["beginner"]["main_set"][0]["notes"]
        z5_notes = result["beginner"]["main_set"][2]["notes"]
        # Zone 숫자 교체 확인
        self.assertIn("Zone 3", z4_notes)
        self.assertNotIn("Zone 4", z4_notes)
        self.assertIn("Zone 3", z5_notes)
        self.assertNotIn("Zone 5", z5_notes)
        # 고강도 문구 교체 확인
        self.assertNotIn("VO2max", z4_notes)
        self.assertNotIn("최대 파워 발휘", z4_notes)
        self.assertNotIn("전력 질주", z5_notes)
        self.assertNotIn("전력 스프린트", z5_notes)
        # Zone 2는 그대로 유지
        self.assertIn("Zone 2", result["beginner"]["main_set"][1]["notes"])

    def test_intermediate_zone5_excess_capped(self):
        """중급자의 Zone 5 총 거리가 main_set 15% 초과 시 Zone 4로 하향."""
        raw = {
            "beginner": {"warmup": [], "main_set": [], "cooldown": []},
            "intermediate": {
                "warmup": [{"description": "자유형 이지", "distance": 200, "repeat": 1,
                            "rest_seconds": 0, "cycle_time": "4:00", "notes": "Zone 1"}],
                "main_set": [
                    {"description": "자유형 스윔", "distance": 100, "repeat": 4,
                     "rest_seconds": 15, "cycle_time": "2:00", "notes": "Zone 3"},
                    {"description": "자유형 스프린트", "distance": 50, "repeat": 4,
                     "rest_seconds": 60, "cycle_time": "2:30",
                     "notes": "Zone 5 (전력 스프린트)"},
                    {"description": "자유형 전력", "distance": 50, "repeat": 4,
                     "rest_seconds": 60, "cycle_time": "2:30",
                     "notes": "Zone 5 (전력 스프린트)"},
                ],
                "cooldown": [{"description": "자유형 이지", "distance": 100, "repeat": 1,
                              "rest_seconds": 0, "cycle_time": "3:00", "notes": "Zone 1"}],
            },
            "advanced": {"warmup": [], "main_set": [], "cooldown": []},
        }
        # main_set total = 400 + 200 + 200 = 800m
        # Zone 5 total = 200 + 200 = 400m (50%)
        # max Zone 5 = 800 * 0.15 = 120m → 280m excess
        result, corrections = WorkoutValidator.validate_intensity_safety(raw)
        self.assertGreater(corrections, 0)
        # 뒤에서부터 하향되므로 마지막 Zone 5 운동이 Zone 4로 변경
        last_sprint = result["intermediate"]["main_set"][2]
        self.assertIn("Zone 4", last_sprint["notes"])

    def test_cross_level_consistency_runs(self):
        """레벨 간 거리 일관성 검증이 정상 실행되는지 확인."""
        raw = {
            "beginner": {
                "warmup": [{"distance": 100, "repeat": 1}],
                "main_set": [{"distance": 50, "repeat": 8}],
                "cooldown": [{"distance": 100, "repeat": 1}],
            },
            "intermediate": {
                "warmup": [{"distance": 200, "repeat": 1}],
                "main_set": [{"distance": 100, "repeat": 10}],
                "cooldown": [{"distance": 200, "repeat": 1}],
            },
            "advanced": {
                "warmup": [{"distance": 300, "repeat": 1}],
                "main_set": [{"distance": 100, "repeat": 20}],
                "cooldown": [{"distance": 200, "repeat": 1}],
            },
        }
        # beginner=600, intermediate=1400, advanced=2500 → 정상 순서
        result = WorkoutValidator.validate_cross_level_consistency(raw)
        self.assertIsNotNone(result)


    def test_sparse_main_set_auto_filled(self):
        """main_set가 3개 미만일 때 자동 보충되는지 확인."""
        raw = {
            "beginner": {
                "warmup": [{"description": "자유형 이지", "distance": 100, "repeat": 1,
                            "rest_seconds": 0, "cycle_time": "3:00", "notes": "Zone 1"}],
                "main_set": [
                    {"description": "자유형 스윔", "distance": 100, "repeat": 4,
                     "rest_seconds": 15, "cycle_time": "2:30", "notes": "Zone 2"},
                ],
                "cooldown": [{"description": "자유형 이지", "distance": 100, "repeat": 1,
                              "rest_seconds": 0, "cycle_time": "3:00", "notes": "Zone 1"}],
            },
            "intermediate": {
                "warmup": [{"description": "자유형 이지", "distance": 200, "repeat": 1,
                            "rest_seconds": 0, "cycle_time": "4:00", "notes": "Zone 1"}],
                "main_set": [
                    {"description": "자유형 스윔", "distance": 100, "repeat": 6,
                     "rest_seconds": 15, "cycle_time": "2:00", "notes": "Zone 2"},
                    {"description": "자유형 스프린트", "distance": 50, "repeat": 4,
                     "rest_seconds": 30, "cycle_time": "1:30", "notes": "Zone 3"},
                    {"description": "자유형 빌드업", "distance": 100, "repeat": 3,
                     "rest_seconds": 20, "cycle_time": "2:30", "notes": "Zone 2~3"},
                ],
                "cooldown": [{"description": "자유형 이지", "distance": 200, "repeat": 1,
                              "rest_seconds": 0, "cycle_time": "4:00", "notes": "Zone 1"}],
            },
            "advanced": {
                "warmup": [{"description": "자유형 이지", "distance": 300, "repeat": 1,
                            "rest_seconds": 0, "cycle_time": "4:30", "notes": "Zone 1"}],
                "main_set": [
                    {"description": "자유형 스윔", "distance": 200, "repeat": 5,
                     "rest_seconds": 15, "cycle_time": "3:00", "notes": "Zone 2"},
                    {"description": "자유형 스프린트", "distance": 50, "repeat": 8,
                     "rest_seconds": 30, "cycle_time": "1:00", "notes": "Zone 4"},
                    {"description": "자유형 빌드업", "distance": 100, "repeat": 4,
                     "rest_seconds": 20, "cycle_time": "1:30", "notes": "Zone 3"},
                ],
                "cooldown": [{"description": "자유형 이지", "distance": 200, "repeat": 1,
                              "rest_seconds": 0, "cycle_time": "4:00", "notes": "Zone 1"}],
            },
        }
        result, fixes = WorkoutValidator.validate_structure(raw)
        # beginner: 1개 → 3개로 보충
        self.assertGreaterEqual(len(result["beginner"]["main_set"]), 3)
        self.assertGreater(fixes, 0)
        # intermediate/advanced: 이미 3개 이상이므로 변경 없음
        self.assertEqual(len(result["intermediate"]["main_set"]), 3)
        self.assertEqual(len(result["advanced"]["main_set"]), 3)



    def test_pool_length_distance_correction(self):
        """pool_length에 맞지 않는 거리가 교정되는지 확인."""
        raw = {
            "beginner": {
                "warmup": [{"description": "자유형 이지", "distance": 75, "repeat": 1,
                            "rest_seconds": 0, "cycle_time": "2:00", "notes": "Zone 1"}],
                "main_set": [
                    {"description": "자유형 스윔", "distance": 30, "repeat": 4,
                     "rest_seconds": 15, "cycle_time": "1:30", "notes": "Zone 2"},
                    {"description": "자유형 킥", "distance": 100, "repeat": 2,
                     "rest_seconds": 15, "cycle_time": "3:00", "notes": "Zone 2"},
                    {"description": "자유형 드릴", "distance": 50, "repeat": 3,
                     "rest_seconds": 15, "cycle_time": "2:00", "notes": "Zone 1"},
                ],
                "cooldown": [{"description": "자유형 이지", "distance": 125, "repeat": 1,
                              "rest_seconds": 0, "cycle_time": "4:00", "notes": "Zone 1"}],
            },
            "intermediate": {
                "warmup": [{"description": "자유형 이지", "distance": 200, "repeat": 1,
                            "rest_seconds": 0, "cycle_time": "4:00", "notes": "Zone 1"}],
                "main_set": [
                    {"description": "자유형 스윔", "distance": 100, "repeat": 4,
                     "rest_seconds": 15, "cycle_time": "2:00", "notes": "Zone 2"},
                    {"description": "자유형 킥", "distance": 50, "repeat": 4,
                     "rest_seconds": 15, "cycle_time": "1:30", "notes": "Zone 2"},
                    {"description": "자유형 드릴", "distance": 50, "repeat": 3,
                     "rest_seconds": 15, "cycle_time": "2:00", "notes": "Zone 1"},
                ],
                "cooldown": [{"description": "자유형 이지", "distance": 200, "repeat": 1,
                              "rest_seconds": 0, "cycle_time": "4:00", "notes": "Zone 1"}],
            },
            "advanced": {
                "warmup": [{"description": "자유형 이지", "distance": 200, "repeat": 1,
                            "rest_seconds": 0, "cycle_time": "4:00", "notes": "Zone 1"}],
                "main_set": [
                    {"description": "자유형 스윔", "distance": 100, "repeat": 4,
                     "rest_seconds": 15, "cycle_time": "2:00", "notes": "Zone 2"},
                    {"description": "자유형 킥", "distance": 50, "repeat": 4,
                     "rest_seconds": 15, "cycle_time": "1:30", "notes": "Zone 2"},
                    {"description": "자유형 드릴", "distance": 50, "repeat": 3,
                     "rest_seconds": 15, "cycle_time": "2:00", "notes": "Zone 1"},
                ],
                "cooldown": [{"description": "자유형 이지", "distance": 200, "repeat": 1,
                              "rest_seconds": 0, "cycle_time": "4:00", "notes": "Zone 1"}],
            },
        }

        # 25m 풀: 75→75(=25*3), 30→25, 125→125(=25*5)
        fixes_25 = WorkoutValidator.fix_pool_length_distances(raw, pool_length=25)
        self.assertEqual(raw["beginner"]["warmup"][0]["distance"], 75)
        self.assertEqual(raw["beginner"]["main_set"][0]["distance"], 25)
        self.assertEqual(raw["beginner"]["cooldown"][0]["distance"], 125)
        self.assertGreater(fixes_25, 0)

        # 50m 풀 테스트
        raw50 = {
            "beginner": {
                "warmup": [{"description": "자유형 이지", "distance": 75, "repeat": 1,
                            "rest_seconds": 0, "cycle_time": "2:00", "notes": "Zone 1"}],
                "main_set": [
                    {"description": "자유형 스윔", "distance": 125, "repeat": 2,
                     "rest_seconds": 15, "cycle_time": "4:00", "notes": "Zone 2"},
                    {"description": "자유형 킥", "distance": 100, "repeat": 2,
                     "rest_seconds": 15, "cycle_time": "3:00", "notes": "Zone 2"},
                    {"description": "자유형 드릴", "distance": 50, "repeat": 3,
                     "rest_seconds": 15, "cycle_time": "2:00", "notes": "Zone 1"},
                ],
                "cooldown": [{"description": "자유형 이지", "distance": 200, "repeat": 1,
                              "rest_seconds": 0, "cycle_time": "6:00", "notes": "Zone 1"}],
            },
            "intermediate": {
                "warmup": [{"description": "자유형 이지", "distance": 200, "repeat": 1,
                            "rest_seconds": 0, "cycle_time": "4:00", "notes": "Zone 1"}],
                "main_set": [
                    {"description": "자유형 스윔", "distance": 200, "repeat": 2,
                     "rest_seconds": 15, "cycle_time": "4:00", "notes": "Zone 2"},
                    {"description": "자유형 킥", "distance": 100, "repeat": 2,
                     "rest_seconds": 15, "cycle_time": "3:00", "notes": "Zone 2"},
                    {"description": "자유형 드릴", "distance": 50, "repeat": 3,
                     "rest_seconds": 15, "cycle_time": "2:00", "notes": "Zone 1"},
                ],
                "cooldown": [{"description": "자유형 이지", "distance": 200, "repeat": 1,
                              "rest_seconds": 0, "cycle_time": "6:00", "notes": "Zone 1"}],
            },
            "advanced": {
                "warmup": [{"description": "자유형 이지", "distance": 200, "repeat": 1,
                            "rest_seconds": 0, "cycle_time": "4:00", "notes": "Zone 1"}],
                "main_set": [
                    {"description": "자유형 스윔", "distance": 200, "repeat": 2,
                     "rest_seconds": 15, "cycle_time": "4:00", "notes": "Zone 2"},
                    {"description": "자유형 킥", "distance": 100, "repeat": 2,
                     "rest_seconds": 15, "cycle_time": "3:00", "notes": "Zone 2"},
                    {"description": "자유형 드릴", "distance": 50, "repeat": 3,
                     "rest_seconds": 15, "cycle_time": "2:00", "notes": "Zone 1"},
                ],
                "cooldown": [{"description": "자유형 이지", "distance": 200, "repeat": 1,
                              "rest_seconds": 0, "cycle_time": "6:00", "notes": "Zone 1"}],
            },
        }
        fixes_50 = WorkoutValidator.fix_pool_length_distances(raw50, pool_length=50)
        # 75→50(반올림) or 100(반올림), 125→150(반올림) or 100(반올림), 100→100(이미 배수)
        self.assertEqual(raw50["beginner"]["warmup"][0]["distance"] % 50, 0)
        self.assertEqual(raw50["beginner"]["main_set"][0]["distance"] % 50, 0)
        self.assertEqual(raw50["beginner"]["main_set"][1]["distance"] % 50, 0)
        self.assertGreater(fixes_50, 0)


class TestWeaknessAnalyzer(unittest.TestCase):
    """WeaknessAnalyzer 약점 분석 단위 테스트"""

    def _make_log(self, sets, strokes=None, planned=1000, completed=900):
        return {
            "started_at": "2026-03-01",
            "planned_distance": planned,
            "completed_distance": completed,
            "strokes": strokes or ["freestyle"],
            "training_goal": "endurance",
            "sets": sets,
        }

    def _make_set(self, exercise, distance=100, status="completed", repeat=4, completed_repeat=4):
        return {
            "exercise": exercise,
            "distance": distance,
            "repeat": repeat,
            "status": status,
            "completed_repeat": completed_repeat if status == "completed" else (0 if status == "skipped" else completed_repeat),
        }

    def test_insufficient_data(self):
        """데이터 부족 시 분석 불가 응답."""
        result = WeaknessAnalyzer.analyze([{"sets": []}])
        self.assertFalse(result["has_enough_data"])

    def test_stroke_weakness_detected(self):
        """특정 종목 스킵률이 높으면 약점으로 감지."""
        logs = []
        for _ in range(5):
            logs.append(self._make_log([
                self._make_set("자유형 스윔", status="completed"),
                self._make_set("자유형 빌드업", status="completed"),
                self._make_set("접영 드릴", status="skipped", completed_repeat=0),
                self._make_set("접영 스윔", status="skipped", completed_repeat=0),
            ]))
        result = WeaknessAnalyzer.analyze(logs)
        self.assertTrue(result["has_enough_data"])
        stroke_weaknesses = [w for w in result["weaknesses"] if w["category"] == "stroke"]
        self.assertTrue(any("접영" in w["detail"] for w in stroke_weaknesses))

    def test_stroke_strength_detected(self):
        """특정 종목 완주율이 높으면 강점으로 감지."""
        logs = []
        for _ in range(5):
            logs.append(self._make_log([
                self._make_set("자유형 스윔", status="completed"),
                self._make_set("자유형 빌드업", status="completed"),
                self._make_set("자유형 드릴", status="completed"),
            ]))
        result = WeaknessAnalyzer.analyze(logs)
        self.assertTrue(result["has_enough_data"])
        stroke_strengths = [s for s in result["strengths"] if s["category"] == "stroke"]
        self.assertTrue(any("자유형" in s["detail"] for s in stroke_strengths))

    def test_distance_weakness_detected(self):
        """긴 거리 세트에서 실패율이 높으면 약점으로 감지."""
        logs = []
        for _ in range(4):
            logs.append(self._make_log([
                self._make_set("자유형 스윔", distance=50, status="completed"),
                self._make_set("자유형 스윔", distance=50, status="completed"),
                self._make_set("자유형 스윔", distance=200, status="skipped", completed_repeat=0),
                self._make_set("자유형 빌드업", distance=200, status="skipped", completed_repeat=1),
            ]))
        result = WeaknessAnalyzer.analyze(logs)
        endurance_weaknesses = [w for w in result["weaknesses"] if w["category"] == "endurance"]
        self.assertTrue(len(endurance_weaknesses) > 0)

    def test_completion_trend_declining(self):
        """완주율 하락 추세 감지."""
        logs = []
        for i in range(8):
            rate = 60 + i * 5
            logs.append(self._make_log(
                [self._make_set("자유형 스윔")],
                planned=1000,
                completed=int(1000 * rate / 100),
            ))
        result = WeaknessAnalyzer.analyze(logs)
        trend_weaknesses = [w for w in result["weaknesses"] if w["category"] == "trend"]
        self.assertTrue(len(trend_weaknesses) > 0)

    def test_summary_not_empty(self):
        """분석 결과에 요약이 포함됨."""
        logs = []
        for _ in range(3):
            logs.append(self._make_log([
                self._make_set("자유형 스윔"),
                self._make_set("배영 스윔", status="skipped", completed_repeat=0),
            ]))
        result = WeaknessAnalyzer.analyze(logs)
        self.assertTrue(len(result["summary"]) > 0)


if __name__ == "__main__":
    unittest.main()
