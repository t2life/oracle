from __future__ import annotations

import hashlib
import re
from typing import Any

from ..logging_utils import get_logger


def _stable_hash(*parts: str) -> int:
    """プロセス間で安定する決定的ハッシュ（組込hashはシード乱数化されるため不使用）。"""
    digest = hashlib.md5("|".join(parts).encode("utf-8")).hexdigest()
    return int(digest[:8], 16)


class InterpretationEngine:
    """カードDB（44柱＋解釈素材9表）から託宣文を合成するエンジン。

    合成は3層（2026-09-10 承認方針§4.3）:
      素材層 … カードの基本的意味・テーマ別解釈・4系キーワード・組み合わせルール
      構成層 … 相談内容→質問タイプ分類でジャンル/状況/トーンを判定し、
               スプレッドのポジション（位置の意味・文中での役割）で段落順を決める
      文体層 … 感情トーン設定の文末表現と接続表現マスタで段落を繋ぎ、
               体言止めの素材を文章体へ整える

    単数引き（本日の託宣）と複数枚リーディングは同じ [compose_reading] で組み立てる。
    [compose_ja] は既存API互換のための1枚版の入口で、内部は同一実装へ委譲する。
    """

    # DBに「テーマジャンル対応」が無い旧データ用のフォールバック（通常はDB側が正）。
    THEME_TO_GENRE = {
        "love": "恋愛",
        "work": "仕事",
        "money": "金運",
        "health": "健康",
        "subconscious": "精神",
        "higher_self": "精神",
    }
    _FALLBACK_GENRE = "全般"
    _FALLBACK_TONE = "中立トーン"

    def __init__(self, content: dict[str, Any]) -> None:
        self._logger = get_logger(self.__class__.__name__)
        self._cards_by_id: dict[str, dict[str, Any]] = {
            card["card_id"]: card for card in content.get("cards", [])
        }
        self._patterns_by_genre: dict[str, list[dict[str, Any]]] = {}
        for pattern in content.get("context_patterns", []):
            self._patterns_by_genre.setdefault(pattern["genre"], []).append(pattern)
        self._tones_by_name = {tone["name"]: tone for tone in content.get("tones", [])}
        self._question_types: list[dict[str, Any]] = sorted(
            content.get("question_types", []),
            key=lambda item: item.get("priority", 999),
        )
        self._combination_rules: dict[tuple[str, str], dict[str, Any]] = {}
        for rule in content.get("combination_rules", []):
            self._combination_rules[(rule["attr1"], rule["attr2"])] = rule
        # 2026-09-10 追加のマスタ（無い場合も従来どおり動く＝fail-soft）
        self._spreads: dict[str, dict[str, Any]] = {
            spread["spread_id"]: spread for spread in content.get("spreads", [])
        }
        self._positions: dict[str, list[dict[str, Any]]] = content.get("positions", {})
        self._connectors: dict[str, dict[str, Any]] = {
            item["tone"]: item for item in content.get("connectors", [])
        }
        self._theme_genres: dict[str, str] = content.get("theme_genres", {})

    # ------------------------------------------------------------------ 参照系
    def card_for(self, card_id: str) -> dict[str, Any] | None:
        return self._cards_by_id.get(card_id)

    def spread_for(self, spread_id: str) -> dict[str, Any] | None:
        return self._spreads.get(spread_id)

    def spreads(self) -> list[dict[str, Any]]:
        """スプレッド定義の一覧（選択画面と事前提示に使う）。"""
        return list(self._spreads.values())

    def positions_for(self, spread_id: str, card_count: int) -> list[dict[str, Any]]:
        """スプレッドの位置定義。定義が足りない場合は枚数ぶんを汎用名で補う。"""
        defined = list(self._positions.get(spread_id, []))
        if len(defined) >= card_count:
            return defined[:card_count]
        for index in range(len(defined), card_count):
            defined.append(
                {
                    "index": index + 1,
                    "name": f"{index + 1}枚目",
                    "meaning": "問いに寄せられたメッセージ",
                    "role": "展開として補足を述べる",
                }
            )
        return defined

    # ------------------------------------------------------------------ 構成層
    def _genre_for_theme(self, theme_id: str) -> str:
        return (
            self._theme_genres.get(theme_id)
            or self.THEME_TO_GENRE.get(theme_id)
            or self._FALLBACK_GENRE
        )

    def _classify(
        self, question_text: str | None, theme_id: str
    ) -> tuple[str, str | None, dict[str, Any] | None]:
        """相談内容からジャンル・状況・トーンを判定する。

        相談内容が無い場合は従来どおりテーマ→ジャンルのみで、状況はNone
        （呼び出し側が日替わりで選ぶ）。
        """
        theme_genre = self._genre_for_theme(theme_id)
        question = (question_text or "").strip()
        if question:
            best: tuple[int, dict[str, Any]] | None = None
            for entry in self._question_types:
                hits = sum(
                    1
                    for keyword in entry.get("keywords", [])
                    if keyword and keyword in question
                )
                if hits == 0:
                    continue
                # テーマと同じジャンルの候補を優先（同点時の決定性も担保）
                score = hits * 2 + (1 if entry.get("genre") == theme_genre else 0)
                if best is None or score > best[0]:
                    best = (score, entry)
            if best is not None:
                entry = best[1]
                situations = entry.get("situations") or []
                situation = situations[0] if situations else entry.get("situation")
                return (
                    entry.get("genre") or theme_genre,
                    situation or None,
                    self._tone_by_label(entry.get("tone", "")),
                )
        return theme_genre, None, self._tone_for_genre(theme_genre)

    def _tone_by_label(self, label: str) -> dict[str, Any] | None:
        """「励まし+神秘的」のような推奨トーン表記から先頭のトーンを引く。"""
        primary = (label or "").split("+")[0].strip()
        if primary:
            for name, tone in self._tones_by_name.items():
                if name.startswith(primary):
                    return tone
        return self._tones_by_name.get(self._FALLBACK_TONE)

    def _tone_for_genre(self, genre: str) -> dict[str, Any] | None:
        for entry in self._question_types:
            if genre and genre in entry.get("genre", ""):
                return self._tone_by_label(entry.get("tone", ""))
        return self._tones_by_name.get(self._FALLBACK_TONE)

    # ------------------------------------------------------------------ 文体層
    @staticmethod
    def _as_phrase(text: str) -> str:
        """体言止めの列挙（「A。B。C。」）を、文へ埋め込める句（「A、B、C」）にする。"""
        cleaned = re.sub(r"[。．]\s*$", "", (text or "").strip())
        return re.sub(r"[。．]\s*", "、", cleaned).rstrip("、")

    def _connector(self, tone: dict[str, Any] | None) -> dict[str, Any]:
        name = (tone or {}).get("name", self._FALLBACK_TONE)
        return self._connectors.get(name) or self._connectors.get(
            self._FALLBACK_TONE, {}
        )

    def _fill_placeholders(self, template: str, card: dict[str, Any]) -> str:
        dictionary = card.get("keyword_dict", {})
        keywords = card.get("keywords", [])
        values = {
            "神名": card.get("name_ja", ""),
            "基本的意味": self._as_phrase(card.get("basic_meaning", "")),
            "キーワード": "・".join(keywords[:2]) if keywords else card.get("basic_meaning", ""),
            "肯定的キーワード": "・".join(dictionary.get("positive", [])[:2]),
            "否定的キーワード": "・".join(dictionary.get("negative", [])[:2]),
            "中立的キーワード": "・".join(dictionary.get("neutral", [])[:2]),
            "行動提案ワード": "・".join(dictionary.get("action", [])[:2]),
        }
        text = template
        for key, value in values.items():
            text = text.replace("{" + key + "}", value)
        return text

    def _action_sentence(
        self, card: dict[str, Any], tone: dict[str, Any] | None, seed: int
    ) -> str:
        """行動提案。

        「感情トーン設定」の文末表現は*文の結び*の見本であり、
        「{action}ことで、{ending}」の形に差し込むと
        「転換することで、実行します」のように主語がねじれる。
        よって行動提案は独立した一文に固定し、トーンの差は
        接続表現マスタの締め句（[compose_reading] の最終段落）で出す。
        """
        actions = card.get("keyword_dict", {}).get("action", [])
        if not actions:
            return ""
        action = actions[seed % len(actions)]
        return f"アドバイス：{action}ことを意識してみてください。"

    def _card_paragraph(
        self,
        card: dict[str, Any],
        theme_id: str,
        position: dict[str, Any] | None,
        single: bool,
    ) -> str:
        """1枚ぶんの段落。位置がある場合は位置名と位置の意味を織り込む。"""
        meaning = card.get("theme_meanings", {}).get(theme_id) or card.get(
            "basic_meaning", ""
        )
        phrase = self._as_phrase(meaning)
        name = card.get("name_ja", "")
        # 素材は体言止めと動詞句が混在するため、どちらでも収まる受け皿にする。
        if single or position is None:
            return f"{name}は、{phrase}、といった意味を帯びています。"
        return (
            f"【{position.get('name', '')}】{name}。"
            f"{position.get('meaning', '')}には、{phrase}、という意味合いが示されています。"
        )

    # ------------------------------------------------------------------ 合成
    def compose_reading(
        self,
        card_ids: list[str],
        theme_id: str,
        date_key: str,
        session_id: str,
        fallback_text: str,
        spread_id: str = "daily",
        question_text: str | None = None,
    ) -> str:
        """1枚〜N枚の託宣文を合成する。素材不足時はfallback_textを返す（fail-soft）。"""
        cards = [
            card
            for card in (self._cards_by_id.get(card_id) for card_id in card_ids)
            if card is not None
        ]
        if not cards:
            return fallback_text

        genre, situation, tone = self._classify(question_text, theme_id)
        connector = self._connector(tone)
        positions = self.positions_for(spread_id, len(cards))
        single = len(cards) == 1

        paragraphs: list[str] = []

        # 1. 導入（相談内容があれば問いを受け止める一文にする）
        opening = connector.get("opening", "")
        question = (question_text or "").strip()
        if opening:
            if question:
                summary = question if len(question) <= 40 else f"{question[:40]}…"
                paragraphs.append(f"「{summary}」という問いに、{opening}、次の流れです。")
            else:
                paragraphs.append(f"{opening}、次の流れです。")

        # 2. 各カード（位置の意味に沿って述べる）
        for index, card in enumerate(cards):
            position = positions[index] if index < len(positions) else None
            paragraphs.append(self._card_paragraph(card, theme_id, position, single))

        # 3. 組み合わせ解釈（2枚以上のときだけ。従来latentだった素材の本配線）
        if len(cards) >= 2:
            combination = self.compose_combination(
                cards[0]["card_id"], cards[-1]["card_id"]
            )
            if combination:
                linking = connector.get("linking", "")
                paragraphs.append(
                    f"{linking}、{combination}" if linking else combination
                )

        # 4. 文脈テンプレ（状況は相談内容から、無ければ日替わりで決定的に選ぶ）
        patterns = self._patterns_by_genre.get(genre) or self._patterns_by_genre.get(
            self._FALLBACK_GENRE, []
        )
        pattern = None
        if patterns:
            if situation:
                pattern = next(
                    (item for item in patterns if item.get("situation") == situation),
                    None,
                )
            if pattern is None:
                pattern = patterns[_stable_hash(date_key, theme_id) % len(patterns)]
        if pattern:
            templates = pattern.get("templates", [])
            if templates:
                template = templates[
                    _stable_hash(session_id, cards[0]["card_id"]) % len(templates)
                ]
                paragraphs.append(self._fill_placeholders(template, cards[0]))

        # 5. 行動提案 → 6. 締め
        action = self._action_sentence(
            cards[-1], tone, _stable_hash(date_key, cards[-1]["card_id"])
        )
        if action:
            paragraphs.append(action)
        closing = connector.get("closing", "")
        if closing:
            paragraphs.append(closing)

        if not paragraphs:
            return fallback_text
        self._logger.debug(
            "託宣文を合成: 枚数=%s spread=%s genre=%s 状況=%s トーン=%s",
            len(cards),
            spread_id,
            genre,
            situation,
            (tone or {}).get("name"),
        )
        return "\n\n".join(paragraphs)

    def compose_ja(
        self,
        card_id: str,
        theme_id: str,
        date_key: str,
        session_id: str,
        fallback_text: str,
        question_text: str | None = None,
    ) -> str:
        """1枚引きの入口（既存API互換）。実体は [compose_reading] と同一。"""
        return self.compose_reading(
            card_ids=[card_id],
            theme_id=theme_id,
            date_key=date_key,
            session_id=session_id,
            fallback_text=fallback_text,
            spread_id="daily",
            question_text=question_text,
        )

    def compose_combination(
        self,
        card_id_a: str,
        card_id_b: str,
    ) -> str | None:
        """2枚のカード間の組み合わせ解釈。

        照合はエレメント同士→属性分類同士の順（順不同）。一致無しはNone（省略）。
        """
        card_a = self._cards_by_id.get(card_id_a)
        card_b = self._cards_by_id.get(card_id_b)
        if card_a is None or card_b is None or card_a is card_b:
            return None

        candidates = [
            (card_a.get("element", ""), card_b.get("element", "")),
            (card_a.get("attribute", ""), card_b.get("attribute", "")),
        ]
        for key_a, key_b in candidates:
            rule = self._combination_rules.get((key_a, key_b)) or self._combination_rules.get(
                (key_b, key_a)
            )
            if rule:
                keywords = "・".join(rule.get("keywords", [])[:3])
                text = (
                    f"{card_a['name_ja']}と{card_b['name_ja']}の組み合わせは"
                    f"「{rule.get('interaction', '')}」の関係です。"
                    f"{rule.get('direction', '')}"
                )
                if keywords:
                    text += f"（鍵となる言葉: {keywords}）"
                return text
        return None
