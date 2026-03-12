import logging

import httpx
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/auth", tags=["auth"])


class KakaoAuthRequest(BaseModel):
    access_token: str


@router.post("/kakao")
async def kakao_login(request: KakaoAuthRequest):
    """
    Kakao 액세스 토큰을 검증하고 Firebase 커스텀 토큰을 반환합니다.
    흐름: Kakao 사용자 정보 조회 → Firebase Auth 커스텀 토큰 발급
    """
    # 1. Kakao API로 사용자 정보 조회
    async with httpx.AsyncClient() as client:
        kakao_resp = await client.get(
            "https://kapi.kakao.com/v2/user/me",
            headers={"Authorization": f"Bearer {request.access_token}"},
        )

    if kakao_resp.status_code != 200:
        raise HTTPException(
            status_code=401,
            detail=f"Kakao 토큰 검증 실패: {kakao_resp.status_code}",
        )

    kakao_data = kakao_resp.json()
    kakao_id = str(kakao_data.get("id"))
    if not kakao_id:
        raise HTTPException(status_code=401, detail="Kakao 사용자 ID를 가져올 수 없습니다.")

    # Firebase Auth uid: "kakao:{kakao_id}" 형식으로 고유성 보장
    firebase_uid = f"kakao:{kakao_id}"

    # 2. Firebase 커스텀 토큰 생성
    try:
        import firebase_admin
        from firebase_admin import auth as firebase_auth

        from app.services.firebase_service import _init_firebase

        _init_firebase()

        # 추가 클레임 (선택)
        kakao_account = kakao_data.get("kakaoAccount", {}) or kakao_data.get("kakao_account", {})
        additional_claims = {
            "provider": "kakao",
            "kakao_id": kakao_id,
        }
        email = kakao_account.get("email")
        if email:
            additional_claims["email"] = email

        custom_token: bytes = firebase_auth.create_custom_token(
            firebase_uid, additional_claims
        )
        firebase_token = custom_token.decode("utf-8") if isinstance(custom_token, bytes) else custom_token

    except Exception as e:
        logger.error(f"Firebase 커스텀 토큰 생성 실패: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Firebase 토큰 생성에 실패했습니다: {str(e)}",
        )

    logger.info(f"✅ Kakao 로그인 성공 — firebase_uid: {firebase_uid}")
    return {"firebase_token": firebase_token, "uid": firebase_uid}
