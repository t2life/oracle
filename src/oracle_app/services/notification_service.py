from __future__ import annotations

from datetime import datetime

from ..logging_utils import get_logger
from ..models import PushCampaign
from ..store import InMemoryStore
from .push_sender import PushSender, PushSendReport


class NotificationService:
    def __init__(self, store: InMemoryStore, push_sender: PushSender) -> None:
        self._store = store
        self._push_sender = push_sender
        self._logger = get_logger(self.__class__.__name__)

    def register_device_token(self, user_id: str, token: str) -> None:
        self._store.save_notification_token(user_id, token)
        self._logger.info("通知トークン登録: user_id=%s", user_id)

    def should_prompt_permission(self, user_id: str, completed_readings: int) -> bool:
        has_token = self._store.has_notification_token(user_id)
        if has_token:
            return False
        return completed_readings >= 1

    def create_campaign(
        self,
        title: str,
        body: str,
        category: str,
        target_segment: str,
        scheduled_at: datetime,
        is_ab_test: bool,
    ) -> PushCampaign:
        campaign = self._store.create_push_campaign(
            title=title,
            body=body,
            category=category,
            target_segment=target_segment,
            scheduled_at=scheduled_at,
            is_ab_test=is_ab_test,
        )
        self._logger.info("通知キャンペーン作成: campaign_id=%s", campaign.campaign_id)
        return campaign

    def list_campaigns(self) -> list[PushCampaign]:
        return self._store.list_push_campaigns()

    def dispatch_campaign(self, campaign_id: str) -> tuple[PushCampaign, PushSendReport]:
        campaign = self._store.get_push_campaign(campaign_id)
        if campaign is None:
            raise ValueError("キャンペーンが存在しません。")

        tokens = self._store.list_notification_tokens()
        report = self._push_sender.send_campaign(campaign, tokens)
        campaign = self._store.mark_campaign_dispatched(campaign_id)
        self._logger.info(
            "通知キャンペーン配信: campaign_id=%s mode=%s 送信=%s/%s",
            campaign_id,
            report.mode,
            report.sent_count,
            report.target_count,
        )
        return campaign, report
