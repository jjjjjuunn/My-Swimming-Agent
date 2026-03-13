"""
LLM Service using OpenAI API
"""
import json
import re
from typing import Dict, Any
from langchain_openai import ChatOpenAI
from langchain_core.messages import SystemMessage, HumanMessage
from tenacity import retry, stop_after_attempt, wait_exponential

from app.core.config import get_settings
from app.utils.logger import get_logger

logger = get_logger(__name__)


class LLMService:
    """OpenAI API 연동 서비스"""

    def __init__(self):
        settings = get_settings()
        self.model = ChatOpenAI(
            model=settings.openai_model,
            openai_api_key=settings.openai_api_key,
            temperature=0.4,
            max_tokens=8192,
        )
        logger.info(f"Initialized OpenAI model: {settings.openai_model}")

    @retry(
        stop=stop_after_attempt(2),
        wait=wait_exponential(multiplier=1, min=2, max=10),
    )
    async def generate_program_json(
        self,
        system_prompt: str,
        user_prompt: str,
    ) -> Dict[str, Any]:
        """
        OpenAI LLM을 사용하여 수영 프로그램 생성

        Args:
            system_prompt: LLM에 대한 시스템 지침
            user_prompt: 컨텍스트가 포함된 사용자 요청

        Returns:
            생성된 프로그램 구조를 포함하는 Dict
        """
        content = ""
        try:
            logger.info("OpenAI API 요청 전송 중...")

            messages = [
                SystemMessage(content=system_prompt),
                HumanMessage(
                    content=user_prompt
                    + "\n\nPlease respond ONLY with valid JSON following the exact structure specified above. "
                    "No markdown, no explanations, just the JSON object."
                ),
            ]

            response = await self.model.ainvoke(messages)

            content = response.content
            if not isinstance(content, str):
                content = str(content)

            logger.debug(f"OpenAI 응답: {str(content)[:200]}...")

            content = self._extract_json(content)

            program_data = json.loads(content)
            logger.info("OpenAI에서 프로그램 생성 완료")

            return program_data

        except json.JSONDecodeError as e:
            logger.error(f"JSON 응답 파싱 실패: {str(e)}")
            logger.error(f"응답 내용: {content[:500]}")
            raise ValueError(f"OpenAI의 잘못된 JSON 응답: {str(e)}")
        except Exception as e:
            logger.error(f"프로그램 생성 오류: {str(e)}")
            raise

    @staticmethod
    def _extract_json(content: str) -> str:
        """LLM 응답에서 JSON 본문을 추출. 마크다운 래핑/전후 텍스트 처리."""
        content = content.strip()
        if content.startswith("```json"):
            content = content[7:]
        if content.startswith("```"):
            content = content[3:]
        if content.endswith("```"):
            content = content[:-3]
        content = content.strip()

        if not content.startswith("{"):
            start = content.find("{")
            if start == -1:
                return content
            depth = 0
            end = start
            for i in range(start, len(content)):
                if content[i] == "{":
                    depth += 1
                elif content[i] == "}":
                    depth -= 1
                    if depth == 0:
                        end = i
                        break
            content = content[start:end + 1]

        return content

    async def generate_text(
        self,
        system_prompt: str,
        user_prompt: str,
    ) -> str:
        """텍스트 응답 생성 (JSON이 아닌 자연어)"""
        try:
            full_prompt = f"{system_prompt}\n\n{user_prompt}"
            logger.info("OpenAI 텍스트 생성 요청 중...")
            response = await self.model.ainvoke(full_prompt)
            content = response.content
            if not isinstance(content, str):
                content = str(content)
            logger.info("텍스트 생성 완료")
            return content.strip()
        except Exception as e:
            logger.error(f"텍스트 생성 오류: {str(e)}")
            raise
