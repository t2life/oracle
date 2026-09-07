from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol

from ..logging_utils import get_logger
from ..models import PushCampaign


class PushDeliveryError(ValueError):
    """プッシュ実配信に失敗したことを表す例外（API層では400系に変換される）。"""


@dataclass(slots=True)
class PushSendReport:
    mode: str
    target_count: int
    sent_count: int
    message: str


class PushSender(Protocol):
    def send_campaign(self, campaign: PushCampaign, tokens: list[str]) -> PushSendReport:
        """送信不能時は PushDeliveryError を送出する。"""


class NoopPushSender:
    """実配信を行わない既定送信器（モード noop）。

    「送ったつもり」事故を防ぐため、実送信が行われていないことを
    WARNINGログとレスポンスメッセージの両方で明示する。
    """

    def __init__(self) -> None:
        self._logger = get_logger(self.__class__.__name__)

    def send_campaign(self, campaign: PushCampaign, tokens: list[str]) -> PushSendReport:
        self._logger.warning(
            "実配信モード未設定のため送信をスキップ: campaign_id=%s 対象トークン=%s件",
            campaign.campaign_id,
            len(tokens),
        )
        return PushSendReport(
            mode="noop",
            target_count=len(tokens),
            sent_count=0,
            message=(
                f"実配信モード未設定（noop）: 対象{len(tokens)}件への実送信は行われていません。"
            ),
        )


class FcmV1PushSender:
    """FCM HTTP v1 送信器の骨格。

    認証情報が未設定の場合は起動時に明示エラーとする（fail-fast）。
    実HTTP接続はサービスアカウント投入後に実装する。実装完了までは
    fail-closed（配信失敗扱い）とし、配信済みステータスへの誤遷移を防ぐ。
    """

    def __init__(self, project_id: str, service_account_json: str) -> None:
        if not project_id or not service_account_json:
            raise ValueError(
                "FCM送信の認証情報（ORACLE_FCM_PROJECT_ID / "
                "ORACLE_FCM_SERVICE_ACCOUNT_JSON）が未設定です。"
            )
        self._project_id = project_id
        self._service_account_json = service_account_json
        self._logger = get_logger(self.__class__.__name__)

    def send_campaign(self, campaign: PushCampaign, tokens: list[str]) -> PushSendReport:
        self._logger.warning(
            "FCM HTTP v1との実接続は未実装のため配信を拒否: campaign_id=%s",
            campaign.campaign_id,
        )
        raise PushDeliveryError(
            "FCM HTTP v1との実接続は未実装です。ロードマップB-3の実装完了後に利用できます。"
        )
