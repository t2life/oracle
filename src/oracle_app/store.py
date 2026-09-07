from __future__ import annotations

import threading
from datetime import timedelta
from uuid import uuid4

from .config import AppConfig
from .content_loader import load_card_content
from .models import (
	AdminRole,
	AdminSession,
	AdminUser,
	AuditLog,
	AnalyticsEvent,
	Announcement,
	AuthAccount,
	AuthProvider,
	CampaignChannel,
	CampaignStatus,
	Card,
	Deck,
	ExternalLink,
	HistoryItem,
	Inquiry,
	LiveEvent,
	NotificationSetting,
	PlanType,
	Product,
	Profile,
	PushCampaign,
	ReadingResult,
	ReadingSession,
	Theme,
	User,
)
from .time_utils import date_key_jst, now_jst


class InMemoryStore:
	def __init__(self, config: AppConfig) -> None:
		self._config = config
		self._lock = threading.RLock()
		self._users: dict[str, User] = {}
		self._profiles: dict[str, Profile] = {}
		self._auth_accounts: dict[str, AuthAccount] = {}
		self._themes: dict[str, Theme] = {}
		self._decks: dict[str, Deck] = {}
		self._cards: dict[str, Card] = {}
		self._cards_by_deck: dict[str, list[str]] = {}
		self._sessions: dict[str, ReadingSession] = {}
		self._results: dict[str, ReadingResult] = {}
		self._history: list[HistoryItem] = []
		self._announcements: dict[str, Announcement] = {}
		self._notification_tokens: dict[str, str] = {}
		self._notification_settings: dict[str, NotificationSetting] = {}
		self._push_campaigns: dict[str, PushCampaign] = {}
		self._inquiries: list[Inquiry] = []
		self._used_receipts: set[str] = set()
		self._products: dict[str, Product] = {}
		self._external_links: dict[str, ExternalLink] = {}
		self._live_events: dict[str, LiveEvent] = {}
		self._admin_roles: dict[str, AdminRole] = {}
		self._admin_users: dict[str, AdminUser] = {}
		self._admin_sessions: dict[str, AdminSession] = {}
		self._analytics_events: list[AnalyticsEvent] = []
		self._audit_logs: list[AuditLog] = []
		self._seed_master_data()

	def _seed_master_data(self) -> None:
		# マスタ名称の3言語マップ（ja=正・en=英語・zh=簡体字中国語）
		theme_name_map = {
			"subconscious": ("潜在意識", "Subconscious", "潜意识"),
			"higher_self": ("ハイヤーセルフ", "Higher Self", "高我"),
			"love": ("恋愛", "Love", "爱情"),
			"money": ("金運", "Wealth", "财运"),
			"work": ("仕事", "Work", "事业"),
			"health": ("健康", "Health", "健康"),
			"relationships": ("人間関係", "Relationships", "人际关系"),
			"soul": ("魂", "Soul", "灵魂"),
			"awakening": ("覚醒", "Awakening", "觉醒"),
			"karma": ("カルマ", "Karma", "业力"),
			"past_life": ("前世", "Past Life", "前世"),
		}

		deck_name_map = {
			"japanese_mythology": ("日本神話デッキ", "Japanese Mythology Deck", "日本神话牌组"),
			"ryujin": ("龍神デッキ", "Dragon God Deck", "龙神牌组"),
			"blythe": ("ブライスドールデッキ", "Blythe Doll Deck", "布莱斯娃娃牌组"),
		}

		def _theme_names(theme_id: str) -> tuple[str, str, str]:
			return theme_name_map.get(theme_id, (theme_id, theme_id, theme_id))

		def _deck_names(deck_id: str) -> tuple[str, str, str]:
			return deck_name_map.get(deck_id, (deck_id, deck_id, deck_id))

		for theme_id in self._config.default_theme_ids:
			name_ja, name_en, name_zh = _theme_names(theme_id)
			self._themes[theme_id] = Theme(
				theme_id=theme_id,
				name_ja=name_ja,
				is_visible=True,
				name_en=name_en,
				name_zh=name_zh,
			)

		for theme_id in self._config.legacy_hidden_theme_ids:
			name_ja, name_en, name_zh = _theme_names(theme_id)
			self._themes[theme_id] = Theme(
				theme_id=theme_id,
				name_ja=name_ja,
				is_visible=False,
				name_en=name_en,
				name_zh=name_zh,
			)

		for order, deck_id in enumerate(self._config.default_deck_ids, start=1):
			name_ja, name_en, name_zh = _deck_names(deck_id)
			self._decks[deck_id] = Deck(
				deck_id=deck_id,
				name_ja=name_ja,
				is_published=True,
				sort_order=order,
				name_en=name_en,
				name_zh=name_zh,
			)
			self._cards_by_deck[deck_id] = []

		for deck_id, card_count in self._config.card_counts_by_deck.items():
			deck_ja, deck_en, deck_zh = _deck_names(deck_id)
			if deck_id == "japanese_mythology":
				# 日本神話デッキはカードDB（44柱.xlsx由来のcard_content.json）が正本
				self._seed_japanese_mythology_cards(_theme_names)
				continue
			for number in range(1, card_count + 1):
				card_id = f"{deck_id}_card_{number:03d}"
				name_ja = f"{deck_ja} {number}"
				name_en = f"{deck_en} {number}"
				name_zh = f"{deck_zh} {number}"
				keywords = [f"示唆{number % 5 + 1}", "内省", "行動"]
				keywords_en = [f"Insight {number % 5 + 1}", "Introspection", "Action"]
				keywords_zh = [f"启示{number % 5 + 1}", "内省", "行动"]
				default_meaning = (
					f"{name_ja}は、焦らず現状を受け止め、次の一歩を丁寧に整える合図です。"
				)
				default_meaning_en = (
					f"{name_en} is a sign to accept the present calmly and prepare your next step with care."
				)
				default_meaning_zh = (
					f"{name_zh}提示你从容接纳现状，用心准备好下一步。"
				)
				meanings_by_theme = {
					theme_id: f"{_theme_names(theme_id)[0]}について、{name_ja}は自分軸を守る判断を示します。"
					for theme_id in self._themes
				}
				meanings_by_theme_en = {
					theme_id: (
						f"Regarding {_theme_names(theme_id)[1]}, "
						f"{name_en} suggests a decision that stays true to yourself."
					)
					for theme_id in self._themes
				}
				meanings_by_theme_zh = {
					theme_id: f"关于{_theme_names(theme_id)[2]}，{name_zh}提示你做出忠于自我的判断。"
					for theme_id in self._themes
				}
				card = Card(
					card_id=card_id,
					deck_id=deck_id,
					name_ja=name_ja,
					keywords=keywords,
					default_meaning=default_meaning,
					meanings_by_theme=meanings_by_theme,
					name_en=name_en,
					keywords_en=keywords_en,
					default_meaning_en=default_meaning_en,
					meanings_by_theme_en=meanings_by_theme_en,
					name_zh=name_zh,
					keywords_zh=keywords_zh,
					default_meaning_zh=default_meaning_zh,
					meanings_by_theme_zh=meanings_by_theme_zh,
				)
				self._cards[card_id] = card
				self._cards_by_deck[deck_id].append(card_id)

		now = now_jst()
		announcement = Announcement(
			announcement_id="ann_001",
			title="運営からのお知らせ",
			body="新しい神託体験の改善を段階的に公開します。",
			category="重要なお知らせ",
			start_at=now - timedelta(days=1),
			end_at=now + timedelta(days=30),
			is_important=True,
			link_url=None,
		)
		self._announcements[announcement.announcement_id] = announcement

		self._products["ticket_trial_30"] = Product(
			product_code="ticket_trial_30",
			title="初回お試し30枚",
			plan_type=PlanType.TICKET,
			price_jpy=300,
			ticket_amount=30,
			is_subscription=False,
		)
		self._products["ticket_20"] = Product(
			product_code="ticket_20",
			title="チケット20枚",
			plan_type=PlanType.TICKET,
			price_jpy=500,
			ticket_amount=20,
			is_subscription=False,
		)
		self._products["ticket_50"] = Product(
			product_code="ticket_50",
			title="チケット50枚",
			plan_type=PlanType.TICKET,
			price_jpy=1000,
			ticket_amount=50,
			is_subscription=False,
		)
		self._products["ticket_120"] = Product(
			product_code="ticket_120",
			title="チケット120枚",
			plan_type=PlanType.TICKET,
			price_jpy=2000,
			ticket_amount=120,
			is_subscription=False,
		)
		self._products[self._config.pricing.subscription_product_code] = Product(
			product_code=self._config.pricing.subscription_product_code,
			title="サブスクリプション月額",
			plan_type=PlanType.SUBSCRIPTION,
			price_jpy=500,
			ticket_amount=0,
			is_subscription=True,
		)

		for idx, url in enumerate(self._config.links.shop_links, start=1):
			link_id = f"shop_{idx:03d}"
			self._external_links[link_id] = ExternalLink(
				link_id=link_id,
				category="shop",
				title=f"ショップ導線 {idx}",
				url=url,
				is_active=True,
			)

		for idx, url in enumerate(self._config.links.consultation_links, start=1):
			link_id = f"consult_{idx:03d}"
			self._external_links[link_id] = ExternalLink(
				link_id=link_id,
				category="consultation",
				title=f"鑑定導線 {idx}",
				url=url,
				is_active=True,
			)

		for idx, url in enumerate(self._config.links.live_links, start=1):
			link_id = f"live_{idx:03d}"
			self._external_links[link_id] = ExternalLink(
				link_id=link_id,
				category="live",
				title=f"ロンの部屋導線 {idx}",
				url=url,
				is_active=True,
			)

		self._live_events["live_001"] = LiveEvent(
			live_event_id="live_001",
			title="ロンの部屋 定期配信",
			start_at=now + timedelta(days=3),
			archive_url=None,
			is_public=True,
		)

		role_definitions: dict[str, tuple[str, list[str]]] = {
			"super_admin": (
				"Super Admin",
				[
					"dashboard:view",
					"cards:manage",
					"decks:manage",
					"themes:manage",
					"announcements:manage",
					"notifications:manage",
					"users:view",
					"inquiries:view",
					"audit:view",
				],
			),
			"content_admin": (
				"Content Admin",
				[
					"dashboard:view",
					"cards:manage",
					"decks:manage",
					"themes:manage",
					"announcements:manage",
					"notifications:manage",
				],
			),
			"cs_support": (
				"CS Support",
				[
					"dashboard:view",
					"users:view",
					"inquiries:view",
				],
			),
			"analyst": (
				"Analyst",
				[
					"dashboard:view",
				],
			),
		}
		for role_id, (role_name, permissions) in role_definitions.items():
			self._admin_roles[role_id] = AdminRole(
				role_id=role_id,
				name=role_name,
				permissions=permissions,
			)
		role_id = self._config.admin.default_role_id

		admin_id = "admin_001"
		self._admin_users[admin_id] = AdminUser(
			admin_user_id=admin_id,
			email=self._config.admin.default_admin_email,
			password=self._config.admin.default_admin_password,
			role_id=role_id,
			is_active=True,
			created_at=now,
		)

	def _seed_japanese_mythology_cards(self, theme_names) -> None:
		"""日本神話デッキをカードDB由来のコンテンツでシードする（No.1〜44）。

		英語名はv1未収録（実装マスタが29件・別表記体系で結合不能と実測）のため
		name_en/name_zhは空＝UI側で日本語神名へフォールバックする。
		en/zhの解釈文は暫定テンプレ（承認方針⑩-#12）。
		"""
		deck_id = "japanese_mythology"
		content = load_card_content()
		for entry in content["cards"]:
			name_ja = entry["name_ja"]
			meanings_en = {}
			meanings_zh = {}
			for theme_id in self._config.default_theme_ids:
				_, theme_en, theme_zh = theme_names(theme_id)
				meanings_en[theme_id] = (
					f"Regarding {theme_en}, {name_ja} suggests a decision "
					"that stays true to yourself."
				)
				meanings_zh[theme_id] = (
					f"关于{theme_zh}，{name_ja}提示你做出忠于自我的判断。"
				)
			card = Card(
				card_id=entry["card_id"],
				deck_id=deck_id,
				name_ja=name_ja,
				keywords=list(entry.get("keywords", [])),
				default_meaning=entry.get("basic_meaning", ""),
				meanings_by_theme=dict(entry.get("theme_meanings", {})),
				name_en="",
				keywords_en=[],
				default_meaning_en=(
					f"{name_ja} is a sign to accept the present calmly "
					"and prepare your next step with care."
				),
				meanings_by_theme_en=meanings_en,
				name_zh="",
				keywords_zh=[],
				default_meaning_zh=f"{name_ja}提示你从容接纳现状，用心准备好下一步。",
				meanings_by_theme_zh=meanings_zh,
			)
			self._cards[card.card_id] = card
			self._cards_by_deck[deck_id].append(card.card_id)

	# ---- user/account ----
	def get_or_create_user(self, user_id: str) -> User:
		with self._lock:
			user = self._users.get(user_id)
			if user is None:
				user = User(user_id=user_id, plan=PlanType.FREE)
				self._users[user_id] = user
				self._profiles[user_id] = Profile(user_id=user_id, display_name=user_id)
				self._notification_settings[user_id] = NotificationSetting(user_id=user_id)
			return user

	def update_user(self, user: User) -> None:
		with self._lock:
			self._users[user.user_id] = user

	def list_users(self) -> list[User]:
		with self._lock:
			return sorted(self._users.values(), key=lambda x: x.created_at)

	def get_or_create_profile(self, user_id: str) -> Profile:
		with self._lock:
			profile = self._profiles.get(user_id)
			if profile is None:
				profile = Profile(user_id=user_id, display_name=user_id)
				self._profiles[user_id] = profile
			return profile

	def update_profile_display_name(self, user_id: str, display_name: str) -> Profile:
		with self._lock:
			profile = self._profiles.get(user_id)
			if profile is None:
				profile = Profile(user_id=user_id, display_name=display_name)
				self._profiles[user_id] = profile
			else:
				profile.display_name = display_name
				profile.updated_at = now_jst()
			return profile

	def get_auth_account(self, provider: AuthProvider, provider_user_id: str) -> AuthAccount | None:
		key = f"{provider.value}:{provider_user_id}"
		with self._lock:
			return self._auth_accounts.get(key)

	def add_auth_account(
		self,
		user_id: str,
		provider: AuthProvider,
		provider_user_id: str,
		email: str | None,
	) -> AuthAccount:
		key = f"{provider.value}:{provider_user_id}"
		with self._lock:
			existed = self._auth_accounts.get(key)
			if existed is not None:
				return existed
			account = AuthAccount(
				auth_account_id=f"auth_{uuid4().hex}",
				user_id=user_id,
				provider=provider,
				provider_user_id=provider_user_id,
				email=email,
			)
			self._auth_accounts[key] = account
			return account

	# ---- theme/deck/card ----
	def list_themes(self) -> list[Theme]:
		with self._lock:
			return [theme for theme in self._themes.values() if theme.is_visible]

	def list_all_themes(self) -> list[Theme]:
		with self._lock:
			return sorted(self._themes.values(), key=lambda x: x.theme_id)

	def get_theme(self, theme_id: str) -> Theme | None:
		with self._lock:
			return self._themes.get(theme_id)

	def list_decks(self) -> list[Deck]:
		with self._lock:
			return sorted(
				[deck for deck in self._decks.values() if deck.is_published],
				key=lambda x: x.sort_order,
			)

	def list_all_decks(self) -> list[Deck]:
		with self._lock:
			return sorted(self._decks.values(), key=lambda x: x.sort_order)

	def get_deck(self, deck_id: str) -> Deck | None:
		with self._lock:
			return self._decks.get(deck_id)

	def list_cards_by_deck(self, deck_id: str) -> list[Card]:
		with self._lock:
			return [self._cards[card_id] for card_id in self._cards_by_deck.get(deck_id, [])]

	def list_cards(self, deck_id: str | None = None, query: str | None = None) -> list[Card]:
		with self._lock:
			if deck_id:
				cards = [self._cards[card_id] for card_id in self._cards_by_deck.get(deck_id, [])]
			else:
				cards = list(self._cards.values())

			if query:
				lowered = query.lower()
				cards = [
					card
					for card in cards
					if lowered in card.name_ja.lower()
					or any(lowered in keyword.lower() for keyword in card.keywords)
				]
			return cards

	def get_card(self, card_id: str) -> Card | None:
		with self._lock:
			return self._cards.get(card_id)

	# ---- reading flow ----
	def create_session(self, session: ReadingSession) -> None:
		with self._lock:
			self._sessions[session.session_id] = session

	def get_session(self, session_id: str) -> ReadingSession | None:
		with self._lock:
			return self._sessions.get(session_id)

	def count_user_sessions_on_date(self, user_id: str, target_date_key: str) -> int:
		with self._lock:
			count = 0
			for session in self._sessions.values():
				if session.user_id != user_id:
					continue
				if date_key_jst(session.started_at) == target_date_key:
					count += 1
			return count

	def save_result(self, result: ReadingResult) -> None:
		with self._lock:
			self._results[result.session_id] = result

	def get_result(self, session_id: str) -> ReadingResult | None:
		with self._lock:
			return self._results.get(session_id)

	def add_history_item(self, item: HistoryItem) -> None:
		with self._lock:
			self._history.append(item)

	def trim_history_for_user(self, user_id: str, max_items: int) -> None:
		with self._lock:
			items = [item for item in self._history if item.user_id == user_id]
			items.sort(key=lambda x: x.created_at, reverse=True)
			keep_ids = {item.history_id for item in items[:max_items]}
			self._history = [
				item
				for item in self._history
				if item.user_id != user_id or item.history_id in keep_ids
			]

	def list_history(self, user_id: str) -> list[HistoryItem]:
		with self._lock:
			items = [item for item in self._history if item.user_id == user_id]
			items.sort(key=lambda x: x.created_at, reverse=True)
			return items

	def get_history_item(self, history_id: str) -> HistoryItem | None:
		with self._lock:
			for item in self._history:
				if item.history_id == history_id:
					return item
			return None

	def delete_history_item(self, user_id: str, history_id: str) -> bool:
		"""本人の履歴1件を削除する。対象が存在すればTrue。"""
		with self._lock:
			for index, item in enumerate(self._history):
				if item.history_id == history_id and item.user_id == user_id:
					del self._history[index]
					return True
			return False

	# ---- announcements / inquiries ----
	def list_announcements(self) -> list[Announcement]:
		now = now_jst()
		with self._lock:
			return [
				ann
				for ann in self._announcements.values()
				if ann.start_at <= now <= ann.end_at
			]

	def list_all_announcements(self) -> list[Announcement]:
		with self._lock:
			return sorted(
				self._announcements.values(),
				key=lambda x: x.start_at,
				reverse=True,
			)

	def create_announcement(
		self,
		title: str,
		body: str,
		category: str,
		start_at,
		end_at,
		is_important: bool,
		link_url: str | None,
	) -> Announcement:
		with self._lock:
			ann = Announcement(
				announcement_id=f"ann_{uuid4().hex}",
				title=title,
				body=body,
				category=category,
				start_at=start_at,
				end_at=end_at,
				is_important=is_important,
				link_url=link_url,
			)
			self._announcements[ann.announcement_id] = ann
			return ann

	def add_inquiry(self, user_id: str, category: str, body: str, email: str | None) -> Inquiry:
		with self._lock:
			inquiry = Inquiry(
				inquiry_id=f"inq_{uuid4().hex}",
				user_id=user_id,
				category=category,
				body=body,
				email=email,
				created_at=now_jst(),
			)
			self._inquiries.append(inquiry)
			return inquiry

	def list_inquiries(self) -> list[Inquiry]:
		with self._lock:
			return sorted(self._inquiries, key=lambda x: x.created_at, reverse=True)

	# ---- notification ----
	def save_notification_token(self, user_id: str, token: str) -> None:
		with self._lock:
			self._notification_tokens[user_id] = token

	def has_notification_token(self, user_id: str) -> bool:
		with self._lock:
			return user_id in self._notification_tokens

	def list_notification_tokens(self) -> list[str]:
		with self._lock:
			return list(self._notification_tokens.values())

	def create_push_campaign(
		self,
		title: str,
		body: str,
		category: str,
		target_segment: str,
		scheduled_at,
		is_ab_test: bool,
	) -> PushCampaign:
		with self._lock:
			campaign = PushCampaign(
				campaign_id=f"pc_{uuid4().hex}",
				title=title,
				body=body,
				category=category,
				channel=CampaignChannel.PUSH,
				target_segment=target_segment,
				scheduled_at=scheduled_at,
				created_at=now_jst(),
				status=CampaignStatus.SCHEDULED,
				is_ab_test=is_ab_test,
			)
			self._push_campaigns[campaign.campaign_id] = campaign
			return campaign

	def get_push_campaign(self, campaign_id: str) -> PushCampaign | None:
		with self._lock:
			return self._push_campaigns.get(campaign_id)

	def list_push_campaigns(self) -> list[PushCampaign]:
		with self._lock:
			return sorted(self._push_campaigns.values(), key=lambda x: x.created_at, reverse=True)

	def mark_campaign_dispatched(self, campaign_id: str) -> PushCampaign:
		with self._lock:
			campaign = self._push_campaigns.get(campaign_id)
			if campaign is None:
				raise ValueError("キャンペーンが存在しません。")
			campaign.status = CampaignStatus.DISPATCHED
			return campaign

	# ---- billing ----
	def register_receipt_if_new(self, receipt_id: str) -> bool:
		with self._lock:
			if receipt_id in self._used_receipts:
				return False
			self._used_receipts.add(receipt_id)
			return True

	def list_products(self) -> list[Product]:
		with self._lock:
			return [product for product in self._products.values() if product.is_active]

	# ---- external links ----
	def list_external_links(self, category: str) -> list[ExternalLink]:
		with self._lock:
			return [
				link
				for link in self._external_links.values()
				if link.category == category and link.is_active
			]

	def list_live_events(self) -> list[LiveEvent]:
		with self._lock:
			return [event for event in self._live_events.values() if event.is_public]

	# ---- admin ----
	def get_admin_user_by_email(self, email: str) -> AdminUser | None:
		with self._lock:
			for admin_user in self._admin_users.values():
				if admin_user.email == email and admin_user.is_active:
					return admin_user
			return None

	def get_admin_user(self, admin_user_id: str) -> AdminUser | None:
		with self._lock:
			return self._admin_users.get(admin_user_id)

	def list_admin_users(self) -> list[AdminUser]:
		with self._lock:
			return sorted(self._admin_users.values(), key=lambda x: x.created_at)

	def create_admin_session(self, admin_user_id: str, ttl_minutes: int = 120) -> AdminSession:
		with self._lock:
			issued = now_jst()
			session = AdminSession(
				token=uuid4().hex,
				admin_user_id=admin_user_id,
				issued_at=issued,
				expires_at=issued + timedelta(minutes=ttl_minutes),
			)
			self._admin_sessions[session.token] = session
			return session

	def get_admin_session(self, token: str) -> AdminSession | None:
		with self._lock:
			session = self._admin_sessions.get(token)
			if session is None:
				return None
			if session.expires_at <= now_jst():
				del self._admin_sessions[token]
				return None
			return session

	def list_admin_roles(self) -> list[AdminRole]:
		with self._lock:
			return list(self._admin_roles.values())

	def get_admin_role(self, role_id: str) -> AdminRole | None:
		with self._lock:
			return self._admin_roles.get(role_id)

	# ---- analytics ----
	def add_analytics_event(
		self,
		event_name: str,
		user_id: str | None,
		properties: dict[str, str] | None,
	) -> AnalyticsEvent:
		with self._lock:
			event = AnalyticsEvent(
				event_id=f"evt_{uuid4().hex}",
				event_name=event_name,
				user_id=user_id,
				occurred_at=now_jst(),
				properties=properties or {},
			)
			self._analytics_events.append(event)
			return event

	def list_analytics_events(self) -> list[AnalyticsEvent]:
		with self._lock:
			return sorted(self._analytics_events, key=lambda x: x.occurred_at, reverse=True)

	def add_audit_log(
		self,
		actor_type: str,
		actor_id: str,
		action: str,
		resource_type: str,
		resource_id: str | None,
		detail: dict[str, str] | None,
	) -> AuditLog:
		with self._lock:
			log = AuditLog(
				audit_id=f"aud_{uuid4().hex}",
				actor_type=actor_type,
				actor_id=actor_id,
				action=action,
				resource_type=resource_type,
				resource_id=resource_id,
				detail=detail or {},
			)
			self._audit_logs.append(log)
			return log

	def list_audit_logs(self, limit: int = 200) -> list[AuditLog]:
		with self._lock:
			ordered = sorted(self._audit_logs, key=lambda x: x.occurred_at, reverse=True)
			return ordered[:limit]

