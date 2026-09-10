from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum

from .time_utils import now_jst


class PlanType(str, Enum):
    GUEST = "guest"
    FREE = "free"
    TICKET = "ticket"
    SUBSCRIPTION = "subscription"
    ADMIN = "admin"


class SessionStatus(str, Enum):
    STARTED = "started"
    SHUFFLED = "shuffled"
    PILE_SELECTED = "pile_selected"
    CARD_OPENED = "card_opened"
    COMPLETED = "completed"


class AuthProvider(str, Enum):
    EMAIL = "email"
    APPLE = "apple"
    GOOGLE = "google"


class CampaignStatus(str, Enum):
    SCHEDULED = "scheduled"
    DISPATCHED = "dispatched"
    CANCELED = "canceled"


class CampaignChannel(str, Enum):
    PUSH = "push"


@dataclass(slots=True)
class User:
    user_id: str
    plan: PlanType = PlanType.FREE
    tickets: int = 0
    subscription_expires_at: datetime | None = None
    created_at: datetime = field(default_factory=now_jst)
    updated_at: datetime = field(default_factory=now_jst)
    visit_count: int = 0


@dataclass(slots=True)
class Profile:
    user_id: str
    display_name: str
    locale: str = "ja-JP"
    created_at: datetime = field(default_factory=now_jst)
    updated_at: datetime = field(default_factory=now_jst)


@dataclass(slots=True)
class AuthAccount:
    auth_account_id: str
    user_id: str
    provider: AuthProvider
    provider_user_id: str
    email: str | None
    created_at: datetime = field(default_factory=now_jst)


@dataclass(slots=True)
class Theme:
    theme_id: str
    name_ja: str
    is_visible: bool = True
    name_en: str = ""
    name_zh: str = ""


@dataclass(slots=True)
class Deck:
    deck_id: str
    name_ja: str
    is_published: bool = True
    sort_order: int = 0
    name_en: str = ""
    name_zh: str = ""


@dataclass(slots=True)
class Card:
    card_id: str
    deck_id: str
    name_ja: str
    keywords: list[str]
    default_meaning: str
    meanings_by_theme: dict[str, str] = field(default_factory=dict)
    name_en: str = ""
    keywords_en: list[str] = field(default_factory=list)
    default_meaning_en: str = ""
    meanings_by_theme_en: dict[str, str] = field(default_factory=dict)
    name_zh: str = ""
    keywords_zh: list[str] = field(default_factory=list)
    default_meaning_zh: str = ""
    meanings_by_theme_zh: dict[str, str] = field(default_factory=dict)
    # 2026-09-10 承認: カード情報として神名のルビ・属性分類・エレメントを持つ。
    # 出所は 44柱.xlsx の「44柱一覧」（読み／属性分類／エレメント列）。
    # DB非搭載デッキでは空のまま＝画面側は空なら描画しない。
    reading: str = ""
    attribute: str = ""
    element: str = ""


@dataclass(slots=True)
class TransferCode:
    """機種変更の引継ぎコード。

    発行元アカウント（user_id）を1回だけ新しい端末へ引き渡すための使い捨ての鍵。
    使用済み（used_at あり）または期限切れのコードは受け付けない。
    """

    code: str
    user_id: str
    issued_at: datetime
    expires_at: datetime
    used_at: datetime | None = None


@dataclass(slots=True)
class ReadingSession:
    session_id: str
    user_id: str
    theme_id: str
    deck_id: str
    draw_count: int
    started_at: datetime
    status: SessionStatus = SessionStatus.STARTED
    shuffled_at: datetime | None = None
    chosen_pile: int | None = None
    selected_card_id: str | None = None
    precomputed_card_ids: list[str] = field(default_factory=list)
    piles: dict[int, list[str]] = field(default_factory=dict)
    # 2026-09-10 リーディング拡張。既定は本日の託宣（1枚・相談内容なし）。
    spread_id: str = "daily"
    question_text: str = ""
    # 複数枚リーディングで確定した順のカード。1枚目は selected_card_id と一致する。
    selected_card_ids: list[str] = field(default_factory=list)


@dataclass(slots=True)
class ResultCard:
    """複数枚リーディングの1枚ぶん（位置つき）。"""

    card_id: str
    card_name: str
    keywords: list[str]
    position_index: int
    position_name: str
    position_meaning: str
    # 神名のルビ・属性分類・エレメント（カード情報として結果画面に出す）
    reading: str = ""
    attribute: str = ""
    element: str = ""


@dataclass(slots=True)
class ReadingResult:
    session_id: str
    user_id: str
    theme_id: str
    deck_id: str
    card_id: str
    card_name: str
    keywords: list[str]
    interpretation_text: str
    caution_text: str | None
    created_at: datetime
    copied: bool = False
    # 多言語（英語・簡体字中国語）フィールド。永続化層（Postgres）は日本語のみ保存するため、
    # 再水和後は既定値（空）となる（現行の保存スキーマ互換を維持）。
    card_name_en: str = ""
    keywords_en: list[str] = field(default_factory=list)
    interpretation_text_en: str = ""
    caution_text_en: str | None = None
    card_name_zh: str = ""
    keywords_zh: list[str] = field(default_factory=list)
    interpretation_text_zh: str = ""
    caution_text_zh: str | None = None
    # 組み合わせ解釈（日本語のみ）。2枚以上のリーディングで値が入る。
    combination_text: str | None = None
    # 2026-09-10 複数枚リーディング。単数フィールド（card_id/card_name/keywords）は
    # 1枚目を指し続ける（履歴・管理画面・永続化層の互換のため）。
    spread_id: str = "daily"
    question_text: str = ""
    cards: list[ResultCard] = field(default_factory=list)


@dataclass(slots=True)
class HistoryItem:
    history_id: str
    user_id: str
    session_id: str
    created_at: datetime
    theme_id: str
    deck_id: str
    card_id: str
    summary: str
    full_text: str
    plan_at_creation: PlanType


@dataclass(slots=True)
class Announcement:
    announcement_id: str
    title: str
    body: str
    category: str
    start_at: datetime
    end_at: datetime
    is_important: bool
    link_url: str | None = None


@dataclass(slots=True)
class PushCampaign:
    campaign_id: str
    title: str
    body: str
    category: str
    channel: CampaignChannel
    target_segment: str
    scheduled_at: datetime
    created_at: datetime
    status: CampaignStatus = CampaignStatus.SCHEDULED
    is_ab_test: bool = False


@dataclass(slots=True)
class NotificationSetting:
    user_id: str
    push_enabled: bool = True
    reminder_enabled: bool = True
    campaign_enabled: bool = True
    updated_at: datetime = field(default_factory=now_jst)


@dataclass(slots=True)
class Product:
    product_code: str
    title: str
    plan_type: PlanType
    price_jpy: int
    ticket_amount: int = 0
    is_subscription: bool = False
    is_active: bool = True


@dataclass(slots=True)
class ExternalLink:
    link_id: str
    category: str
    title: str
    url: str
    is_active: bool = True


@dataclass(slots=True)
class LiveEvent:
    live_event_id: str
    title: str
    start_at: datetime
    archive_url: str | None = None
    is_public: bool = True


@dataclass(slots=True)
class AdminRole:
    role_id: str
    name: str
    permissions: list[str]


@dataclass(slots=True)
class AdminUser:
    admin_user_id: str
    email: str
    password: str
    role_id: str
    is_active: bool = True
    created_at: datetime = field(default_factory=now_jst)


@dataclass(slots=True)
class AdminSession:
    token: str
    admin_user_id: str
    issued_at: datetime
    expires_at: datetime


@dataclass(slots=True)
class AnalyticsEvent:
    event_id: str
    event_name: str
    user_id: str | None
    occurred_at: datetime
    properties: dict[str, str] = field(default_factory=dict)


@dataclass(slots=True)
class Inquiry:
    inquiry_id: str
    user_id: str
    category: str
    body: str
    email: str | None
    created_at: datetime


@dataclass(slots=True)
class PurchaseResult:
    accepted: bool
    user_id: str
    plan: PlanType
    tickets: int
    message: str


@dataclass(slots=True)
class AuditLog:
    audit_id: str
    actor_type: str
    actor_id: str
    action: str
    resource_type: str
    resource_id: str | None
    detail: dict[str, str] = field(default_factory=dict)
    occurred_at: datetime = field(default_factory=now_jst)
