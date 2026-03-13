import unittest
import asyncio

from app.services.validation_protocol import (
    ReliabilityGateConfig,
    ValidationProtocol,
    run_validation_protocol,
)


class TestValidationProtocol(unittest.TestCase):
    def test_prompt_builders_include_required_sections(self):
        answer = "beginner 1000m program"
        persona = "최근 4주 어깨 통증, 킥 약점"

        p = ValidationProtocol.build_professional_prompt(answer)
        self.assertIn("역학적 정확성", p)
        self.assertIn(answer, p)

        pe = ValidationProtocol.build_personalization_prompt(persona, answer)
        self.assertIn("데이터 반영도", pe)
        self.assertIn(persona, pe)
        self.assertIn(answer, pe)

        s = ValidationProtocol.build_safety_prompt(answer)
        self.assertIn("오버트레이닝 위험", s)
        self.assertIn(answer, s)

    def test_parse_json_response_tolerates_fence(self):
        raw = """```json
        {"score": 9, "critical_issues": [], "improvement_guides": []}
        ```"""
        parsed = ValidationProtocol.parse_json_response(raw)
        self.assertEqual(parsed["score"], 9)

    def test_gate_passes_only_with_strict_scores(self):
        prof = {"score": 9, "critical_issues": [], "improvement_guides": []}
        pers = {"score": 8, "differentiators": ["a", "b", "c"], "missing_reflections": []}
        safe = {
            "score": 9,
            "risk_level": "낮음",
            "must_fix_sentences": [],
            "safety_actions": ["cooldown 포함"],
        }
        result = ValidationProtocol.evaluate_gate(prof, pers, safe)
        self.assertTrue(result["ready_for_real_training"])
        self.assertEqual(result["scores"]["total"], 26)

    def test_gate_fails_when_safety_risk_high(self):
        prof = {"score": 10}
        pers = {"score": 10}
        safe = {
            "score": 10,
            "risk_level": "높음",
            "must_fix_sentences": [],
            "safety_actions": [],
        }
        result = ValidationProtocol.evaluate_gate(prof, pers, safe)
        self.assertFalse(result["ready_for_real_training"])
        self.assertIn("안전성 위험 수준이 '높음'", result["blockers"])

    def test_gate_fails_with_must_fix_sentences_and_high_risk(self):
        cfg = ReliabilityGateConfig(
            min_professional_score=7,
            min_personalization_score=7,
            min_safety_score=8,
            min_total_score=24,
        )
        prof = {"score": 8}
        pers = {"score": 8}
        safe = {
            "score": 9,
            "risk_level": "높음",
            "must_fix_sentences": ["고강도 직후 쿨다운 없이 종료"],
            "safety_actions": ["쿨다운 추가"],
        }
        result = ValidationProtocol.evaluate_gate(prof, pers, safe, config=cfg)
        self.assertFalse(result["ready_for_real_training"])
        self.assertIn("안전성 위험 수준이 \'높음\'", result["blockers"])

    def test_gate_fails_with_must_fix_regardless_of_risk(self):
        """must_fix_sentences가 있으면 risk_level과 무관하게 차단."""
        cfg = ReliabilityGateConfig(
            min_professional_score=7,
            min_personalization_score=7,
            min_safety_score=8,
            min_total_score=24,
        )
        prof = {"score": 8}
        pers = {"score": 8}
        safe = {
            "score": 9,
            "risk_level": "보통",
            "must_fix_sentences": ["고강도 직후 쿨다운 없이 종료"],
            "safety_actions": ["쿨다운 추가"],
        }
        result = ValidationProtocol.evaluate_gate(prof, pers, safe, config=cfg)
        self.assertFalse(result["ready_for_real_training"])
        self.assertIn("안전상 반드시 수정해야 할 문장이 존재", result["blockers"])

    def test_run_validation_protocol_end_to_end(self):
        class FakeLLM:
            def __init__(self):
                self.calls = 0

            async def generate_text(self, _system_prompt, _user_prompt):
                self.calls += 1
                if self.calls == 1:
                    return '{"score": 9, "critical_issues": [], "improvement_guides": ["ok"]}'
                if self.calls == 2:
                    return '{"score": 8, "differentiators": ["a", "b", "c"], "missing_reflections": []}'
                return '{"score": 9, "risk_level": "낮음", "must_fix_sentences": [], "safety_actions": ["cooldown"]}'

        async def _run():
            return await run_validation_protocol(
                llm_service=FakeLLM(),
                agent_answer="샘플 프로그램",
                user_persona_and_history="초급, 어깨 통증 이력",
            )

        out = asyncio.run(_run())
        self.assertTrue(out["gate"]["ready_for_real_training"])
        self.assertEqual(out["gate"]["scores"]["total"], 26)


if __name__ == "__main__":
    unittest.main()