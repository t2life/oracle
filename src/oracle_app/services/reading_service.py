from __future__ import annotations

import random
from uuid import uuid4

from ..config import AppConfig
from ..logging_utils import get_logger
from ..models import (
    HistoryItem,
    PlanType,
    ReadingResult,
    ReadingSession,
    ResultCard,
    SessionStatus,
)
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

    # 相談内容の上限（2026-09-10 承認: 3000文字まで）。
    QUESTION_TEXT_MAX_LENGTH = 3000

    def spread_or_raise(self, spread_id: str) -> dict:
        """スプレッド定義（マスタ由来）を返す。未定義はエラー。"""
        spread = self._interpretation_engine.spread_for(spread_id)
        if spread is None:
            raise ValueError("指定されたスプレッドが存在しません。")
        return spread

    def resolve_draw_count(self, spread: dict, requested: int | None) -> int:
        """引く枚数を決める。フリー（枚数可変）のみ要求値を最小〜最大で受け付ける。"""
        fixed = int(spread.get("card_count") or 0)
        if fixed > 0:
            return fixed
        minimum = int(spread.get("min_cards") or 1)
        maximum = int(spread.get("max_cards") or 1)
        count = requested if requested is not None else minimum
        if count < minimum or count > maximum:
            raise ValueError(f"枚数は{minimum}〜{maximum}枚で指定してください。")
        return count

    def start_session(
        self,
        user_id: str,
        theme_id: str,
        deck_id: str,
        draw_count: int,
        spread_id: str = "daily",
        question_text: str = "",
        origin_session_id: str | None = None,
    ) -> ReadingSession:
        spread = self.spread_or_raise(spread_id)
        draw_count = self.resolve_draw_count(spread, draw_count)
        question_text = (question_text or "").strip()
        if len(question_text) > self.QUESTION_TEXT_MAX_LENGTH:
            raise ValueError(
                f"相談内容は{self.QUESTION_TEXT_MAX_LENGTH}文字以内で入力してください。"
            )

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

        # 対象プランと必要チケットはスプレッド定義（マスタ）が決める。
        if not self._billing_service.can_use_spread(user, spread):
            raise PermissionError("このリーディングは有料プランで利用できます。")

        cards = self._store.list_cards_by_deck(deck_id)
        if len(cards) < draw_count * 3:
            raise ValueError("デッキ内のカード数が不足しています。")

        # ★消費より先に起点を確かめる。順序を違えると、起点が不正でも
        # チケットだけ引かれる（テストで実際に 20→15 と減っていた）。
        carried = self._carried_card_id(user_id, origin_session_id)

        self._billing_service.consume_for_spread(user, spread)

        ordered_ids = [card.card_id for card in cards]
        rng = random.Random()
        rng.seed(f"{user_id}:{theme_id}:{deck_id}:{uuid4().hex}")
        rng.shuffle(ordered_ids)

        # 深掘り: 起点の託宣で出たカードを**1枚目として引き継ぐ**。
        # 引き直しにしないための要。引き継いだ1枚は**山から取り除く**ので、
        # 利用者は残りの枚数だけを選ぶ（同じカードを二度引かせない）。
        if carried is not None:
            ordered_ids.remove(carried)

        session = ReadingSession(
            session_id=f"ses_{uuid4().hex}",
            user_id=user_id,
            theme_id=theme_id,
            deck_id=deck_id,
            draw_count=draw_count,
            started_at=now_jst(),
            status=SessionStatus.STARTED,
            precomputed_card_ids=ordered_ids,
            spread_id=spread_id,
            question_text=question_text,
            origin_session_id=origin_session_id if carried else None,
            # 引き継いだ1枚は確定済みとして持つ（選ばせない）。
            selected_card_ids=[carried] if carried else [],
        )
        if carried:
            session.selected_card_id = carried
        self._store.create_session(session)
        self._logger.info(
            "セッション開始: session_id=%s user_id=%s theme=%s deck=%s "
            "spread=%s draw=%s 相談内容=%s文字",
            session.session_id,
            user_id,
            theme_id,
            deck_id,
            spread_id,
            draw_count,
            len(question_text),
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

    def _carried_card_id(
        self, user_id: str, origin_session_id: str | None
    ) -> str | None:
        """深掘りの起点から引き継ぐカード。起点が無ければ None。

        ★他人の結果や、まだ結果の出ていないセッションを起点にできない。
        引き継ぎはアカウントをまたがない（結果の持ち主だけが深掘りできる）。
        """
        if not origin_session_id:
            return None
        origin = self._store.get_result(origin_session_id)
        if origin is None:
            raise ValueError("深掘りの起点になる結果が見つかりません。")
        if origin.user_id != user_id:
            raise PermissionError("他の利用者の結果は深掘りできません。")
        return origin.card_id

    def select_card(self, session_id: str, card_index: int) -> ReadingResult | None:
        """カードを1枚確定する。

        必要枚数（スプレッド定義）に達するまでは None を返し、
        達した時点で結果を生成する。1枚のスプレッド（本日の託宣）は
        従来どおり1回の呼び出しで結果が返る。
        """
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
        if card_id in session.selected_card_ids:
            raise ValueError("同じカードは選べません。")
        card = self._store.get_card(card_id)
        if card is None:
            raise ValueError("カード情報が見つかりません。")

        session.selected_card_ids.append(card_id)
        if len(session.selected_card_ids) < session.draw_count:
            self._logger.info(
                "カード確定（途中）: session_id=%s %s/%s枚",
                session_id,
                len(session.selected_card_ids),
                session.draw_count,
            )
            return None

        # 1枚目を単数フィールドの代表とする（履歴・管理画面・永続化層の互換）。
        card = self._store.get_card(session.selected_card_ids[0]) or card
        interpretation = card.meanings_by_theme.get(session.theme_id, card.default_meaning)
        # カードDB搭載カード（日本神話デッキ）は解釈合成エンジンで託宣文を構成する。
        # DB非搭載カードはエンジンがfallback_textをそのまま返す（fail-soft）。
        interpretation = self._interpretation_engine.compose_reading(
            card_ids=list(session.selected_card_ids),
            theme_id=session.theme_id,
            date_key=date_key_jst(now_jst()),
            session_id=session.session_id,
            fallback_text=interpretation,
            spread_id=session.spread_id,
            question_text=session.question_text,
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
            spread_id=session.spread_id,
            question_text=session.question_text,
            cards=self._build_result_cards(session),
            origin_session_id=session.origin_session_id,
            combination_text=(
                self._interpretation_engine.compose_combination(
                    session.selected_card_ids[0], session.selected_card_ids[-1]
                )
                if len(session.selected_card_ids) >= 2
                else None
            ),
        )
        self._store.save_result(result)
        session.selected_card_id = card.card_id
        session.status = SessionStatus.CARD_OPENED
        self._logger.info(
            "カード確定: session_id=%s spread=%s cards=%s",
            session_id,
            session.spread_id,
            ",".join(session.selected_card_ids),
        )
        return result

    def _build_result_cards(self, session: ReadingSession) -> list[ResultCard]:
        """確定順のカードへ、スプレッドの位置（名称・意味）を割り当てる。"""
        positions = self._interpretation_engine.positions_for(
            session.spread_id, len(session.selected_card_ids)
        )
        result_cards: list[ResultCard] = []
        for index, card_id in enumerate(session.selected_card_ids):
            card = self._store.get_card(card_id)
            if card is None:
                continue
            position = positions[index] if index < len(positions) else {}
            result_cards.append(
                ResultCard(
                    card_id=card.card_id,
                    card_name=card.name_ja,
                    keywords=card.keywords,
                    position_index=int(position.get("index", index + 1)),
                    position_name=str(position.get("name", "")),
                    position_meaning=str(position.get("meaning", "")),
                    reading=card.reading,
                    attribute=card.attribute,
                    element=card.element,
                )
            )
        return result_cards

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
        # 深掘りは託宣の続きなので、履歴は**1件にまとめる**（2026-09-11 承認④）。
        # 託宣の結果で「履歴に保存」を押してから深掘りする人がいるため、
        # 単に足すと2件になる。起点の履歴があれば取り除いてから入れ直す。
        if result.origin_session_id:
            self._store.delete_history_by_session(user_id, result.origin_session_id)
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
