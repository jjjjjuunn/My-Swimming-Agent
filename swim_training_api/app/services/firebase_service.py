import logging
from typing import Optional

from app.core.config import get_settings

logger = logging.getLogger(__name__)

# Firebase 초기화 여부 플래그
_firebase_initialized = False


def _init_firebase():
    """Firebase Admin SDK 초기화 (앱 시작 시 한번만)"""
    global _firebase_initialized
    if _firebase_initialized:
        return

    try:
        import firebase_admin
        from firebase_admin import credentials

        settings = get_settings()
        cred = credentials.Certificate(settings.firebase_credentials_path)
        firebase_admin.initialize_app(cred)
        _firebase_initialized = True
        logger.info("Firebase Admin SDK 초기화 완료")
    except FileNotFoundError:
        logger.warning(
            "Firebase credentials 파일을 찾을 수 없습니다. "
            "검색 이력 분석 기능이 비활성화됩니다."
        )
    except Exception as e:
        logger.warning(f"Firebase 초기화 실패: {e}")


class FirebaseService:
    """Firestore에서 사용자 데이터를 조회하는 서비스"""

    def __init__(self):
        _init_firebase()

    async def get_search_history(self, user_id: str) -> list[str]:
        """사용자의 검색 이력을 가져옴"""
        if not _firebase_initialized:
            logger.info("Firebase 미초기화 - 검색 이력 없이 진행")
            return []

        try:
            from firebase_admin import firestore

            db = firestore.client()
            history_ref = (
                db.collection("users")
                .document(user_id)
                .collection("search_history")
                .order_by("timestamp", direction="DESCENDING")
                .limit(20)
            )

            docs = history_ref.stream()
            queries = [doc.to_dict().get("query", "") for doc in docs]

            logger.info(f"검색 이력 {len(queries)}건 조회 (user: {user_id})")
            return queries

        except Exception as e:
            logger.warning(f"검색 이력 조회 실패: {e}")
            return []

    def analyze_search_patterns(self, search_history: list[str]) -> Optional[str]:
        """검색 이력을 LLM이 직접 해석할 수 있도록 원문 그대로 전달"""
        if not search_history:
            return None

        # 중복 제거하되 순서 유지 (최신순)
        seen = set()
        unique = []
        for q in search_history:
            q_lower = q.strip().lower()
            if q_lower and q_lower not in seen:
                seen.add(q_lower)
                unique.append(q.strip())

        recent = unique[:10]  # 최근 고유 검색어 10개

        return (
            f"최근 검색어 (최신순): {', '.join(recent)}\n"
            f"총 검색 횟수: {len(search_history)}건"
        )
