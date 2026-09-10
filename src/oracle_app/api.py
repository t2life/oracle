from __future__ import annotations

from typing import Any

from fastapi import FastAPI, Header, HTTPException, Query

from .config import AppConfig
from .logging_utils import get_logger
from .models import AuthProvider, PlanType
from .orchestrator import ServiceContainer, build_service_container
from .schemas import (
    AdminDashboardResponse,
    AdminLoginRequest,
    AdminLoginResponse,
    AdminUserResponse,
    AuditLogResponse,
    AnalyticsEventRequest,
    AnalyticsEventResponse,
    AnnouncementCreateRequest,
    AnnouncementResponse,
    AuthLoginRequest,
    AuthLogoutRequest,
    AuthProviderRequest,
    CardResponse,
    CompleteShuffleRequest,
    DeckAdminResponse,
    DeckResponse,
    ExternalLinkResponse,
    HistoryItemResponse,
    InquiryRequest,
    InquiryResponse,
    KpiSnapshotResponse,
    HealthReadyResponse,
    LiveEventResponse,
    MessageResponse,
    NotificationTokenRequest,
    PileStatusResponse,
    ProductResponse,
    ProfileResponse,
    ProfileUpdateRequest,
    PurchaseRestoreRequest,
    PurchaseVerifyRequest,
    PurchaseVerifyResponse,
    PushCampaignCreateRequest,
    PushCampaignResponse,
    ReadingResultResponse,
    ResultCardResponse,
    SaveHistoryRequest,
    SpreadResponse,
    SelectCardRequest,
    SelectPileRequest,
    StartReadingRequest,
    StartReadingResponse,
    ThemeAdminResponse,
    ThemeResponse,
    TransferCodeIssueRequest,
    TransferCodeRedeemRequest,
    TransferCodeResponse,
    UserResponse,
    UserSummaryResponse,
)
from .time_utils import date_key_jst, now_jst


def _convert_error(exc: Exception) -> HTTPException:
    if isinstance(exc, PermissionError):
        return HTTPException(status_code=403, detail=str(exc))
    if isinstance(exc, ValueError):
        return HTTPException(status_code=400, detail=str(exc))
    return HTTPException(status_code=500, detail="内部エラーが発生しました。")


def _map_user(container: ServiceContainer, user) -> UserResponse:
    profile = container.store.get_or_create_profile(user.user_id)
    return UserResponse(
        user_id=user.user_id,
        plan=user.plan.value,
        tickets=user.tickets,
        visit_count=user.visit_count,
        subscription_expires_at=user.subscription_expires_at,
        display_name=profile.display_name,
    )


def _map_result(result) -> ReadingResultResponse:
    return ReadingResultResponse(
        session_id=result.session_id,
        user_id=result.user_id,
        theme_id=result.theme_id,
        deck_id=result.deck_id,
        card_id=result.card_id,
        card_name=result.card_name,
        keywords=result.keywords,
        interpretation_text=result.interpretation_text,
        caution_text=result.caution_text,
        created_at=result.created_at,
        copied=result.copied,
        card_name_en=result.card_name_en,
        keywords_en=result.keywords_en,
        interpretation_text_en=result.interpretation_text_en,
        caution_text_en=result.caution_text_en,
        card_name_zh=result.card_name_zh,
        keywords_zh=result.keywords_zh,
        interpretation_text_zh=result.interpretation_text_zh,
        caution_text_zh=result.caution_text_zh,
        combination_text=result.combination_text,
        spread_id=getattr(result, "spread_id", "daily"),
        question_text=getattr(result, "question_text", ""),
        cards=[
            ResultCardResponse(
                card_id=item.card_id,
                card_name=item.card_name,
                keywords=item.keywords,
                position_index=item.position_index,
                position_name=item.position_name,
                position_meaning=item.position_meaning,
                reading=item.reading,
                attribute=item.attribute,
                element=item.element,
            )
            for item in getattr(result, "cards", [])
        ],
    )


def _oracle_daily_limit_reached(container, user, spread: dict) -> bool:
    """本日の託宣（無料枠）を今日すでに使い切っているか。

    判定規則は `ReadingService.start_session` と同一（無料・ゲストのみ対象）。
    有料プランやリーディングのスプレッドでは常に False。
    """
    if spread.get("kind") != "oracle":
        return False
    if user.plan not in {PlanType.FREE, PlanType.GUEST}:
        return False
    used = container.store.count_user_sessions_on_date(
        user.user_id, date_key_jst(now_jst())
    )
    return used >= container.config.free_daily_draw_limit


def _map_announcement(announcement) -> AnnouncementResponse:
    return AnnouncementResponse(
        announcement_id=announcement.announcement_id,
        title=announcement.title,
        body=announcement.body,
        category=announcement.category,
        start_at=announcement.start_at,
        end_at=announcement.end_at,
        is_important=announcement.is_important,
        link_url=announcement.link_url,
    )


def _map_campaign(campaign, dispatch_result: str | None = None) -> PushCampaignResponse:
    return PushCampaignResponse(
        campaign_id=campaign.campaign_id,
        title=campaign.title,
        body=campaign.body,
        category=campaign.category,
        target_segment=campaign.target_segment,
        scheduled_at=campaign.scheduled_at,
        created_at=campaign.created_at,
        status=campaign.status.value,
        is_ab_test=campaign.is_ab_test,
        dispatch_result=dispatch_result,
    )


def _track_event(
    container: ServiceContainer,
    event_name: str,
    user_id: str | None,
    properties: dict[str, str] | None = None,
) -> None:
    try:
        container.analytics_service.track_event(
            event_name=event_name,
            user_id=user_id,
            properties=properties,
        )
    except Exception:  # noqa: BLE001
        # 分析記録失敗は業務APIを失敗させない
        return


def _audit_action(
    container: ServiceContainer,
    actor_type: str,
    actor_id: str,
    action: str,
    resource_type: str,
    resource_id: str | None,
    detail: dict[str, str] | None = None,
) -> None:
    logger = get_logger("Audit")

    try:
        container.store.add_audit_log(
            actor_type=actor_type,
            actor_id=actor_id,
            action=action,
            resource_type=resource_type,
            resource_id=resource_id,
            detail=detail,
        )
    except Exception as exc:  # noqa: BLE001
        logger.warning("監査ログ保存に失敗しました: %s", exc)


def _build_health_components(container: ServiceContainer) -> tuple[str, dict[str, str]]:
    components: dict[str, str] = {
        "app": "ok",
        "backend": container.config.persistence_backend,
    }

    has_degraded = False

    wants_postgres = (
        container.config.persistence_backend.strip().lower() in {"postgres", "postgresql", "hybrid"}
        or container.config.postgres.enabled
    )
    wants_redis = (
        container.config.persistence_backend.strip().lower() in {"redis", "hybrid"}
        or container.config.redis.enabled
    )

    postgres = getattr(container.store, "_postgres", None)
    redis_cache = getattr(container.store, "_redis_cache", None)

    if wants_postgres:
        if postgres is None:
            components["postgres"] = "degraded"
            has_degraded = True
        else:
            try:
                postgres.check_connection()
                components["postgres"] = "ok"
            except Exception:  # noqa: BLE001
                components["postgres"] = "degraded"
                has_degraded = True
    else:
        components["postgres"] = "skipped"

    if wants_redis:
        if redis_cache is None:
            components["redis"] = "degraded"
            has_degraded = True
        else:
            try:
                redis_cache.check_connection()
                components["redis"] = "ok"
            except Exception:  # noqa: BLE001
                components["redis"] = "degraded"
                has_degraded = True
    else:
        components["redis"] = "skipped"

    return ("degraded" if has_degraded else "ok"), components


def _require_admin(
    container: ServiceContainer,
    token: str | None,
    required_permission: str | None = None,
):
    if token is None or token.strip() == "":
        raise HTTPException(status_code=401, detail="管理者トークンが必要です。")

    try:
        return container.admin_service.require_admin(
            token,
            required_permission=required_permission,
        )
    except Exception as exc:  # noqa: BLE001
        raise _convert_error(exc) from exc


def create_app(config: AppConfig | None = None) -> FastAPI:
    app = FastAPI(title="Oracle Reading App API", version="0.2.0")
    container: ServiceContainer = build_service_container(config)
    app.state.container = container

    @app.get("/health", response_model=MessageResponse)
    def health() -> MessageResponse:
        return MessageResponse(message=f"稼働中: {now_jst().isoformat()}")

    @app.get("/health/ready", response_model=HealthReadyResponse)
    def health_ready() -> HealthReadyResponse:
        overall_status, components = _build_health_components(container)
        return HealthReadyResponse(
            overall_status=overall_status,
            checked_at=now_jst(),
            components=components,
        )

    # ---- auth ----
    @app.post("/auth/login", response_model=UserResponse)
    def login(req: AuthLoginRequest) -> UserResponse:
        user = container.auth_service.login_by_user_id(req.user_id)
        user = container.billing_service.refresh_subscription_status(user)
        _track_event(container, "app_open", user.user_id)
        _audit_action(
            container,
            actor_type="user",
            actor_id=user.user_id,
            action="auth.login",
            resource_type="auth",
            resource_id=user.user_id,
        )
        return _map_user(container, user)

    @app.post("/account/transfer-code", response_model=TransferCodeResponse)
    def issue_transfer_code(req: TransferCodeIssueRequest) -> TransferCodeResponse:
        """機種変更の引継ぎコードを発行する（発行し直すと前のコードは無効）。"""
        try:
            issued = container.auth_service.issue_transfer_code(req.user_id)
        except Exception as exc:  # noqa: BLE001
            raise _convert_error(exc) from exc
        _audit_action(
            container,
            actor_type="user",
            actor_id=req.user_id,
            action="account.transfer_code.issue",
            resource_type="account",
            resource_id=req.user_id,
        )
        return TransferCodeResponse(
            code=issued.code,
            formatted_code=container.auth_service.format_transfer_code(issued.code),
            expires_at=issued.expires_at,
        )

    @app.post("/account/transfer-code/redeem", response_model=UserResponse)
    def redeem_transfer_code(req: TransferCodeRedeemRequest) -> UserResponse:
        """引継ぎコードで、発行元のアカウントへ切り替える（コードは使い捨て）。"""
        try:
            user = container.auth_service.redeem_transfer_code(req.code)
        except Exception as exc:  # noqa: BLE001
            raise _convert_error(exc) from exc
        user = container.billing_service.refresh_subscription_status(user)
        _audit_action(
            container,
            actor_type="user",
            actor_id=user.user_id,
            action="account.transfer_code.redeem",
            resource_type="account",
            resource_id=user.user_id,
        )
        return _map_user(container, user)

    @app.post("/auth/apple", response_model=UserResponse)
    def login_with_apple(req: AuthProviderRequest) -> UserResponse:
        user = container.auth_service.login_with_provider(
            provider=AuthProvider.APPLE,
            provider_user_id=req.provider_user_id,
            email=req.email,
        )
        user = container.billing_service.refresh_subscription_status(user)
        _track_event(container, "app_open", user.user_id, {"provider": "apple"})
        _audit_action(
            container,
            actor_type="user",
            actor_id=user.user_id,
            action="auth.login.apple",
            resource_type="auth",
            resource_id=user.user_id,
            detail={"provider_user_id": req.provider_user_id},
        )
        return _map_user(container, user)

    @app.post("/auth/google", response_model=UserResponse)
    def login_with_google(req: AuthProviderRequest) -> UserResponse:
        user = container.auth_service.login_with_provider(
            provider=AuthProvider.GOOGLE,
            provider_user_id=req.provider_user_id,
            email=req.email,
        )
        user = container.billing_service.refresh_subscription_status(user)
        _track_event(container, "app_open", user.user_id, {"provider": "google"})
        _audit_action(
            container,
            actor_type="user",
            actor_id=user.user_id,
            action="auth.login.google",
            resource_type="auth",
            resource_id=user.user_id,
            detail={"provider_user_id": req.provider_user_id},
        )
        return _map_user(container, user)

    @app.get("/profile", response_model=ProfileResponse)
    def get_profile(user_id: str = Query(min_length=1)) -> ProfileResponse:
        profile = container.auth_service.get_profile(user_id)
        return ProfileResponse(
            user_id=profile.user_id,
            display_name=profile.display_name,
        )

    @app.put("/profile", response_model=ProfileResponse)
    def update_profile(req: ProfileUpdateRequest) -> ProfileResponse:
        try:
            profile = container.auth_service.update_profile(
                user_id=req.user_id,
                display_name=req.display_name,
            )
            _audit_action(
                container,
                actor_type="user",
                actor_id=req.user_id,
                action="profile.update",
                resource_type="profile",
                resource_id=req.user_id,
            )
            return ProfileResponse(
                user_id=profile.user_id,
                display_name=profile.display_name,
            )
        except Exception as exc:  # noqa: BLE001
            raise _convert_error(exc) from exc

    @app.post("/auth/logout", response_model=MessageResponse)
    def logout(req: AuthLogoutRequest) -> MessageResponse:
        container.auth_service.logout_by_user_id(req.user_id)
        _audit_action(
            container,
            actor_type="user",
            actor_id=req.user_id,
            action="auth.logout",
            resource_type="auth",
            resource_id=req.user_id,
        )
        return MessageResponse(message="ログアウトを受け付けました。")

    # ---- content ----
    @app.get("/reading/spreads", response_model=list[SpreadResponse])
    def list_spreads(user_id: str | None = None) -> list[SpreadResponse]:
        """スプレッド定義の一覧。

        `user_id` を渡すと、そのユーザーが実行できるか（プラン・チケット残数）を
        `available` / `unavailable_reason` に載せて返す。
        リーディング開始前に必要枚数と残数を提示するために使う。
        """
        engine = container.interpretation_engine
        billing = container.billing_service
        user = container.store.get_or_create_user(user_id) if user_id else None
        responses: list[SpreadResponse] = []
        for spread in sorted(
            engine.spreads(), key=lambda item: item.get("sort_order", 0)
        ):
            available = True
            reason: str | None = None
            if user is not None:
                if not billing.can_use_spread(user, spread):
                    available = False
                    reason = "このリーディングは有料プランで利用できます。"
                elif not billing.has_enough_tickets(user, spread):
                    available = False
                    reason = "チケット残高が不足しています。"
                elif _oracle_daily_limit_reached(container, user, spread):
                    # 本日の託宣は無料プランでも1日1回。開始してから弾くのではなく、
                    # 種別を選ぶ前に分かるようにする（start_session と同じ規則）。
                    available = False
                    reason = "本日の無料枠は使い切りました。"
            responses.append(
                SpreadResponse(
                    spread_id=spread["spread_id"],
                    name_ja=spread.get("name_ja", ""),
                    kind=spread.get("kind", ""),
                    card_count=int(spread.get("card_count") or 0),
                    min_cards=int(spread.get("min_cards") or 1),
                    max_cards=int(spread.get("max_cards") or 1),
                    purpose=spread.get("purpose", ""),
                    required_tickets=int(spread.get("required_tickets") or 0),
                    allowed_plans=list(spread.get("allowed_plans", [])),
                    sort_order=int(spread.get("sort_order") or 0),
                    available=available,
                    unavailable_reason=reason,
                )
            )
        return responses

    @app.get("/themes", response_model=list[ThemeResponse])
    def list_themes() -> list[ThemeResponse]:
        return [
            ThemeResponse(
                theme_id=theme.theme_id,
                name_ja=theme.name_ja,
                name_en=theme.name_en,
                name_zh=theme.name_zh,
            )
            for theme in container.content_service.list_themes()
        ]

    @app.get("/decks", response_model=list[DeckResponse])
    def list_decks() -> list[DeckResponse]:
        return [
            DeckResponse(
                deck_id=deck.deck_id,
                name_ja=deck.name_ja,
                sort_order=deck.sort_order,
                name_en=deck.name_en,
                name_zh=deck.name_zh,
            )
            for deck in container.content_service.list_decks()
        ]

    @app.get("/cards", response_model=list[CardResponse])
    def list_cards(
        deck_id: str | None = Query(default=None),
        q: str | None = Query(default=None),
    ) -> list[CardResponse]:
        cards = container.content_service.list_cards(deck_id=deck_id, query=q)
        return [
            CardResponse(
                card_id=card.card_id,
                deck_id=card.deck_id,
                name_ja=card.name_ja,
                keywords=card.keywords,
                name_en=card.name_en,
                keywords_en=card.keywords_en,
                name_zh=card.name_zh,
                keywords_zh=card.keywords_zh,
                reading=card.reading,
                attribute=card.attribute,
                element=card.element,
            )
            for card in cards
        ]

    @app.get("/products", response_model=list[ProductResponse])
    def list_products() -> list[ProductResponse]:
        products = container.content_service.list_products()
        return [
            ProductResponse(
                product_code=product.product_code,
                title=product.title,
                plan_type=product.plan_type.value,
                price_jpy=product.price_jpy,
                ticket_amount=product.ticket_amount,
                is_subscription=product.is_subscription,
            )
            for product in products
        ]

    @app.get("/announcements", response_model=list[AnnouncementResponse])
    def list_announcements() -> list[AnnouncementResponse]:
        return [_map_announcement(ann) for ann in container.content_service.list_announcements()]

    # ---- reading ----
    @app.post("/reading/start", response_model=StartReadingResponse)
    def reading_start(req: StartReadingRequest) -> StartReadingResponse:
        try:
            session = container.reading_service.start_session(
                user_id=req.user_id,
                theme_id=req.theme_id,
                deck_id=req.deck_id,
                draw_count=req.draw_count,
                spread_id=req.spread_id,
                question_text=req.question_text,
            )
            _track_event(
                container,
                "theme_selected",
                req.user_id,
                {"theme_id": req.theme_id, "deck_id": req.deck_id},
            )
            _track_event(container, "shuffle_started", req.user_id)
            return StartReadingResponse(
                session_id=session.session_id,
                status=session.status.value,
                started_at=session.started_at,
                draw_count=session.draw_count,
            )
        except Exception as exc:  # noqa: BLE001
            raise _convert_error(exc) from exc

    @app.post("/reading/complete-shuffle", response_model=PileStatusResponse)
    def complete_shuffle(req: CompleteShuffleRequest) -> PileStatusResponse:
        try:
            session = container.reading_service.complete_shuffle(
                session_id=req.session_id,
                idle_seconds=req.idle_seconds,
                finger_released=req.finger_released,
                swipe_distance=req.swipe_distance,
            )
            pile_sizes = {str(index): len(cards) for index, cards in session.piles.items()}
            return PileStatusResponse(
                session_id=session.session_id,
                status=session.status.value,
                pile_sizes=pile_sizes,
            )
        except Exception as exc:  # noqa: BLE001
            raise _convert_error(exc) from exc

    @app.post("/reading/select-pile", response_model=PileStatusResponse)
    def select_pile(req: SelectPileRequest) -> PileStatusResponse:
        try:
            session = container.reading_service.select_pile(
                session_id=req.session_id,
                pile_index=req.pile_index,
            )
            _track_event(
                container,
                "pile_selected",
                session.user_id,
                {"pile_index": str(req.pile_index)},
            )
            pile_sizes = {str(index): len(cards) for index, cards in session.piles.items()}
            return PileStatusResponse(
                session_id=session.session_id,
                status=session.status.value,
                pile_sizes=pile_sizes,
            )
        except Exception as exc:  # noqa: BLE001
            raise _convert_error(exc) from exc

    @app.post("/reading/select-card", response_model=ReadingResultResponse | None)
    def select_card(req: SelectCardRequest) -> ReadingResultResponse | None:
        # 複数枚リーディングでは必要枚数に達するまで None（204相当の空応答）を返す。
        try:
            result = container.reading_service.select_card(
                session_id=req.session_id,
                card_index=req.card_index,
            )
            if result is None:
                return None
            _track_event(
                container,
                "card_selected",
                result.user_id,
                {"card_id": result.card_id},
            )
            _track_event(container, "reading_completed", result.user_id)
            return _map_result(result)
        except Exception as exc:  # noqa: BLE001
            raise _convert_error(exc) from exc

    @app.get("/reading/{session_id}", response_model=ReadingResultResponse)
    def get_reading_result(session_id: str) -> ReadingResultResponse:
        try:
            result = container.reading_service.get_result(session_id)
            return _map_result(result)
        except Exception as exc:  # noqa: BLE001
            raise _convert_error(exc) from exc

    @app.post("/reading/{session_id}/copy", response_model=ReadingResultResponse)
    def copy_result(session_id: str) -> ReadingResultResponse:
        try:
            result = container.reading_service.mark_copied(session_id)
            _track_event(container, "result_copied", result.user_id)
            return _map_result(result)
        except Exception as exc:  # noqa: BLE001
            raise _convert_error(exc) from exc

    @app.post("/reading/{session_id}/save-history", response_model=MessageResponse)
    def save_history(session_id: str, req: SaveHistoryRequest) -> MessageResponse:
        try:
            item = container.reading_service.save_history(
                user_id=req.user_id,
                session_id=session_id,
            )
            return MessageResponse(message=f"履歴を保存しました: {item.history_id}")
        except Exception as exc:  # noqa: BLE001
            raise _convert_error(exc) from exc

    @app.get("/history", response_model=list[HistoryItemResponse])
    def list_history(user_id: str = Query(min_length=1)) -> list[HistoryItemResponse]:
        items = container.reading_service.list_history(user_id=user_id)
        _track_event(container, "history_viewed", user_id)
        return [
            HistoryItemResponse(
                history_id=item.history_id,
                session_id=item.session_id,
                created_at=item.created_at,
                theme_id=item.theme_id,
                deck_id=item.deck_id,
                card_id=item.card_id,
                summary=item.summary,
                full_text=item.full_text,
                plan_at_creation=item.plan_at_creation.value,
            )
            for item in items
        ]

    @app.delete("/history/{history_id}", response_model=MessageResponse)
    def delete_history(
        history_id: str,
        user_id: str = Query(min_length=1),
    ) -> MessageResponse:
        item = container.store.get_history_item(history_id)
        if item is None:
            raise HTTPException(status_code=404, detail="履歴が存在しません。")
        if item.user_id != user_id:
            raise HTTPException(
                status_code=403, detail="他ユーザーの履歴は削除できません。"
            )
        container.store.delete_history_item(user_id=user_id, history_id=history_id)
        _audit_action(
            container,
            actor_type="user",
            actor_id=user_id,
            action="history.delete",
            resource_type="history",
            resource_id=history_id,
        )
        return MessageResponse(message=f"履歴を削除しました: {history_id}")

    # ---- billing ----
    @app.post("/purchase/verify", response_model=PurchaseVerifyResponse)
    def purchase_verify(req: PurchaseVerifyRequest) -> PurchaseVerifyResponse:
        try:
            result = container.billing_service.verify_purchase(
                user_id=req.user_id,
                product_code=req.product_code,
                receipt_id=req.receipt_id,
            )
            event_name = (
                "subscription_started"
                if req.product_code == container.config.pricing.subscription_product_code
                else "ticket_purchased"
            )
            _track_event(
                container,
                event_name,
                req.user_id,
                {"product_code": req.product_code},
            )
            _audit_action(
                container,
                actor_type="user",
                actor_id=req.user_id,
                action="billing.purchase_verify",
                resource_type="purchase",
                resource_id=req.product_code,
                detail={"receipt_id": req.receipt_id},
            )
            return PurchaseVerifyResponse(
                accepted=result.accepted,
                user_id=result.user_id,
                plan=result.plan.value,
                tickets=result.tickets,
                message=result.message,
            )
        except Exception as exc:  # noqa: BLE001
            raise _convert_error(exc) from exc

    @app.post("/purchase/restore", response_model=PurchaseVerifyResponse)
    def purchase_restore(req: PurchaseRestoreRequest) -> PurchaseVerifyResponse:
        try:
            result = container.billing_service.restore_purchase(
                user_id=req.user_id,
                product_code=req.product_code,
                restore_receipt_id=req.restore_receipt_id,
            )
            event_name = (
                "subscription_started"
                if req.product_code == container.config.pricing.subscription_product_code
                else "ticket_purchased"
            )
            _track_event(
                container,
                event_name,
                req.user_id,
                {"product_code": req.product_code, "restored": "true"},
            )
            _audit_action(
                container,
                actor_type="user",
                actor_id=req.user_id,
                action="billing.purchase_restore",
                resource_type="purchase",
                resource_id=req.product_code,
                detail={"restore_receipt_id": req.restore_receipt_id},
            )
            return PurchaseVerifyResponse(
                accepted=result.accepted,
                user_id=result.user_id,
                plan=result.plan.value,
                tickets=result.tickets,
                message=result.message,
            )
        except Exception as exc:  # noqa: BLE001
            raise _convert_error(exc) from exc

    # ---- notification / inquiries ----
    @app.post("/notifications/token", response_model=MessageResponse)
    def register_token(req: NotificationTokenRequest) -> MessageResponse:
        container.notification_service.register_device_token(
            user_id=req.user_id,
            token=req.token,
        )
        return MessageResponse(message="通知トークンを登録しました。")

    @app.post("/inquiries", response_model=MessageResponse)
    def submit_inquiry(req: InquiryRequest) -> MessageResponse:
        try:
            inquiry = container.inquiry_service.submit(
                user_id=req.user_id,
                category=req.category,
                body=req.body,
                email=req.email,
            )
            return MessageResponse(message=f"問い合わせを受け付けました: {inquiry.inquiry_id}")
        except Exception as exc:  # noqa: BLE001
            raise _convert_error(exc) from exc

    # ---- links ----
    @app.get("/links/shop", response_model=list[ExternalLinkResponse])
    def list_shop_links() -> list[ExternalLinkResponse]:
        links = container.link_service.list_shop_links()
        return [
            ExternalLinkResponse(
                link_id=link.link_id,
                category=link.category,
                title=link.title,
                url=link.url,
            )
            for link in links
        ]

    @app.get("/links/consultation", response_model=list[ExternalLinkResponse])
    def list_consultation_links() -> list[ExternalLinkResponse]:
        links = container.link_service.list_consultation_links()
        return [
            ExternalLinkResponse(
                link_id=link.link_id,
                category=link.category,
                title=link.title,
                url=link.url,
            )
            for link in links
        ]

    @app.get("/links/live", response_model=list[ExternalLinkResponse])
    def list_live_links() -> list[ExternalLinkResponse]:
        links = container.link_service.list_live_links()
        return [
            ExternalLinkResponse(
                link_id=link.link_id,
                category=link.category,
                title=link.title,
                url=link.url,
            )
            for link in links
        ]

    @app.get("/links/live-events", response_model=list[LiveEventResponse])
    def list_live_events() -> list[LiveEventResponse]:
        return [
            LiveEventResponse(
                live_event_id=event.live_event_id,
                title=event.title,
                start_at=event.start_at,
                archive_url=event.archive_url,
            )
            for event in container.link_service.list_live_events()
        ]

    # ---- analytics ----
    @app.post("/analytics/events", response_model=AnalyticsEventResponse)
    def create_analytics_event(req: AnalyticsEventRequest) -> AnalyticsEventResponse:
        event = container.analytics_service.track_event(
            event_name=req.event_name,
            user_id=req.user_id,
            properties=req.properties,
        )
        return AnalyticsEventResponse(
            event_id=event.event_id,
            event_name=event.event_name,
            user_id=event.user_id,
            occurred_at=event.occurred_at,
            properties=event.properties,
        )

    # ---- admin ----
    @app.post("/admin/login", response_model=AdminLoginResponse)
    def admin_login(req: AdminLoginRequest) -> AdminLoginResponse:
        try:
            admin_user, session = container.admin_service.login(req.email, req.password)
            _audit_action(
                container,
                actor_type="admin",
                actor_id=admin_user.admin_user_id,
                action="admin.login",
                resource_type="admin_session",
                resource_id=session.token,
                detail={"email": req.email},
            )
            return AdminLoginResponse(
                token=session.token,
                admin_user_id=admin_user.admin_user_id,
                role_id=admin_user.role_id,
            )
        except Exception as exc:  # noqa: BLE001
            raise _convert_error(exc) from exc

    @app.get("/admin/dashboard", response_model=AdminDashboardResponse)
    def admin_dashboard(
        x_admin_token: str | None = Header(default=None, alias="X-Admin-Token"),
    ) -> AdminDashboardResponse:
        _require_admin(container, x_admin_token, required_permission="dashboard:view")
        dashboard = container.admin_service.get_dashboard()
        return AdminDashboardResponse(**dashboard)

    @app.get("/admin/users", response_model=list[UserSummaryResponse])
    def admin_users(
        x_admin_token: str | None = Header(default=None, alias="X-Admin-Token"),
    ) -> list[UserSummaryResponse]:
        _require_admin(container, x_admin_token, required_permission="users:view")
        return [
            UserSummaryResponse(
                user_id=user.user_id,
                plan=user.plan.value,
                tickets=user.tickets,
                created_at=user.created_at,
            )
            for user in container.store.list_users()
        ]

    @app.get("/admin/inquiries", response_model=list[InquiryResponse])
    def admin_inquiries(
        x_admin_token: str | None = Header(default=None, alias="X-Admin-Token"),
    ) -> list[InquiryResponse]:
        _require_admin(container, x_admin_token, required_permission="inquiries:view")
        return [
            InquiryResponse(
                inquiry_id=inquiry.inquiry_id,
                user_id=inquiry.user_id,
                category=inquiry.category,
                body=inquiry.body,
                email=inquiry.email,
                created_at=inquiry.created_at,
            )
            for inquiry in container.store.list_inquiries()
        ]

    @app.get("/admin/announcements", response_model=list[AnnouncementResponse])
    def admin_announcements(
        x_admin_token: str | None = Header(default=None, alias="X-Admin-Token"),
    ) -> list[AnnouncementResponse]:
        _require_admin(container, x_admin_token, required_permission="announcements:manage")
        return [_map_announcement(ann) for ann in container.store.list_all_announcements()]

    @app.post("/admin/announcements", response_model=AnnouncementResponse)
    def admin_create_announcement(
        req: AnnouncementCreateRequest,
        x_admin_token: str | None = Header(default=None, alias="X-Admin-Token"),
    ) -> AnnouncementResponse:
        admin_user = _require_admin(
            container, x_admin_token, required_permission="announcements:manage"
        )
        try:
            created = container.admin_service.create_announcement(
                title=req.title,
                body=req.body,
                category=req.category,
                start_at=req.start_at,
                end_at=req.end_at,
                is_important=req.is_important,
                link_url=req.link_url,
            )
            _audit_action(
                container,
                actor_type="admin",
                actor_id=admin_user.admin_user_id,
                action="admin.announcement.create",
                resource_type="announcement",
                resource_id=created.announcement_id,
                detail={"category": req.category},
            )
            return _map_announcement(created)
        except Exception as exc:  # noqa: BLE001
            raise _convert_error(exc) from exc

    @app.get("/admin/themes", response_model=list[ThemeAdminResponse])
    def admin_themes(
        x_admin_token: str | None = Header(default=None, alias="X-Admin-Token"),
    ) -> list[ThemeAdminResponse]:
        _require_admin(container, x_admin_token, required_permission="themes:manage")
        return [
            ThemeAdminResponse(
                theme_id=theme.theme_id,
                name_ja=theme.name_ja,
                is_visible=theme.is_visible,
            )
            for theme in container.store.list_all_themes()
        ]

    @app.get("/admin/decks", response_model=list[DeckAdminResponse])
    def admin_decks(
        x_admin_token: str | None = Header(default=None, alias="X-Admin-Token"),
    ) -> list[DeckAdminResponse]:
        _require_admin(container, x_admin_token, required_permission="decks:manage")
        return [
            DeckAdminResponse(
                deck_id=deck.deck_id,
                name_ja=deck.name_ja,
                sort_order=deck.sort_order,
                is_published=deck.is_published,
            )
            for deck in container.store.list_all_decks()
        ]

    @app.get("/admin/admin-users", response_model=list[AdminUserResponse])
    def admin_admin_users(
        x_admin_token: str | None = Header(default=None, alias="X-Admin-Token"),
    ) -> list[AdminUserResponse]:
        _require_admin(container, x_admin_token, required_permission="audit:view")
        return [
            AdminUserResponse(
                admin_user_id=admin_user.admin_user_id,
                email=admin_user.email,
                role_id=admin_user.role_id,
                is_active=admin_user.is_active,
            )
            for admin_user in container.store.list_admin_users()
        ]

    @app.post("/admin/campaigns", response_model=PushCampaignResponse)
    def admin_create_campaign(
        req: PushCampaignCreateRequest,
        x_admin_token: str | None = Header(default=None, alias="X-Admin-Token"),
    ) -> PushCampaignResponse:
        admin_user = _require_admin(
            container, x_admin_token, required_permission="notifications:manage"
        )
        try:
            campaign = container.admin_service.create_push_campaign(
                title=req.title,
                body=req.body,
                category=req.category,
                target_segment=req.target_segment,
                scheduled_at=req.scheduled_at,
                is_ab_test=req.is_ab_test,
            )
            _audit_action(
                container,
                actor_type="admin",
                actor_id=admin_user.admin_user_id,
                action="admin.campaign.create",
                resource_type="push_campaign",
                resource_id=campaign.campaign_id,
                detail={"category": req.category, "target_segment": req.target_segment},
            )
            return _map_campaign(campaign)
        except Exception as exc:  # noqa: BLE001
            raise _convert_error(exc) from exc

    @app.get("/admin/campaigns", response_model=list[PushCampaignResponse])
    def admin_list_campaigns(
        x_admin_token: str | None = Header(default=None, alias="X-Admin-Token"),
    ) -> list[PushCampaignResponse]:
        _require_admin(container, x_admin_token, required_permission="notifications:manage")
        return [_map_campaign(campaign) for campaign in container.admin_service.list_push_campaigns()]

    @app.post("/admin/campaigns/{campaign_id}/dispatch", response_model=PushCampaignResponse)
    def admin_dispatch_campaign(
        campaign_id: str,
        x_admin_token: str | None = Header(default=None, alias="X-Admin-Token"),
    ) -> PushCampaignResponse:
        admin_user = _require_admin(
            container, x_admin_token, required_permission="notifications:manage"
        )
        try:
            campaign, report = container.admin_service.dispatch_push_campaign(campaign_id)
            _audit_action(
                container,
                actor_type="admin",
                actor_id=admin_user.admin_user_id,
                action="admin.campaign.dispatch",
                resource_type="push_campaign",
                resource_id=campaign.campaign_id,
                detail={
                    "mode": report.mode,
                    "sent_count": str(report.sent_count),
                    "target_count": str(report.target_count),
                },
            )
            return _map_campaign(campaign, dispatch_result=report.message)
        except Exception as exc:  # noqa: BLE001
            raise _convert_error(exc) from exc

    @app.get("/admin/audit-logs", response_model=list[AuditLogResponse])
    def admin_audit_logs(
        limit: int = Query(default=200, ge=1, le=1000),
        x_admin_token: str | None = Header(default=None, alias="X-Admin-Token"),
    ) -> list[AuditLogResponse]:
        _require_admin(container, x_admin_token, required_permission="audit:view")
        return [
            AuditLogResponse(
                audit_id=log.audit_id,
                actor_type=log.actor_type,
                actor_id=log.actor_id,
                action=log.action,
                resource_type=log.resource_type,
                resource_id=log.resource_id,
                detail=log.detail,
                occurred_at=log.occurred_at,
            )
            for log in container.store.list_audit_logs(limit=limit)
        ]

    @app.get("/admin/analytics/kpi", response_model=KpiSnapshotResponse)
    def admin_kpi_snapshot(
        x_admin_token: str | None = Header(default=None, alias="X-Admin-Token"),
    ) -> KpiSnapshotResponse:
        _require_admin(container, x_admin_token, required_permission="dashboard:view")
        snapshot = container.analytics_service.get_kpi_snapshot()
        return KpiSnapshotResponse(values=snapshot)

    return app
