"""Agent 경로 스모크 테스트

에이전트 핵심 경로(헬퍼, 그래프 빌드, 도구 정합성)를 검증합니다.
실제 LLM/Firebase 호출 없이 구조적 정합성만 확인합니다.
"""

import unittest
import json


class TestExtractText(unittest.TestCase):
    """_extract_text 헬퍼의 str/list/None 안전 변환 검증"""

    def _extract(self, content):
        from app.agent.graph import _extract_text
        return _extract_text(content)

    def test_string_passthrough(self):
        self.assertEqual(self._extract("hello"), "hello")

    def test_list_of_strings(self):
        self.assertEqual(self._extract(["hello", " world"]), "hello world")

    def test_list_of_dicts_with_text(self):
        result = self._extract([{"type": "text", "text": "abc"}, {"type": "text", "text": "def"}])
        self.assertEqual(result, "abcdef")

    def test_mixed_list(self):
        result = self._extract(["start ", {"type": "text", "text": "middle"}, " end"])
        self.assertEqual(result, "start middle end")

    def test_none_returns_empty(self):
        self.assertEqual(self._extract(None), "")

    def test_empty_list(self):
        self.assertEqual(self._extract([]), "")

    def test_empty_string(self):
        self.assertEqual(self._extract(""), "")


class TestToolRegistry(unittest.TestCase):
    """ALL_TOOLS 레지스트리 정합성 검증"""

    def test_all_tools_not_empty(self):
        from app.agent.tools import ALL_TOOLS
        self.assertGreater(len(ALL_TOOLS), 0, "ALL_TOOLS must not be empty")

    def test_all_tools_have_name(self):
        from app.agent.tools import ALL_TOOLS
        for t in ALL_TOOLS:
            self.assertTrue(hasattr(t, "name"), f"Tool {t} missing name attribute")
            self.assertIsInstance(t.name, str)
            self.assertGreater(len(t.name), 0)

    def test_all_tools_have_description(self):
        from app.agent.tools import ALL_TOOLS
        for t in ALL_TOOLS:
            self.assertTrue(hasattr(t, "description"), f"Tool {t.name} missing description")
            self.assertGreater(len(t.description), 0)

    def test_expected_tools_present(self):
        from app.agent.tools import ALL_TOOLS
        names = {t.name for t in ALL_TOOLS}
        expected = {
            "get_user_profile", "get_workout_history", "generate_program",
            "save_condition", "get_today_condition", "get_user_equipment",
            "save_user_equipment", "save_workout_memo",
        }
        missing = expected - names
        self.assertEqual(missing, set(), f"Missing tools: {missing}")


class TestGraphBuild(unittest.TestCase):
    """Agent 그래프 빌드 정합성 검증 (LLM 호출 없이)"""

    def test_graph_compiles_without_error(self):
        """build_graph()가 예외 없이 CompiledGraph를 반환하는지 확인"""
        import os
        os.environ.setdefault("OPENAI_API_KEY", "sk-test-dummy-key-for-compile")
        os.environ.setdefault("OPENAI_MODEL", "gpt-4o-mini")
        from app.agent.graph import build_graph
        graph = build_graph()
        self.assertIsNotNone(graph)

    def test_should_continue_end_on_plain_text(self):
        """tool_calls 없는 AI 메시지는 __end__로 라우팅"""
        from langchain_core.messages import AIMessage
        from app.agent.graph import should_continue
        state = {"messages": [AIMessage(content="안녕하세요!")]}
        result = should_continue(state)
        self.assertEqual(result, "__end__")

    def test_should_continue_redirect_on_promise(self):
        """프로그램 생성 약속만 하고 도구 호출 없으면 redirect"""
        from langchain_core.messages import AIMessage
        from app.agent.graph import should_continue
        state = {"messages": [AIMessage(content="프로그램을 생성해드릴게요!")]}
        result = should_continue(state)
        self.assertEqual(result, "redirect")

    def test_should_continue_end_on_future_promise(self):
        """미래 시점 약속은 redirect하지 않고 __end__"""
        from langchain_core.messages import AIMessage
        from app.agent.graph import should_continue
        state = {"messages": [AIMessage(content="내일 프로그램을 만들어드릴게요!")]}
        result = should_continue(state)
        self.assertEqual(result, "__end__")


if __name__ == "__main__":
    unittest.main()
