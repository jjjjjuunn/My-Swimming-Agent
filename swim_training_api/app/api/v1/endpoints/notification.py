"""알림 관련 API 엔드포인트"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional

from app.services.notification_service import NotificationService

router = APIRouter(prefix="/notifications", tags=["notifications"])


class FCMTokenRequest(BaseModel):
    user_id: str
    fcm_token: str


class NotificationPrefsRequest(BaseModel):
    user_id: str
    morning_enabled: bool = True
    morning_time: str = "07:00"
    post_workout_enabled: bool = True
    weekly_report_enabled: bool = True


class SendNotificationRequest(BaseModel):
    user_id: str
    template_key: str
    extra_data: Optional[dict] = None


@router.post("/register-token")
async def register_fcm_token(req: FCMTokenRequest):
    """FCM 토큰 등록 — 앱 시작 시 호출."""
    success = NotificationService.save_fcm_token(req.user_id, req.fcm_token)
    if not success:
        raise HTTPException(status_code=500, detail="FCM 토큰 저장 실패")
    return {"status": "ok", "message": "FCM 토큰 등록 완료"}


@router.post("/preferences")
async def save_preferences(req: NotificationPrefsRequest):
    """알림 설정 저장."""
    success = NotificationService.save_notification_preferences(
        user_id=req.user_id,
        morning_enabled=req.morning_enabled,
        morning_time=req.morning_time,
        post_workout_enabled=req.post_workout_enabled,
        weekly_report_enabled=req.weekly_report_enabled,
    )
    if not success:
        raise HTTPException(status_code=500, detail="알림 설정 저장 실패")
    return {"status": "ok", "message": "알림 설정 저장 완료"}


@router.get("/preferences/{user_id}")
async def get_preferences(user_id: str):
    """알림 설정 조회."""
    prefs = NotificationService.get_notification_preferences(user_id)
    return {"status": "ok", "preferences": prefs}


@router.post("/send")
async def send_notification(req: SendNotificationRequest):
    """특정 사용자에게 템플릿 알림 전송."""
    token = NotificationService.get_fcm_token(req.user_id)
    if not token:
        raise HTTPException(status_code=404, detail="FCM 토큰 없음")

    success = NotificationService.send_template(
        fcm_token=token,
        template_key=req.template_key,
        extra_data=req.extra_data,
    )
    if not success:
        raise HTTPException(status_code=500, detail="알림 전송 실패")
    return {"status": "ok", "message": "알림 전송 완료"}


@router.post("/trigger/morning")
async def trigger_morning_notifications():
    """아침 컨디션 체크 알림 일괄 전송.

    외부 스케줄러(Cloud Functions, cron 등)에서 호출.
    """
    result = NotificationService.send_morning_check_to_all()
    if "error" in result:
        raise HTTPException(status_code=500, detail=result["error"])
    return {"status": "ok", "result": result}
