import logging
from typing import Optional

from app.models.response import ProgramResponse
from app.services.llm_service import LLMService
from app.services.rag_service import RAGService
from app.services.firebase_service import FirebaseService
from app.prompts.program_prompts import SYSTEM_PROMPT, build_user_prompt

logger = logging.getLogger(__name__)


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
    ) -> ProgramResponse:
        """3개 레벨 모두 포함된 하루 운동 프로그램 생성"""

        # 입력 검증
        self._validate_input(training_goal, strokes, equipment)

        logger.info(
            f"프로그램 생성 시작 (3개 레벨) - 목표: {training_goal}, 종목: {strokes}"
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
        )

        raw_result = await self.llm.generate_program_json(
            system_prompt=SYSTEM_PROMPT,
            user_prompt=user_prompt,
        )

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
