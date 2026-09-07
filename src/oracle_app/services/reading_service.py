from __future__ import annotations

import random
from uuid import uuid4

from ..config import AppConfig
from ..logging_utils import get_logger
from ..models import HistoryItem, PlanType, ReadingResult, ReadingSession, SessionStatus
from ..store import InMemoryStore
from ..time_utils import date_key_jst, now_jst
from .billing_service import BillingService
from .interpretation_engine import InterpretationEngine


class ReadingService:
    def __init__(
        self,
        store: InMemoryStore,
        config: AppConfig,
        billing_service: BillingService,
        interpretation_engine: InterpretationEngine,
    ) -> None:
        self._store = store
        self._config = config
        self._billing_service = billing_service
        self._interpretation_engine = interpretation_engine
        self._logger = get_logger(self.__class__.__name__)

    def _split_three_piles(self, card_ids: list[str]) -> dict[int, list[str]]:
        piles: dict[int, list[str]] = {1: [], 2: [], 3: []}
        for index, card_id in enumerate(card_ids):
            piles[(index % 3) + 1].append(card_id)
        return piles

    def start_session(
        self,
        user_id: str,
        theme_id: str,
        deck_id: str,
        draw_count: int,
    ) -> ReadingSession:
        if draw_count < 1 or draw_count > 3:
            raise ValueError("draw_count は1から3の範囲で指定してください。")

        user = self._store.get_or_create_user(user_id)
        theme = self._store.get_theme(theme_id)
        deck = self._store.get_deck(deck_id)

        if theme is None or not theme.is_visible:
            raise ValueError("指定されたテーマが存在しません。")
        if deck is None or not deck.is_published:
            raise ValueError("指定されたデッキが存在しません。")

        today_key = date_key_jst(now_jst())
        if user.plan in {PlanType.FREE, PlanType.GUEST}:
            if self._store.count_user_sessions_on_date(user_id, today_key) >= self._config.free_daily_draw_limit:
                raise PermissionError("無料プランは1日1回までです。")

        if not self._billing_service.can_use_draw_count(user, draw_count):
            raise PermissionError("3枚引きは有料プランで利用できます。")

        cards = self._store.list_cards_by_deck(deck_id)
        if len(cards) < draw_count * 3:
            raise ValueError("デッキ内のカード数が不足しています。")

        self._billing_service.consume_for_session(user, draw_count)

        ordered_ids = [card.card_id for card in cards]
        rng = random.Random()
        rng.seed(f"{user_id}:{theme_id}:{deck_id}:{uuid4().hex}")
        rng.shuffle(ordered_ids)

        session = ReadingSession(
            session_id=f"ses_{uuid4().hex}",
            user_id=user_id,
            theme_id=theme_id,
            deck_id=deck_id,
            draw_count=draw_count,
            started_at=now_jst(),
            status=SessionStatus.STARTED,
            precomputed_card_ids=ordered_ids,
        )
        self._store.create_session(session)
        self._logger.info(
            "セッション開始: session_id=%s user_id=%s theme=%s deck=%s draw=%s",
            session.session_id,
            user_id,
            theme_id,
            deck_id,
            draw_count,
        )
        return session

    def complete_shuffle(
        self,
        session_id: str,
        idle_seconds: float,
        finger_released: bool,
        swipe_distance: float,
    ) -> ReadingSession:
        session = self._store.get_session(session_id)
        if session is None:
            raise ValueError("セッションが存在しません。")
        if session.status != SessionStatus.STARTED:
            raise ValueError("シャッフル完了可能な状態ではありません。")

        rules = self._config.shuffle
        if not finger_released:
            raise ValueError("指が画面から離れている必要があります。")
        if idle_seconds < rules.idle_seconds_min or idle_seconds > rules.idle_seconds_max:
            raise ValueError("シャッフル終了判定の待機時間が仕様外です。")
        if swipe_distance < rules.min_swipe_distance:
            raise ValueError("最低操作量を満たしていません。")

        session.piles = self._split_three_piles(session.precomputed_card_ids)
        session.shuffled_at = now_jst()
        session.status = SessionStatus.SHUFFLED
        self._logger.debug("シャッフル完了: session_id=%s", session_id)
        return session

    def select_pile(self, session_id: str, pile_index: int) -> ReadingSession:
        session = self._store.get_session(session_id)
        if session is None:
            raise ValueError("セッションが存在しません。")
        if session.status != SessionStatus.SHUFFLED:
            raise ValueError("山選択可能な状態ではありません。")
        if pile_index not in {1, 2, 3}:
            raise ValueError("山番号は1から3で指定してください。")
        if not session.piles.get(pile_index):
            raise ValueError("選択された山にカードがありません。")

        session.chosen_pile = pile_index
        session.status = SessionStatus.PILE_SELECTED
        self._logger.debug("山選択: session_id=%s pile=%s", session_id, pile_index)
        return session

    def select_card(self, session_id: str, card_index: int) -> ReadingResult:
        session = self._store.get_session(session_id)
        if session is None:
            raise ValueError("セッションが存在しません。")
        if session.status != SessionStatus.PILE_SELECTED:
            raise ValueError("カード選択可能な状態ではありません。")
        if session.chosen_pile is None:
            raise ValueError("先に山を選択してください。")

        pile = session.piles.get(session.chosen_pile, [])
        if not pile:
            raise ValueError("選択済みの山が空です。")
        if card_index < 1 or card_index > len(pile):
            raise ValueError("カード番号が不正です。")

        card_id = pile[card_index - 1]
        card = self._store.get_card(card_id)
        if card is None:
            raise ValueError("カード情報が見つかりません。")

        interpretation = card.meanings_by_theme.get(session.theme_id, card.default_meaning)
        # カードDB搭載カード（日本神話デッキ）は解釈合成エンジンで託宣文を構成する。
        # DB非搭載カードはエンジンがfallback_textをそのまま返す（fail-soft）。
        interpretation = self._interpretation_engine.compose_ja(
            card_id=card.card_id,
            theme_id=session.theme_id,
            date_key=date_key_jst(now_jst()),
            session_id=session.session_id,
            fallback_text=interpretation,
        )
        interpretation_en = card.meanings_by_theme_en.get(
            session.theme_id, card.default_meaning_en
        )
        interpretation_zh = card.meanings_by_theme_zh.get(
            session.theme_id, card.default_meaning_zh
        )
        caution_text = "本結果は内省を助けるためのメッセージです。最終判断はご自身で行ってください。"
        caution_text_en = (
            "This result is a message to support self-reflection. "
            "Please make the final decision yourself."
        )
        caution_text_zh = "本结果仅为帮助自我反思的讯息，最终决定请由您自己做出。"

        result = ReadingResult(
            session_id=session.session_id,
            user_id=session.user_id,
            theme_id=session.theme_id,
            deck_id=session.deck_id,
            card_id=card.card_id,
            card_name=card.name_ja,
            keywords=card.keywords,
            interpretation_text=interpretation,
            caution_text=caution_text,
            created_at=now_jst(),
            copied=False,
            card_name_en=card.name_en,
            keywords_en=card.keywords_en,
            interpretation_text_en=interpretation_en,
            caution_text_en=caution_text_en,
            card_name_zh=card.name_zh,
            keywords_zh=card.keywords_zh,
            interpretation_text_zh=interpretation_zh,
            caution_text_zh=caution_text_zh,
        )
        self._store.save_result(result)
        session.selected_card_id = card.card_id
        session.status = SessionStatus.CARD_OPENED
        self._logger.info("カード確定: session_id=%s card_id=%s", session_id, card.card_id)
        return result

    def get_result(self, session_id: str) -> ReadingResult:
        result = self._store.get_result(session_id)
        if result is None:
            raise ValueError("結果が存在しません。")
        return result

    def mark_copied(self, session_id: str) -> ReadingResult:
        result = self.get_result(session_id)
        result.copied = True
        self._store.save_result(result)
        self._logger.debug("結果コピー: session_id=%s", session_id)
        return result

    def save_history(self, user_id: str, session_id: str) -> HistoryItem:
        session = self._store.get_session(session_id)
        if session is None:
            raise ValueError("セッションが存在しません。")
        if session.user_id != user_id:
            raise PermissionError("他ユーザーのセッションは保存できません。")

        result = self._store.get_result(session_id)
        if result is None:
            raise ValueError("保存対象の結果がありません。")

        user = self._store.get_or_create_user(user_id)
        summary = result.interpretation_text[:60]
        item = HistoryItem(
            history_id=f"his_{uuid4().hex}",
            user_id=user_id,
            session_id=session_id,
            created_at=now_jst(),
            theme_id=result.theme_id,
            deck_id=result.deck_id,
            card_id=result.card_id,
            summary=summary,
            full_text=result.interpretation_text,
            plan_at_creation=user.plan,
        )
        self._store.add_history_item(item)

        if user.plan in {PlanType.FREE, PlanType.GUEST}:
            self._store.trim_history_for_user(
                user_id=user_id,
                max_items=self._config.history.free_visible_limit,
            )

        session.status = SessionStatus.COMPLETED
        self._logger.info("履歴保存: user_id=%s session_id=%s", user_id, session_id)
        return item

    def list_history(self, user_id: str) -> list[HistoryItem]:
        return self._store.list_history(user_id)
