from __future__ import annotations

from datetime import timedelta

from ..config import AppConfig
from ..logging_utils import get_logger
from ..models import PlanType, PurchaseResult, User
from ..store import InMemoryStore
from ..time_utils import now_jst
from .receipt_verification import ReceiptVerificationError, ReceiptVerifier


class BillingService:
    def __init__(
        self,
        store: InMemoryStore,
        config: AppConfig,
        receipt_verifier: ReceiptVerifier,
    ) -> None:
        self._store = store
        self._config = config
        self._receipt_verifier = receipt_verifier
        self._logger = get_logger(self.__class__.__name__)

    def _refresh_subscription_status(self, user: User) -> None:
        if user.plan != PlanType.SUBSCRIPTION:
            return
        if user.subscription_expires_at is None:
            user.plan = PlanType.FREE
            user.updated_at = now_jst()
            self._store.update_user(user)
            return
        if user.subscription_expires_at <= now_jst():
            user.plan = PlanType.FREE
            user.subscription_expires_at = None
            user.updated_at = now_jst()
            self._store.update_user(user)

    def refresh_subscription_status(self, user: User) -> User:
        self._refresh_subscription_status(user)
        return user

    def is_paid_user(self, user: User) -> bool:
        self._refresh_subscription_status(user)
        return user.plan in {PlanType.TICKET, PlanType.SUBSCRIPTION, PlanType.ADMIN}

    def can_use_draw_count(self, user: User, draw_count: int) -> bool:
        if draw_count <= 1:
            return True
        self._refresh_subscription_status(user)
        return self.is_paid_user(user)

    def consume_for_session(self, user: User, draw_count: int) -> None:
        self._refresh_subscription_status(user)
        if user.plan == PlanType.TICKET:
            if user.tickets < draw_count:
                raise PermissionError("チケット残高が不足しています。")
            user.tickets -= draw_count
            user.updated_at = now_jst()
            self._store.update_user(user)
            self._logger.debug(
                "チケット消費: user_id=%s 消費=%s 残高=%s",
                user.user_id,
                draw_count,
                user.tickets,
            )

    def verify_purchase(self, user_id: str, product_code: str, receipt_id: str) -> PurchaseResult:
        try:
            self._receipt_verifier.verify(
                user_id=user_id,
                product_code=product_code,
                receipt_id=receipt_id,
            )
        except ReceiptVerificationError as exc:
            self._logger.warning(
                "レシート検証失敗: user_id=%s product=%s 理由=%s",
                user_id,
                product_code,
                exc,
            )
            raise ValueError(f"レシート検証に失敗しました: {exc}") from exc

        user = self._store.get_or_create_user(user_id)
        if not self._store.register_receipt_if_new(receipt_id):
            return PurchaseResult(
                accepted=True,
                user_id=user.user_id,
                plan=user.plan,
                tickets=user.tickets,
                message="同一レシートのため、重複処理をスキップしました。",
            )

        ticket_amount = self._config.pricing.ticket_products.get(product_code)
        if ticket_amount is not None:
            user.plan = PlanType.TICKET
            user.tickets += ticket_amount
            user.updated_at = now_jst()
            self._store.update_user(user)
            self._logger.info(
                "課金検証成功: user_id=%s 商品=%s チケット=%s",
                user.user_id,
                product_code,
                ticket_amount,
            )
            return PurchaseResult(
                accepted=True,
                user_id=user.user_id,
                plan=user.plan,
                tickets=user.tickets,
                message="チケット購入を反映しました。",
            )

        if product_code == self._config.pricing.subscription_product_code:
            now = now_jst()
            trial_days = self._config.pricing.subscription_trial_days
            user.plan = PlanType.SUBSCRIPTION
            user.subscription_expires_at = now + timedelta(days=30 + trial_days)
            user.updated_at = now
            self._store.update_user(user)
            self._logger.info(
                "課金検証成功: user_id=%s 商品=%s サブスク期限=%s",
                user.user_id,
                product_code,
                user.subscription_expires_at,
            )
            return PurchaseResult(
                accepted=True,
                user_id=user.user_id,
                plan=user.plan,
                tickets=user.tickets,
                message="サブスクリプションを反映しました。",
            )

        raise ValueError("未対応の商品コードです。")

    def restore_purchase(self, user_id: str, product_code: str, restore_receipt_id: str) -> PurchaseResult:
        result = self.verify_purchase(
            user_id=user_id,
            product_code=product_code,
            receipt_id=f"restore:{restore_receipt_id}",
        )
        result.message = "購入復元を反映しました。"
        self._logger.info(
            "購入復元: user_id=%s product_code=%s",
            user_id,
            product_code,
        )
        return result
