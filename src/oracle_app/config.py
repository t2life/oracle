from __future__ import annotations

import os
from dataclasses import dataclass, field
from typing import Mapping


def _env_bool(name: str, default: bool) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


def _env_int(name: str, default: int) -> int:
    raw = os.getenv(name)
    if raw is None:
        return default
    try:
        return int(raw)
    except ValueError:
        return default


@dataclass(frozen=True)
class ShuffleRules:
    idle_seconds_min: float = 1.0
    idle_seconds_max: float = 2.0
    min_swipe_distance: float = 120.0


@dataclass(frozen=True)
class HistoryRules:
    free_visible_limit: int = 3


@dataclass(frozen=True)
class ProfileRules:
    """ニックネーム（display_name）の検証規則。

    forbidden_words は将来のSNS共有・コミュニティ機能に備えたNGワード
    バリデーションのプレースホルダ（2026-09-06指摘事項2）。既定は空＝無効。
    運用開始時はここへ語を追加するだけで PUT /profile が拒否するようになる。
    """

    display_name_min: int = 1
    display_name_max: int = 20
    forbidden_words: tuple[str, ...] = ()


@dataclass(frozen=True)
class InquiryRules:
    categories: tuple[str, ...] = (
        "general",
        "billing",
        "bug",
        "request",
        "other",
    )


@dataclass(frozen=True)
class PricingCatalog:
    ticket_products: Mapping[str, int] = field(
        default_factory=lambda: {
            "ticket_trial_30": 30,
            "ticket_20": 20,
            "ticket_50": 50,
            "ticket_120": 120,
        }
    )
    subscription_product_code: str = "subscription_monthly_500"
    subscription_trial_days: int = 7


@dataclass(frozen=True)
class ExternalLinkCatalog:
    shop_links: tuple[str, ...] = (
        "https://example.com/shop/omamori",
        "https://example.com/shop/charm",
        "https://example.com/shop/oracle-deck",
    )
    consultation_links: tuple[str, ...] = (
        "https://example.com/consultation/online",
        "https://example.com/consultation/mail",
    )
    live_links: tuple[str, ...] = (
        "https://example.com/live/schedule",
        "https://example.com/live/archive",
    )


@dataclass(frozen=True)
class NotificationRules:
    categories: tuple[str, ...] = (
        "今日の宣託リマインド",
        "連続利用促進通知",
        "未完了セッション再開通知",
        "新デッキ公開通知",
        "サブスク限定宣託通知",
        "キャンペーン通知",
        "ショップ新商品通知",
        "鑑定受付通知",
        "VTuber配信開始通知",
        "重要なお知らせ",
    )


@dataclass(frozen=True)
class AnalyticsRules:
    required_events: tuple[str, ...] = (
        "app_open",
        "onboarding_complete",
        "theme_selected",
        "shuffle_started",
        "pile_selected",
        "card_selected",
        "reading_completed",
        "result_copied",
        "history_viewed",
        "paywall_viewed",
        "ticket_purchased",
        "subscription_started",
        "announcement_opened",
        "shop_link_clicked",
        "consultation_link_clicked",
        "live_room_opened",
    )


@dataclass(frozen=True)
class AdminBootstrapConfig:
    default_admin_email: str = "admin@example.com"
    default_admin_password: str = "ChangeMe123!"
    default_role_id: str = "super_admin"


@dataclass(frozen=True)
class ReceiptVerificationConfig:
    mode: str = field(
        default_factory=lambda: os.getenv("ORACLE_RECEIPT_VERIFICATION_MODE", "local")
    )
    apple_issuer_id: str = field(default_factory=lambda: os.getenv("ORACLE_APPLE_ISSUER_ID", ""))
    apple_key_id: str = field(default_factory=lambda: os.getenv("ORACLE_APPLE_KEY_ID", ""))
    apple_private_key: str = field(
        default_factory=lambda: os.getenv("ORACLE_APPLE_PRIVATE_KEY", "")
    )
    google_package_name: str = field(
        default_factory=lambda: os.getenv("ORACLE_GOOGLE_PACKAGE_NAME", "")
    )
    google_service_account_json: str = field(
        default_factory=lambda: os.getenv("ORACLE_GOOGLE_SERVICE_ACCOUNT_JSON", "")
    )


@dataclass(frozen=True)
class PushDeliveryConfig:
    mode: str = field(default_factory=lambda: os.getenv("ORACLE_PUSH_DELIVERY_MODE", "noop"))
    fcm_project_id: str = field(default_factory=lambda: os.getenv("ORACLE_FCM_PROJECT_ID", ""))
    fcm_service_account_json: str = field(
        default_factory=lambda: os.getenv("ORACLE_FCM_SERVICE_ACCOUNT_JSON", "")
    )


@dataclass(frozen=True)
class PostgresConfig:
    enabled: bool = field(default_factory=lambda: _env_bool("ORACLE_POSTGRES_ENABLED", False))
    dsn: str = field(
        default_factory=lambda: os.getenv(
            "ORACLE_POSTGRES_DSN",
            "postgresql+psycopg://oracle:oracle@localhost:5432/oracle_app",
        )
    )
    echo: bool = field(default_factory=lambda: _env_bool("ORACLE_POSTGRES_ECHO", False))


@dataclass(frozen=True)
class RedisConfig:
    enabled: bool = field(default_factory=lambda: _env_bool("ORACLE_REDIS_ENABLED", False))
    url: str = field(default_factory=lambda: os.getenv("ORACLE_REDIS_URL", "redis://localhost:6379/0"))
    prefix: str = field(default_factory=lambda: os.getenv("ORACLE_REDIS_PREFIX", "oracle:"))
    ttl_seconds: int = field(default_factory=lambda: _env_int("ORACLE_REDIS_TTL_SECONDS", 600))


@dataclass(frozen=True)
class AppConfig:
    runtime_mode: str = field(default_factory=lambda: os.getenv("ORACLE_RUNTIME_MODE", "local"))
    timezone: str = "Asia/Tokyo"
    logger_level: str = "DEBUG"
    free_daily_draw_limit: int = 1
    # プロダクトオーナー確定の6軸（2026-08-31承認・宣言順=表示順）
    default_theme_ids: tuple[str, ...] = (
        "subconscious",
        "higher_self",
        "love",
        "money",
        "work",
        "health",
    )
    # 企画書時代の旧テーマ。履歴・解釈シードの参照整合のため非表示で温存する
    legacy_hidden_theme_ids: tuple[str, ...] = (
        "relationships",
        "soul",
        "awakening",
        "karma",
        "past_life",
    )
    default_deck_ids: tuple[str, ...] = (
        "japanese_mythology",
        "ryujin",
        "blythe",
    )
    card_counts_by_deck: Mapping[str, int] = field(
        default_factory=lambda: {
            "japanese_mythology": 44,
            "ryujin": 32,
            "blythe": 32,
        }
    )
    shuffle: ShuffleRules = field(default_factory=ShuffleRules)
    history: HistoryRules = field(default_factory=HistoryRules)
    profiles: ProfileRules = field(default_factory=ProfileRules)
    inquiries: InquiryRules = field(default_factory=InquiryRules)
    pricing: PricingCatalog = field(default_factory=PricingCatalog)
    links: ExternalLinkCatalog = field(default_factory=ExternalLinkCatalog)
    notifications: NotificationRules = field(default_factory=NotificationRules)
    analytics: AnalyticsRules = field(default_factory=AnalyticsRules)
    admin: AdminBootstrapConfig = field(default_factory=AdminBootstrapConfig)
    receipt_verification: ReceiptVerificationConfig = field(
        default_factory=ReceiptVerificationConfig
    )
    push_delivery: PushDeliveryConfig = field(default_factory=PushDeliveryConfig)
    persistence_backend: str = field(default_factory=lambda: os.getenv("ORACLE_PERSISTENCE_BACKEND", "inmemory"))
    postgres: PostgresConfig = field(default_factory=PostgresConfig)
    redis: RedisConfig = field(default_factory=RedisConfig)
