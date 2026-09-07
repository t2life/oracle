from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class ApiModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class MessageResponse(ApiModel):
    message: str


class AuthLoginRequest(ApiModel):
    user_id: str = Field(min_length=1, max_length=128)

class AuthLogoutRequest(ApiModel):
    user_id: str = Field(min_length=1, max_length=128)




class AuthProviderRequest(ApiModel):
    provider_user_id: str = Field(min_length=1, max_length=256)
    email: str | None = None


class UserResponse(ApiModel):
    user_id: str
    plan: str
    tickets: int
    visit_count: int
    subscription_expires_at: datetime | None = None
    display_name: str = ""


class ProfileResponse(ApiModel):
    user_id: str
    display_name: str


class ProfileUpdateRequest(ApiModel):
    user_id: str = Field(min_length=1, max_length=128)
    display_name: str = Field(min_length=1, max_length=40)


class ThemeResponse(ApiModel):
    theme_id: str
    name_ja: str
    name_en: str = ""
    name_zh: str = ""


class DeckResponse(ApiModel):
    deck_id: str
    name_ja: str
    sort_order: int
    name_en: str = ""
    name_zh: str = ""


class CardResponse(ApiModel):
    card_id: str
    deck_id: str
    name_ja: str
    keywords: list[str]
    name_en: str = ""
    keywords_en: list[str] = Field(default_factory=list)
    name_zh: str = ""
    keywords_zh: list[str] = Field(default_factory=list)


class StartReadingRequest(ApiModel):
    user_id: str = Field(min_length=1, max_length=128)
    theme_id: str = Field(min_length=1, max_length=64)
    deck_id: str = Field(min_length=1, max_length=64)
    draw_count: int = Field(default=1, ge=1, le=3)


class StartReadingResponse(ApiModel):
    session_id: str
    status: str
    started_at: datetime
    draw_count: int


class CompleteShuffleRequest(ApiModel):
    session_id: str
    idle_seconds: float = Field(ge=0.0)
    finger_released: bool
    swipe_distance: float = Field(ge=0.0)


class PileStatusResponse(ApiModel):
    session_id: str
    status: str
    pile_sizes: dict[str, int]


class SelectPileRequest(ApiModel):
    session_id: str
    pile_index: int = Field(ge=1, le=3)


class SelectCardRequest(ApiModel):
    session_id: str
    card_index: int = Field(ge=1)


class ReadingResultResponse(ApiModel):
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
    copied: bool
    card_name_en: str = ""
    keywords_en: list[str] = Field(default_factory=list)
    interpretation_text_en: str = ""
    caution_text_en: str | None = None
    card_name_zh: str = ""
    keywords_zh: list[str] = Field(default_factory=list)
    interpretation_text_zh: str = ""
    caution_text_zh: str | None = None
    combination_text: str | None = None


class SaveHistoryRequest(ApiModel):
    user_id: str


class HistoryItemResponse(ApiModel):
    history_id: str
    session_id: str
    created_at: datetime
    theme_id: str
    deck_id: str
    card_id: str
    summary: str
    full_text: str
    plan_at_creation: str


class ProductResponse(ApiModel):
    product_code: str
    title: str
    plan_type: str
    price_jpy: int
    ticket_amount: int
    is_subscription: bool


class PurchaseVerifyRequest(ApiModel):
    user_id: str
    product_code: str
    receipt_id: str


class PurchaseRestoreRequest(ApiModel):
    user_id: str
    product_code: str
    restore_receipt_id: str


class PurchaseVerifyResponse(ApiModel):
    accepted: bool
    user_id: str
    plan: str
    tickets: int
    message: str

class HealthReadyResponse(ApiModel):
    overall_status: str
    checked_at: datetime
    components: dict[str, str]



class NotificationTokenRequest(ApiModel):
    user_id: str
    token: str = Field(min_length=16, max_length=512)


class PushCampaignCreateRequest(ApiModel):
    title: str
    body: str
    category: str
    target_segment: str = "all"
    scheduled_at: datetime
    is_ab_test: bool = False


class PushCampaignResponse(ApiModel):
    campaign_id: str
    title: str
    body: str
    category: str
    target_segment: str
    scheduled_at: datetime
    created_at: datetime
    status: str
    is_ab_test: bool
    dispatch_result: str | None = None


class AnnouncementResponse(ApiModel):
    announcement_id: str
    title: str
    body: str
    category: str
    start_at: datetime
    end_at: datetime
    is_important: bool
    link_url: str | None


class AnnouncementCreateRequest(ApiModel):
    title: str
    body: str
    category: str
    start_at: datetime
    end_at: datetime
    is_important: bool = False
    link_url: str | None = None


class InquiryRequest(ApiModel):
    user_id: str
    category: str
    body: str
    email: str | None = None


class InquiryResponse(ApiModel):
    inquiry_id: str
    user_id: str
    category: str
    body: str
    email: str | None
    created_at: datetime


class ExternalLinkResponse(ApiModel):
    link_id: str
    category: str
    title: str
    url: str


class LiveEventResponse(ApiModel):
    live_event_id: str
    title: str
    start_at: datetime
    archive_url: str | None


class AnalyticsEventRequest(ApiModel):
    event_name: str
    user_id: str | None = None
    properties: dict[str, str] = Field(default_factory=dict)


class AnalyticsEventResponse(ApiModel):
    event_id: str
    event_name: str
    user_id: str | None
    occurred_at: datetime
    properties: dict[str, str]


class KpiSnapshotResponse(ApiModel):
    values: dict[str, int]


class AdminLoginRequest(ApiModel):
    email: str
    password: str


class AdminLoginResponse(ApiModel):
    token: str
    admin_user_id: str
    role_id: str


class AdminDashboardResponse(ApiModel):
    users_total: int
    inquiries_total: int
    announcements_total: int
    campaigns_total: int
    reading_completed: int
    ticket_purchased: int
    subscription_started: int
    updated_at: str


class AdminUserResponse(ApiModel):
    admin_user_id: str
    email: str
    role_id: str
    is_active: bool

class AuditLogResponse(ApiModel):
    audit_id: str
    actor_type: str
    actor_id: str
    action: str
    resource_type: str
    resource_id: str | None
    detail: dict[str, str]
    occurred_at: datetime


class UserSummaryResponse(ApiModel):
    user_id: str
    plan: str
    tickets: int
    created_at: datetime


class ThemeAdminResponse(ApiModel):
    theme_id: str
    name_ja: str
    is_visible: bool


class DeckAdminResponse(ApiModel):
    deck_id: str
    name_ja: str
    sort_order: int
    is_published: bool
