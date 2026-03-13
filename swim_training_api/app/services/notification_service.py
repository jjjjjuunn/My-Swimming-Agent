"""Push 알림 서비스 — Firebase Cloud Messaging (FCM)

Agent가 먼저 사용자에게 말을 거는 핵심 인프라.
- 아침 컨디션 체크 알림
- 운동 후 메모 요청 알림
- 커스텀 코칭 알림
"""

import logging
from datetime import datetime, timezone
from typing import Optional

from app.services.firebase_service import _init_firebase

logger = logging.getLogger(__name__)


class NotificationService:
    """FCM 기반 Push 알림 전송 서비스."""

    TEMPLATES = {
        "morning_condition": {
            "title": "🏊‍♂️ 오늘 컨디션은 어떠세요?",
            "body": "컨디션을 알려주시면 맞춤 훈련을 준비해 드릴게요!",
            "action": "condition_check",
        },
        "post_workout": {
            "title": "💪 수고하셨어요!",
            "body": "오늘 훈련은 어떠셨나요? 메모를 남겨주세요.",
            "action": "workout_memo",
        },
        "weekly_report": {
            "title": "📊 이번 주 수영 리포트",
            "body": "이번 주 훈련 요약이 준비되었어요. 확인해보세요!",
            "action": "weekly_report",
        },
        "training_reminder": {
            "title": "🏊 오늘 훈련 잊지 않으셨죠?",
            "body": "오늘 예정된 수영 훈련이 있어요!",
            "action": "training_reminder",
        },
    }

    @staticmethod
    def send_push(
        fcm_token: str,
        title: str,
        body: str,
        data: Optional[dict] = None,
    ) -> bool:
        """FCM Push 알림 전송."""
        try:
            _init_firebase()
            from firebase_admin import messaging

            message = messaging.Message(
                notification=messaging.Notification(title=title, body=body),
                data=data or {},
                token=fcm_token,
                apns=messaging.APNSConfig(
                    payload=messaging.APNSPayload(
                        aps=messaging.Aps(sound="default", badge=1),
                    ),
                ),
                android=messaging.AndroidConfig(
                    priority="high",
                    notification=messaging.AndroidNotification(
                        sound="default",
                        click_action="FLUTTER_NOTIFICATION_CLICK",
                    ),
                ),
            )

            response = messaging.send(message)
            logger.info(f"Push 전송 성공: {response}")
            return True
        except Exception as e:
            logger.error(f"Push 전송 실패: {e}")
            return False

    @classmethod
    def send_template(
        cls, fcm_token: str, template_key: str, extra_data: Optional[dict] = None,
    ) -> bool:
        """미리 정의된 템플릿으로 Push 전송."""
        template = cls.TEMPLATES.get(template_key)
        if not template:
            logger.error(f"알 수 없는 템플릿: {template_key}")
            return False

        data = {"action": template["action"]}
        if extra_data:
            data.update(extra_data)

        return cls.send_push(
            fcm_token=fcm_token, title=template["title"],
            body=template["body"], data=data,
        )

    @staticmethod
    def save_fcm_token(user_id: str, fcm_token: str) -> bool:
        """사용자의 FCM 토큰을 Firebase에 저장."""
        try:
            _init_firebase()
            from firebase_admin import firestore

            db = firestore.client()
            db.collection("users").document(user_id).set(
                {
                    "fcm_token": fcm_token,
                    "fcm_token_updated_at": datetime.now(timezone.utc).isoformat(),
                },
                merge=True,
            )
            logger.info(f"FCM 토큰 저장 완료: {user_id}")
            return True
        except Exception as e:
            logger.error(f"FCM 토큰 저장 실패: {e}")
            return False

    @staticmethod
    def get_fcm_token(user_id: str) -> Optional[str]:
        """사용자의 FCM 토큰 조회."""
        try:
            _init_firebase()
            from firebase_admin import firestore

            db = firestore.client()
            doc = db.collection("users").document(user_id).get()
            if doc.exists:
                return doc.to_dict().get("fcm_token")
            return None
        except Exception as e:
            logger.error(f"FCM 토큰 조회 실패: {e}")
            return None

    @staticmethod
    def save_notification_preferences(
        user_id: str,
        morning_enabled: bool = True,
        morning_time: str = "07:00",
        post_workout_enabled: bool = True,
        weekly_report_enabled: bool = True,
    ) -> bool:
        """사용자 알림 설정 저장."""
        try:
            _init_firebase()
            from firebase_admin import firestore

            db = firestore.client()
            db.collection("users").document(user_id).set(
                {
                    "notification_preferences": {
                        "morning_enabled": morning_enabled,
                        "morning_time": morning_time,
                        "post_workout_enabled": post_workout_enabled,
                        "weekly_report_enabled": weekly_report_enabled,
                        "updated_at": datetime.now(timezone.utc).isoformat(),
                    },
                },
                merge=True,
            )
            logger.info(f"알림 설정 저장 완료: {user_id}")
            return True
        except Exception as e:
            logger.error(f"알림 설정 저장 실패: {e}")
            return False

    @staticmethod
    def get_notification_preferences(user_id: str) -> dict:
        """사용자 알림 설정 조회."""
        try:
            _init_firebase()
            from firebase_admin import firestore

            db = firestore.client()
            doc = db.collection("users").document(user_id).get()
            if doc.exists:
                return doc.to_dict().get("notification_preferences", {})
            return {}
        except Exception as e:
            logger.error(f"알림 설정 조회 실패: {e}")
            return {}

    @classmethod
    def send_morning_check_to_all(cls) -> dict:
        """모든 아침 알림 활성화 사용자에게 컨디션 체크 Push 전송.

        외부 스케줄러(Cloud Functions, cron 등)에서 호출.
        """
        try:
            _init_firebase()
            from firebase_admin import firestore

            db = firestore.client()
            users = db.collection("users").stream()

            sent = 0
            failed = 0
            skipped = 0

            for doc in users:
                data = doc.to_dict()
                token = data.get("fcm_token")
                prefs = data.get("notification_preferences", {})

                if not token:
                    skipped += 1
                    continue
                if not prefs.get("morning_enabled", True):
                    skipped += 1
                    continue

                success = cls.send_template(
                    fcm_token=token,
                    template_key="morning_condition",
                    extra_data={"user_id": doc.id},
                )
                if success:
                    sent += 1
                else:
                    failed += 1

            result = {"sent": sent, "failed": failed, "skipped": skipped}
            logger.info(f"아침 알림 전송 결과: {result}")
            return result
        except Exception as e:
            logger.error(f"아침 알림 전송 실패: {e}")
            return {"error": str(e)}
