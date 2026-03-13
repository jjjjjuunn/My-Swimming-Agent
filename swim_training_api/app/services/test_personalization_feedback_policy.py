import unittest

from app.services.personalization_feedback import PersonalizationFeedback


def _fb(difficulty, completion, skipped):
    return {
        "feedback": {
            "difficulty": difficulty,
            "completion_rate": completion,
            "skipped_sets": skipped,
            "duration_minutes": 40,
            "meta": {"level_changed": False, "cooldown_sessions": 3},
        }
    }


class TestPersonalizationFeedbackPolicy(unittest.TestCase):
    def test_upshift_requires_min_samples(self):
        feedbacks = [_fb("too_easy", 95, 0) for _ in range(7)]
        analysis = PersonalizationFeedback.analyze_feedback_patterns(feedbacks)
        actions = {a["type"] for a in analysis["actions"]}
        self.assertNotIn("increase_difficulty", actions)

    def test_upshift_becomes_volume_only_without_streak(self):
        feedbacks = [
            _fb("too_easy", 95, 0),
            _fb("appropriate", 95, 0),
            _fb("too_easy", 95, 0),
            _fb("too_easy", 95, 0),
            _fb("too_easy", 95, 0),
            _fb("too_easy", 95, 0),
            _fb("too_easy", 95, 0),
            _fb("too_easy", 95, 0),
        ]
        analysis = PersonalizationFeedback.analyze_feedback_patterns(feedbacks)
        actions = {a["type"] for a in analysis["actions"]}
        self.assertIn("increase_volume_only", actions)
        hints = PersonalizationFeedback.generate_next_program_hint(analysis, "beginner")
        self.assertEqual(hints["difficulty_adjustment"], 0)
        self.assertEqual(hints["volume_adjustment_percent"], 8.0)

    def test_upshift_triggers_with_streak_and_quality(self):
        feedbacks = [_fb("too_easy", 95, 0) for _ in range(8)]
        analysis = PersonalizationFeedback.analyze_feedback_patterns(feedbacks)
        actions = {a["type"] for a in analysis["actions"]}
        self.assertIn("increase_difficulty", actions)
        hints = PersonalizationFeedback.generate_next_program_hint(analysis, "beginner")
        self.assertEqual(hints["suggested_level"], "intermediate")
        self.assertEqual(hints["difficulty_adjustment"], 1)

    def test_downshift_has_priority_over_upshift(self):
        feedbacks = [
            _fb("too_hard", 60, 3),
            _fb("too_hard", 65, 2),
            _fb("too_hard", 62, 3),
            _fb("too_hard", 64, 2),
            _fb("too_easy", 90, 0),
            _fb("too_easy", 90, 0),
            _fb("too_easy", 90, 0),
            _fb("too_easy", 90, 0),
        ]
        analysis = PersonalizationFeedback.analyze_feedback_patterns(feedbacks)
        actions = [a["type"] for a in analysis["actions"]]
        self.assertEqual(actions[0], "decrease_difficulty")

    def test_cooldown_blocks_upshift(self):
        feedbacks = [_fb("too_easy", 95, 0) for _ in range(10)]
        policy_state = {"cooldown_generations_remaining": 2}
        analysis = PersonalizationFeedback.analyze_feedback_patterns(
            feedbacks, policy_state=policy_state
        )
        actions = {a["type"] for a in analysis["actions"]}
        self.assertIn("maintain_level", actions)
        self.assertNotIn("increase_difficulty", actions)

if __name__ == "__main__":
    unittest.main()
