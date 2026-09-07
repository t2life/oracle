from __future__ import annotations

import hashlib
from typing import Any

from ..logging_utils import get_logger


def _stable_hash(*parts: str) -> int:
    """プロセス間で安定する決定的ハッシュ（組込hashはシード乱数化されるため不使用）。"""
    digest = hashlib.md5("|".join(parts).encode("utf-8")).hexdigest()
    return int(digest[:8], 16)


class InterpretationEngine:
    """カードDB（44柱＋解釈素材5表）から託宣文を合成するエンジン。

    合成手順（ja・2026-09-06承認方針⑩）:
      1. テーマ→ジャンル対応（恋愛/仕事/金運/健康、潜在意識・ハイヤーセルフ→精神、他→全般）
      2. 状況はジャンル内から日替わり選定（date_key基準＝同日同カードは同文の再現性）
      3. 文脈テンプレA/B/CをセッションID基準で選定しプレースホルダを充填
      4. 質問タイプ分類の推奨トーン→感情トーン設定の文末表現で行動提案文を整形
    段落構成: [テーマ別解釈(44柱.xlsx)] + [文脈テンプレ文] + [行動提案文]

    組み合わせ解釈（compose_combination）は複数枚引きUIの実装後に配線する
    **latent実装**（単体テストで検証済み・本番からの呼出しは未配線であることを明記）。
    """

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
        self._tones_by_name = {
            tone["name"]: tone for tone in content.get("tones", [])
        }
        self._question_types: list[dict[str, Any]] = content.get("question_types", [])
        self._combination_rules: dict[tuple[str, str], dict[str, Any]] = {}
        for rule in content.get("combination_rules", []):
            self._combination_rules[(rule["attr1"], rule["attr2"])] = rule

    def card_for(self, card_id: str) -> dict[str, Any] | None:
        return self._cards_by_id.get(card_id)

    def _select_tone(self, genre: str) -> dict[str, Any] | None:
        # 質問タイプ分類のジャンル判定から推奨トーン（例:「励まし+神秘的」）の先頭を採用
        for question in self._question_types:
            if genre and genre in question.get("genre", ""):
                primary = question.get("tone", "").split("+")[0].strip()
                for name, tone in self._tones_by_name.items():
                    if primary and name.startswith(primary):
                        return tone
                break
        return self._tones_by_name.get(self._FALLBACK_TONE)

    def _fill_placeholders(self, template: str, card: dict[str, Any]) -> str:
        dictionary = card.get("keyword_dict", {})
        keywords = card.get("keywords", [])
        values = {
            "神名": card.get("name_ja", ""),
            "基本的意味": card.get("basic_meaning", ""),
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

    def _action_sentence(self, card: dict[str, Any], genre: str, seed: int) -> str:
        actions = card.get("keyword_dict", {}).get("action", [])
        if not actions:
            return ""
        action = actions[seed % len(actions)]
        tone = self._select_tone(genre)
        if tone and tone.get("endings"):
            ending = tone["endings"][seed % len(tone["endings"])].lstrip("〜")
            return f"今日の行動提案：{action}ことで、{ending}。"
        return f"今日の行動提案：{action}。"

    def compose_ja(
        self,
        card_id: str,
        theme_id: str,
        date_key: str,
        session_id: str,
        fallback_text: str,
    ) -> str:
        """日本語の託宣文を合成する。素材不足時はfallback_textを返す（fail-soft）。"""
        card = self._cards_by_id.get(card_id)
        if card is None:
            return fallback_text

        genre = self.THEME_TO_GENRE.get(theme_id, self._FALLBACK_GENRE)
        patterns = self._patterns_by_genre.get(genre) or self._patterns_by_genre.get(
            self._FALLBACK_GENRE, []
        )

        paragraphs: list[str] = []
        theme_meaning = card.get("theme_meanings", {}).get(theme_id)
        if theme_meaning:
            paragraphs.append(theme_meaning)

        if patterns:
            # 状況=日替わり（date_key×テーマ）・テンプレA/B/C=セッション基準で決定的に選ぶ
            situation_seed = _stable_hash(date_key, theme_id)
            pattern = patterns[situation_seed % len(patterns)]
            templates = pattern.get("templates", [])
            if templates:
                template_seed = _stable_hash(session_id, card_id)
                template = templates[template_seed % len(templates)]
                paragraphs.append(self._fill_placeholders(template, card))

        action = self._action_sentence(
            card, genre, _stable_hash(date_key, card_id)
        )
        if action:
            paragraphs.append(action)

        if not paragraphs:
            return fallback_text
        return "\n\n".join(paragraphs)

    def compose_combination(
        self,
        card_id_a: str,
        card_id_b: str,
    ) -> str | None:
        """2枚のカード間の組み合わせ解釈（複数枚引きUI実装後に配線するlatent機能）。

        照合はエレメント同士→属性分類同士の順（順不同）。一致無しはNone（省略）。
        """
        card_a = self._cards_by_id.get(card_id_a)
        card_b = self._cards_by_id.get(card_id_b)
        if card_a is None or card_b is None:
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
