from __future__ import annotations

from dataclasses import dataclass

from .config import AppConfig
from .content_loader import load_card_content
from .logging_utils import get_logger
from .services import (
    AdminService,
    AnalyticsService,
    AppleStoreKitVerifier,
    AuthService,
    BillingService,
    ContentService,
    FcmV1PushSender,
    GooglePlayVerifier,
    InquiryService,
    InterpretationEngine,
    LinkService,
    LocalFormalVerifier,
    NoopPushSender,
    NotificationService,
    PushSender,
    ReadingService,
    ReceiptVerifier,
    StoreApiReceiptVerifier,
)
from .persistence import HybridStore, PostgresPersistence, RedisCache
from .store import InMemoryStore


@dataclass(slots=True)
class ServiceContainer:
    config: AppConfig
    store: InMemoryStore
    auth_service: AuthService
    content_service: ContentService
    billing_service: BillingService
    reading_service: ReadingService
    # スプレッド定義（マスタ）の参照用。APIの一覧提示が使う。
    interpretation_engine: InterpretationEngine
    notification_service: NotificationService
    inquiry_service: InquiryService
    analytics_service: AnalyticsService
    link_service: LinkService
    admin_service: AdminService


def _build_store(config: AppConfig) -> InMemoryStore:
    logger = get_logger("StoreBootstrap")
    backend = config.persistence_backend.strip().lower()
    runtime_mode = config.runtime_mode.strip().lower()

    if runtime_mode in {"staging", "production"} and backend == "inmemory":
        raise RuntimeError(
            "staging/production では ORACLE_PERSISTENCE_BACKEND=inmemory は利用できません。"
        )

    wants_postgres = backend in {"postgres", "postgresql", "hybrid"} or config.postgres.enabled
    wants_redis = backend in {"redis", "hybrid"} or config.redis.enabled

    if not wants_postgres and not wants_redis:
        logger.info("InMemoryStore modeで起動します。")
        return InMemoryStore(config)

    postgres: PostgresPersistence | None = None
    redis_cache: RedisCache | None = None

    try:
        if wants_postgres:
            postgres = PostgresPersistence(
                dsn=config.postgres.dsn,
                echo=config.postgres.echo,
            )
            postgres.initialize_schema()
            postgres.check_connection()
            logger.info("PostgreSQL接続を有効化しました。")

        if wants_redis:
            redis_cache = RedisCache(
                url=config.redis.url,
                prefix=config.redis.prefix,
                default_ttl_seconds=config.redis.ttl_seconds,
            )
            redis_cache.check_connection()
            logger.info("Redis接続を有効化しました。")

        logger.info("HybridStore modeで起動します。")
        return HybridStore(config, postgres=postgres, redis_cache=redis_cache)

    except Exception as exc:  # noqa: BLE001
        if runtime_mode in {"staging", "production"}:
            logger.error("永続化層の初期化に失敗しました。staging/productionではフォールバックしません: %s", exc)
            if postgres is not None:
                postgres.close()
            if redis_cache is not None:
                redis_cache.close()
            raise

        logger.warning("永続化層の初期化に失敗したため InMemoryStore にフォールバックします: %s", exc)
        if postgres is not None:
            postgres.close()
        if redis_cache is not None:
            redis_cache.close()
        return InMemoryStore(config)


def _build_receipt_verifier(config: AppConfig) -> ReceiptVerifier:
    logger = get_logger("ReceiptVerifierBootstrap")
    mode = config.receipt_verification.mode.strip().lower()
    runtime_mode = config.runtime_mode.strip().lower()

    if mode == "local":
        if runtime_mode == "production":
            raise RuntimeError(
                "production では ORACLE_RECEIPT_VERIFICATION_MODE=local は利用できません。"
            )
        if runtime_mode == "staging":
            logger.warning(
                "staging でレシート検証が local モードです。ストア審査前に store_api へ切り替えてください。"
            )
        return LocalFormalVerifier()

    if mode == "store_api":
        apple = AppleStoreKitVerifier(
            issuer_id=config.receipt_verification.apple_issuer_id,
            key_id=config.receipt_verification.apple_key_id,
            private_key=config.receipt_verification.apple_private_key,
        )
        google = GooglePlayVerifier(
            package_name=config.receipt_verification.google_package_name,
            service_account_json=config.receipt_verification.google_service_account_json,
        )
        logger.info("レシート検証を store_api モードで構成しました。")
        return StoreApiReceiptVerifier(apple=apple, google=google)

    raise RuntimeError(f"未対応のレシート検証モードです: {mode}")


def _build_push_sender(config: AppConfig) -> PushSender:
    logger = get_logger("PushSenderBootstrap")
    mode = config.push_delivery.mode.strip().lower()
    runtime_mode = config.runtime_mode.strip().lower()

    if mode == "noop":
        if runtime_mode in {"staging", "production"}:
            logger.warning(
                "%s でプッシュ配信が noop モードです。実配信には fcm モードへの切り替えが必要です。",
                runtime_mode,
            )
        return NoopPushSender()

    if mode == "fcm":
        logger.info("プッシュ配信を fcm モードで構成しました。")
        return FcmV1PushSender(
            project_id=config.push_delivery.fcm_project_id,
            service_account_json=config.push_delivery.fcm_service_account_json,
        )

    raise RuntimeError(f"未対応のプッシュ配信モードです: {mode}")


def build_service_container(config: AppConfig | None = None) -> ServiceContainer:
    resolved_config = config or AppConfig()
    store = _build_store(resolved_config)
    receipt_verifier = _build_receipt_verifier(resolved_config)
    push_sender = _build_push_sender(resolved_config)

    auth_service = AuthService(store=store, config=resolved_config)
    interpretation_engine = InterpretationEngine(load_card_content())
    billing_service = BillingService(
        store=store,
        config=resolved_config,
        receipt_verifier=receipt_verifier,
    )
    reading_service = ReadingService(
        store=store,
        config=resolved_config,
        billing_service=billing_service,
        interpretation_engine=interpretation_engine,
    )
    content_service = ContentService(store=store)
    notification_service = NotificationService(store=store, push_sender=push_sender)
    inquiry_service = InquiryService(store=store, config=resolved_config)
    analytics_service = AnalyticsService(store=store, config=resolved_config)
    link_service = LinkService(store=store)
    admin_service = AdminService(
        store=store,
        analytics_service=analytics_service,
        notification_service=notification_service,
    )

    return ServiceContainer(
        config=resolved_config,
        store=store,
        auth_service=auth_service,
        content_service=content_service,
        billing_service=billing_service,
        reading_service=reading_service,
        interpretation_engine=interpretation_engine,
        notification_service=notification_service,
        inquiry_service=inquiry_service,
        analytics_service=analytics_service,
        link_service=link_service,
        admin_service=admin_service,
    )
