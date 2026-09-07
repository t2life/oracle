from __future__ import annotations

from ..logging_utils import get_logger
from ..models import AdminUser
from ..store import InMemoryStore
from ..time_utils import now_jst
from .analytics_service import AnalyticsService
from .notification_service import NotificationService


class AdminService:
    def __init__(
        self,
        store: InMemoryStore,
        analytics_service: AnalyticsService,
        notification_service: NotificationService,
    ) -> None:
        self._store = store
        self._analytics_service = analytics_service
        self._notification_service = notification_service
        self._logger = get_logger(self.__class__.__name__)

    def login(self, email: str, password: str):
        admin_user = self._store.get_admin_user_by_email(email)
        if admin_user is None or admin_user.password != password:
            raise PermissionError("管理者認証に失敗しました。")
        session = self._store.create_admin_session(admin_user_id=admin_user.admin_user_id)
        self._logger.info("管理者ログイン: admin_user_id=%s", admin_user.admin_user_id)
        return admin_user, session

    def require_admin(self, token: str, required_permission: str | None = None) -> AdminUser:
        session = self._store.get_admin_session(token)
        if session is None:
            raise PermissionError("管理者セッションが無効です。")
        admin_user = self._store.get_admin_user(session.admin_user_id)
        if admin_user is None or not admin_user.is_active:
            raise PermissionError("管理者ユーザーが無効です。")
        if required_permission is not None:
            role = self._store.get_admin_role(admin_user.role_id)
            if role is None or required_permission not in role.permissions:
                self._logger.warning(
                    "管理者権限不足: admin_user_id=%s role=%s 要求権限=%s",
                    admin_user.admin_user_id,
                    admin_user.role_id,
                    required_permission,
                )
                raise PermissionError("この操作を行う権限がありません。")
        return admin_user

    def get_dashboard(self) -> dict[str, int | str]:
        kpi = self._analytics_service.get_kpi_snapshot()
        return {
            "users_total": len(self._store.list_users()),
            "inquiries_total": len(self._store.list_inquiries()),
            "announcements_total": len(self._store.list_announcements()),
            "campaigns_total": len(self._store.list_push_campaigns()),
            "reading_completed": kpi.get("reading_completed", 0),
            "ticket_purchased": kpi.get("ticket_purchased", 0),
            "subscription_started": kpi.get("subscription_started", 0),
            "updated_at": now_jst().isoformat(),
        }

    def create_announcement(
        self,
        title: str,
        body: str,
        category: str,
        start_at,
        end_at,
        is_important: bool,
        link_url: str | None,
    ):
        return self._store.create_announcement(
            title=title,
            body=body,
            category=category,
            start_at=start_at,
            end_at=end_at,
            is_important=is_important,
            link_url=link_url,
        )

    def create_push_campaign(
        self,
        title: str,
        body: str,
        category: str,
        target_segment: str,
        scheduled_at,
        is_ab_test: bool,
    ):
        return self._notification_service.create_campaign(
            title=title,
            body=body,
            category=category,
            target_segment=target_segment,
            scheduled_at=scheduled_at,
            is_ab_test=is_ab_test,
        )

    def list_push_campaigns(self):
        return self._notification_service.list_campaigns()

    def dispatch_push_campaign(self, campaign_id: str):
        return self._notification_service.dispatch_campaign(campaign_id)
