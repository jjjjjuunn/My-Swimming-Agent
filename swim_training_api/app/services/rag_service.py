import logging
from typing import Optional

from app.core.config import get_settings

logger = logging.getLogger(__name__)


class RAGService:
    """벡터 DB 기반 RAG 시스템"""
    
    # 클래스 변수: 모든 인스턴스가 공유 (한 번 실패하면 영구 비활성화)
    _disabled = False
    _vectorstore = None

    def __init__(self):
        self.settings = get_settings()

    def _get_vectorstore(self):
        """Chroma 벡터스토어 로드 (lazy init)"""
        if RAGService._disabled:
            return None
            
        if RAGService._vectorstore is not None:
            return RAGService._vectorstore

        try:
            from langchain_google_genai import GoogleGenerativeAIEmbeddings
            from langchain_community.vectorstores import Chroma

            embeddings = GoogleGenerativeAIEmbeddings(
                model="models/embedding-001",
                google_api_key=self.settings.google_api_key,
            )

            RAGService._vectorstore = Chroma(
                persist_directory=self.settings.chroma_persist_dir,
                embedding_function=embeddings,
            )

            logger.info("Chroma 벡터스토어 로드 완료")
            return RAGService._vectorstore

        except Exception as e:
            logger.warning(f"벡터스토어 로드 실패: {e}")
            RAGService._disabled = True  # 한 번 실패하면 영구 비활성화
            return None

    async def search_relevant_docs(
        self,
        training_goal: str,
        strokes: list[str],
        k: int = 5,
    ) -> Optional[str]:
        """훈련 목표와 종목에 관련된 전문 자료 검색"""
        
        # RAG가 비활성화되었으면 즉시 반환 (API 호출 안 함)
        if RAGService._disabled:
            return None

        vectorstore = self._get_vectorstore()
        if vectorstore is None:
            logger.info("벡터스토어 없음 - RAG 없이 진행")
            return None

        try:
            query = self._build_search_query(training_goal, strokes)
            docs = vectorstore.similarity_search(query, k=k)

            if not docs:
                return None

            # 검색된 문서를 하나의 컨텍스트로 합침
            context = "\n\n---\n\n".join(
                [doc.page_content for doc in docs]
            )

            logger.info(f"RAG 검색 결과: {len(docs)}건")
            return context

        except Exception as e:
            logger.warning(f"RAG 검색 실패: {e}")
            return None

    def _build_search_query(
        self, training_goal: str, strokes: list[str]
    ) -> str:
        """검색 쿼리 생성"""

        goal_map = {
            "speed": "sprint speed training sets intervals",
            "endurance": "distance endurance long swim aerobic",
            "technique": "drill technique form correction",
            "overall": "balanced training mixed workout fitness",
        }

        stroke_map = {
            "freestyle": "freestyle front crawl",
            "butterfly": "butterfly fly stroke",
            "backstroke": "backstroke back",
            "breaststroke": "breaststroke breast",
            "IM": "individual medley IM all strokes",
        }

        goal_text = goal_map.get(training_goal, training_goal)
        stroke_text = " ".join(
            [stroke_map.get(s, s) for s in strokes]
        )

        return f"swimming training program {goal_text} {stroke_text}"
