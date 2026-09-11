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
        # 2026-09-11 託宣文に現れてはならない表現（マスタ「禁止表現マスタ」）。
        # 出所は先行アプリ（吉凶羅針盤）が生成AIを採らない代わりに置いた
        # `FORTUNE_FORBIDDEN_ASSERTIONS`。本アプリも同じ判断をしたため規律も揃える。
        # 無い環境でも従来どおり動く（fail-soft）。
        self._forbidden_expressions: list[dict[str, Any]] = content.get(
            "forbidden_expressions", []
        )
        # 2026-09-11 番号解釈（エレメント→時間の単位、番号→数量）。
        self._number_readings: dict[str, dict[str, Any]] = {
            str(item["element"]): item
            for item in content.get("number_readings", [])
        }
        self._number_question_keywords: list[dict[str, Any]] = content.get(
            "number_question_keywords", []
        )
        # 2026-09-11 位置ごとの語り口。全位置で同じ文末だと「一覧を読み上げた」
        # 印象になるため、位置（時制）ごとに言い方を変える。
        self._position_voices: dict[str, list[str]] = content.get(
            "position_voices", {}
        )
        # 2026-09-12 問いの扱い。区分 → 判定語と、語り口・助言の**型**。
        # 型に差し込む語は全てカード側から取るため、ここにカードの中身は無い。
        self._question_stances: dict[str, dict[str, Any]] = {
            str(entry.get("kind", "")): entry
            for entry in content.get("question_stances", [])
            if entry.get("kind")
        }

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
    ) -> tuple[str, str | None, dict[str, Any] | None, bool]:
        """相談内容からジャンル・状況・トーン・**一致したか**を判定する。

        相談内容が無い場合は従来どおりテーマ→ジャンルのみで、状況はNone
        （呼び出し側が日替わりで選ぶ）。

        第4要素は「質問タイプ分類のどれかに当たったか」。2026-09-12 追加。
        当たらないまま日付でテンプレを選ぶと**問いと無関係な段落**になるため、
        呼び出し側がこれを見て出し分ける。
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
                    True,
                )
        return theme_genre, None, self._tone_for_genre(theme_genre), False

    _STANCE_LUCK = "運任せ"
    _STANCE_UNMATCHED = "分類外"

    def question_stance(self, question_text: str | None, matched: bool) -> str | None:
        """問いの扱いを返す（`運任せ` / `分類外` / なし）。

        - `運任せ` … 抽選・確率など、当人の行動では動かせない問い。
          当否は語らず、カードそのものを語って直感へ委ねる。
        - `分類外` … どの `質問タイプ分類` にも当たらなかった問い。
          **従来はここで文脈テンプレを日付で選んでいた**（＝問いを読まずに語る）。

        相談内容が無いとき（本日の託宣）は None。問いが無ければ無関係にならないため、
        従来どおり日替わりのテンプレでよい。
        """
        question = (question_text or "").strip()
        if not question:
            return None
        luck = self._question_stances.get(self._STANCE_LUCK)
        if luck and any(
            keyword and keyword in question for keyword in luck.get("keywords", [])
        ):
            return self._STANCE_LUCK
        if not matched and self._STANCE_UNMATCHED in self._question_stances:
            return self._STANCE_UNMATCHED
        return None

    def compose_stance_paragraphs(
        self, stance: str, cards: list[dict[str, Any]], seed_key: str
    ) -> tuple[str, str]:
        """問いの扱いに沿った「語り口」「助言」を返す（素材が無ければ空文字）。

        語り口は1枚目、助言は最後の1枚から作る（置き換える段落と同じ出どころ）。
        同じ引きなら何度でも同じ文になるよう決定的に選ぶ。
        """
        entry = self._question_stances.get(stance)
        if not entry or not cards:
            return "", ""
        voices = entry.get("voices", [])
        advices = entry.get("advices", [])
        first, last = cards[0], cards[-1]
        voice = ""
        advice = ""
        if voices:
            index = _stable_hash(seed_key, first.get("card_id", "")) % len(voices)
            voice = self._fill_placeholders(voices[index], first)
        if advices:
            index = _stable_hash(seed_key, last.get("card_id", "")) % len(advices)
            advice = self._fill_placeholders(advices[index], last)
        return voice, advice

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
            # 2026-09-12 追加。問いの扱いの型が属性・エレメントを語るため
            # （文面の実体はカードから引く、というオーナー指示）。
            "属性": card.get("attribute", ""),
            "エレメント": card.get("element", ""),
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
        position_name = "本日の一枚" if position is None else str(
            position.get("name", "")
        )
        voices = self._position_voices.get(position_name) or []
        if voices:
            # 同じ位置でもカードごとに言い方が変わるよう決定的に選ぶ
            # （同じ引きなら何度でも同じ文になる）。
            voice = voices[_stable_hash(card.get("card_id", ""), position_name)
                           % len(voices)]
            return (
                voice.replace("{name}", name)
                .replace("{phrase}", phrase)
                .replace("{meaning}", str((position or {}).get("meaning", "")))
            )
        # 語り口が未整備の位置は従来の言い方へ落ちる（fail-soft）。
        # 素材は体言止めと動詞句が混在するため、どちらでも収まる受け皿にする。
        if single or position is None:
            return f"{name}は、{phrase}、といった意味を帯びています。"
        return (
            f"【{position.get('name', '')}】{name}。"
            f"{position.get('meaning', '')}には、{phrase}、という意味合いが示されています。"
        )

    # ------------------------------------------------------------------ 合成
    # -------------------------------------------------------------- 番号の読み
    def number_question_kind(self, question_text: str | None) -> str | None:
        """相談内容が期日・数量を問うているか。問うていなければ None。

        ★オラクルは自由解釈が基本で、**常に数字を語るのはデッキの性格に合わない**
        （WEB調査・2026-09-11）。問われたときだけ答える。
        判定語はマスタ「番号解釈キーワード」が単一真実源。
        """
        question = (question_text or "").strip()
        if not question:
            return None
        # 「時期」を先に見る。「何日で終わりますか」のように両方に触れる問いは
        # 時期として読むほうが自然なため（順序そのものが仕様）。
        for kind in ("時期", "数量"):
            for entry in self._number_question_keywords:
                if entry.get("kind") != kind:
                    continue
                keyword = str(entry.get("keyword", "")).strip()
                if keyword and keyword in question:
                    return kind
        return None

    def compose_number_reading(
        self, cards: list[dict[str, Any]], question_text: str | None
    ) -> str | None:
        """番号から時期・数量の一文を作る。問われていなければ None。

        単位はエレメントが決め、数は番号が決める（タロットの確立した手順を移植）。
        複数枚では**エレメントの最頻**で単位を決め、同数なら遅いほうを採る
        （外して落胆させるより、遅めに言う）。
        """
        kind = self.number_question_kind(question_text)
        if kind is None or not cards or not self._number_readings:
            return None

        reading = self._number_readings.get(self._dominant_element(cards))
        if reading is None:
            return None

        # 数は「そのポジションの主役」＝最後に引いた札（未来を指す位置）を使う。
        number = int(cards[-1].get("no") or 0)
        if number <= 0:
            return None

        if kind == "数量":
            template = str(reading.get("quantity_template", ""))
            return template.replace("{n}", str(number)) if template else None

        unit = str(reading.get("unit", ""))
        limit = int(reading.get("max_value") or 0)
        # 単位が無い（エーテル）＝期日を定めない。上限超えも幅のある言い方へ。
        if not unit or (limit > 0 and number > limit):
            template = str(reading.get("over_template", ""))
            return template or None
        template = str(reading.get("template", ""))
        if not template:
            return None
        return template.replace("{n}", str(number)).replace("{unit}", unit)

    # 遅い単位ほど後ろ。最頻が割れたときはより遅いほうを採る。
    _ELEMENT_ORDER = ("火", "風", "水", "地", "エーテル")

    def _dominant_element(self, cards: list[dict[str, Any]]) -> str:
        counts: dict[str, int] = {}
        for card in cards:
            element = str(card.get("element") or "")
            if element:
                counts[element] = counts.get(element, 0) + 1
        if not counts:
            return ""
        best = max(counts.values())
        tied = [element for element, count in counts.items() if count == best]
        # 同数なら遅いほう（_ELEMENT_ORDER の後ろ）を採る
        tied.sort(key=lambda element: self._ELEMENT_ORDER.index(element)
                  if element in self._ELEMENT_ORDER else -1)
        return tied[-1]

    # ------------------------------------------------------------ 表現の検査
    def forbidden_expressions(self) -> list[dict[str, Any]]:
        """託宣文に現れてはならない表現（マスタ由来）。"""
        return list(self._forbidden_expressions)

    def find_forbidden(self, text: str, tone_name: str | None = None) -> list[str]:
        """禁止表現の検査。触れた表現を全て返す（空リスト＝問題なし）。

        ★人のレビューに頼らない。語はマスタが単一真実源で、コードに直書きしない。
        健康の治癒・金銭の増減・恐怖訴求・保証と読める語を機械で止めるための検査で、
        素材（44柱.xlsx）へ不用意な語が入ったときにテストが落ちる。

        [tone_name] を渡すと、そのトーンの「避けるべき表現」も併せて見る。
        """
        hits: list[str] = []
        for entry in self.forbidden_expressions():
            expression = str(entry.get("expression", "")).strip()
            if expression and expression in text:
                hits.append(expression)
        if tone_name:
            tone = self._tones_by_name.get(tone_name)
            for avoid in (tone or {}).get("avoid", []):
                # マスタの「避けるべき表現」は「〜できません」の形で波ダッシュを含む
                needle = str(avoid).lstrip("〜～").strip()
                if needle and needle in text and needle not in hits:
                    hits.append(needle)
        return hits

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

        genre, situation, tone, matched = self._classify(question_text, theme_id)
        stance = self.question_stance(question_text, matched)
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

        # 4. 文脈テンプレ／問いの扱い
        #
        # 相談内容が `質問タイプ分類` のどれにも当たらないと、従来はここで
        # **日付でテンプレを選んで**いた（宝くじの問いに節約の話が出た原因）。
        # 問いを読まずに語るくらいなら、カードそのものを語って直感へ委ねる。
        stance_voice, stance_advice = (
            self.compose_stance_paragraphs(stance, cards, session_id)
            if stance
            else ("", "")
        )
        if stance_voice:
            paragraphs.append(stance_voice)
        else:
            patterns = self._patterns_by_genre.get(
                genre
            ) or self._patterns_by_genre.get(self._FALLBACK_GENRE, [])
            pattern = None
            if patterns:
                if situation:
                    pattern = next(
                        (
                            item
                            for item in patterns
                            if item.get("situation") == situation
                        ),
                        None,
                    )
                if pattern is None and not stance:
                    # 問いが無い（本日の託宣）ときだけ日替わりで選ぶ。
                    # 問いがあるのに無関係な段落を出さないための条件。
                    pattern = patterns[_stable_hash(date_key, theme_id) % len(patterns)]
            if pattern:
                templates = pattern.get("templates", [])
                if templates:
                    template = templates[
                        _stable_hash(session_id, cards[0]["card_id"]) % len(templates)
                    ]
                    paragraphs.append(self._fill_placeholders(template, cards[0]))

        # 4.5 番号の読み（期日・数量を問われたときだけ）
        number_reading = self.compose_number_reading(cards, question_text)
        if number_reading:
            paragraphs.append(number_reading)

        # 5. 行動提案 → 6. 締め
        # 問いの扱いがある場合、助言も同じ型から作る（同じ語を二度言わない）。
        action = stance_advice or self._action_sentence(
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
            "託宣文を合成: 枚数=%s spread=%s genre=%s 状況=%s トーン=%s 扱い=%s",
            len(cards),
            spread_id,
            genre,
            situation,
            (tone or {}).get("name"),
            stance,
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
                # ★素材の欄名をそのまま文章へ出さない（2026-09-11）。
                # 「（鍵となる言葉: …）」は表の見出しであって、占い師の言葉ではない。
                # 位置別の語り口と同じ理由で、読み手に地の文として届く形へ直す。
                direction = str(rule.get("direction", "")).strip()
                if direction and not direction.endswith(("。", "．", "！", "？")):
                    direction += "。"
                keywords = "・".join(rule.get("keywords", [])[:3])
                text = (
                    f"{card_a['name_ja']}と{card_b['name_ja']}は"
                    f"「{rule.get('interaction', '')}」の関係にあります。"
                    f"{direction}"
                )
                if keywords:
                    text += f"この巡り合わせを言葉にするなら、{keywords}です。"
                return text
        return None
