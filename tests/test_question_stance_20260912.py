"""問いの扱い（2026-09-12 承認）。

ご指摘: 「宝くじで1等を当てたい」に対し「お金の使い方を見直す時期」（節約）が出た。
原因は、相談内容が `質問タイプ分類` のどれにも当たらないと
**文脈テンプレを日付で選んでいた**こと＝問いを読まずに語っていた。

守りたいこと:
  - 問いがあるのに**無関係な段落を出さない**
  - 当否を語らない（抽選・確率は当人の行動では動かせない）
  - 文面の実体は**カードから引く**（属性・エレメント・キーワード）。
    マスタは判定語と型しか持たない（オーナー指示 2026-09-12）
"""

from __future__ import annotations

import pytest

from oracle_app.content_loader import load_card_content
from oracle_app.services.interpretation_engine import InterpretationEngine

LUCK_QUESTION = "宝くじで1等を当てたい"
UNMATCHED_QUESTION = "猫を飼おうか考えています"
MATCHED_QUESTION = "転職すべきか迷っています"


@pytest.fixture(scope="module")
def engine() -> InterpretationEngine:
    return InterpretationEngine(load_card_content())


@pytest.fixture(scope="module")
def three_cards(engine: InterpretationEngine) -> list[str]:
    return [f"japanese_mythology_card_{no:03d}" for no in (1, 2, 3)]


def _stance(engine: InterpretationEngine, question: str | None) -> str | None:
    _, _, _, matched = engine._classify(question, "money")
    return engine.question_stance(question, matched)


def _reading(engine: InterpretationEngine, cards: list[str], question: str | None) -> str:
    return engine.compose_reading(
        cards, "money", "2026-09-12", "ses_stance", "fb",
        spread_id="three", question_text=question,
    )


# --- 1. 区分の判定 -----------------------------------------------------------


def test_抽選の問いは運任せと判定する(engine: InterpretationEngine) -> None:
    for question in ("宝くじで1等を当てたい", "競馬で勝てますか", "抽選に申し込むべき？"):
        assert _stance(engine, question) == "運任せ", question


def test_どの質問タイプにも当たらない問いは分類外(engine: InterpretationEngine) -> None:
    assert _stance(engine, UNMATCHED_QUESTION) == "分類外"


def test_質問タイプに当たる問いは従来どおり扱う(engine: InterpretationEngine) -> None:
    assert _stance(engine, MATCHED_QUESTION) is None


def test_相談内容が無ければ扱いを決めない(engine: InterpretationEngine) -> None:
    """本日の託宣は問いが無い。無関係になりようが無いので従来どおり。"""
    assert _stance(engine, None) is None
    assert _stance(engine, "   ") is None


def test_思い当たるは当たるとして誤爆しない(engine: InterpretationEngine) -> None:
    """「当たる」を判定語にすると誤爆する。名詞だけを置いている。"""
    assert _stance(engine, "彼の言うことが思い当たる節があります") != "運任せ"


# --- 2. 問いと無関係な段落を出さない ----------------------------------------


def test_運任せの問いに節約の話が出ない(
    engine: InterpretationEngine, three_cards: list[str]
) -> None:
    """ご指摘そのもの。日付で選ばれた文脈テンプレが混ざらないこと。"""
    text = _reading(engine, three_cards, LUCK_QUESTION)
    patterns = [
        template
        for pattern in engine._patterns_by_genre.get("金運", [])
        for template in pattern.get("templates", [])
    ]
    assert patterns, "金運の文脈テンプレが読めていない"
    for template in patterns:
        head = template.split("{")[0]
        if head:
            assert head not in text, template


def test_分類外の問いでも日替わりテンプレを出さない(
    engine: InterpretationEngine, three_cards: list[str]
) -> None:
    """相談内容が変わっても、日付が同じなら同じテンプレが出る——を止めた。"""
    unmatched = _reading(engine, three_cards, UNMATCHED_QUESTION)
    daily = _reading(engine, three_cards, None)
    assert unmatched != daily


def test_質問タイプに当たる問いは従来の文章のまま(
    engine: InterpretationEngine, three_cards: list[str]
) -> None:
    """分類に当たる問いへの影響をゼロにする（退行防止）。"""
    text = _reading(engine, three_cards, MATCHED_QUESTION)
    assert "アドバイス：" in text


# --- 3. 文面の実体はカードから引く（オーナー指示）---------------------------


def test_語り口にカードの属性とエレメントが現れる(
    engine: InterpretationEngine, three_cards: list[str]
) -> None:
    text = _reading(engine, three_cards, LUCK_QUESTION)
    card = engine.card_for(three_cards[0])
    assert card["element"] in text
    assert card["name_ja"] in text


def test_助言にカードの行動提案ワードが現れる(
    engine: InterpretationEngine, three_cards: list[str]
) -> None:
    text = _reading(engine, three_cards, LUCK_QUESTION)
    last = engine.card_for(three_cards[-1])
    actions = last["keyword_dict"]["action"]
    assert any(action in text for action in actions)


def test_カードが変われば文面が変わる(engine: InterpretationEngine) -> None:
    """マスタの型は共通でも、実体はカード由来なので同じ文にならない。"""
    a = _reading(engine, [f"japanese_mythology_card_{n:03d}" for n in (1, 2, 3)], LUCK_QUESTION)
    b = _reading(engine, [f"japanese_mythology_card_{n:03d}" for n in (10, 11, 12)], LUCK_QUESTION)
    assert a != b


def test_差し込みが残らない(engine: InterpretationEngine, three_cards: list[str]) -> None:
    for question in (LUCK_QUESTION, UNMATCHED_QUESTION, MATCHED_QUESTION, None):
        text = _reading(engine, three_cards, question)
        assert "{" not in text and "}" not in text, question


def test_同じ引きなら何度でも同じ文になる(
    engine: InterpretationEngine, three_cards: list[str]
) -> None:
    first = _reading(engine, three_cards, LUCK_QUESTION)
    assert first == _reading(engine, three_cards, LUCK_QUESTION)


# --- 4. 当否を語らない -------------------------------------------------------


def test_当選の断定が禁止表現に入っている(engine: InterpretationEngine) -> None:
    """先行アプリ engine/advice_module.py L25 の規律の移植。"""
    expressions = {item["expression"] for item in engine.forbidden_expressions()}
    assert {"当選し", "当選する", "当たります", "高額当選"} <= expressions


def test_全44柱の運任せの文章が禁止表現を含まない(engine: InterpretationEngine) -> None:
    for no in range(1, 45):
        card_id = f"japanese_mythology_card_{no:03d}"
        if engine.card_for(card_id) is None:
            continue
        for question in (LUCK_QUESTION, UNMATCHED_QUESTION):
            text = engine.compose_reading(
                [card_id], "money", "2026-09-12", "ses_f", "fb",
                spread_id="daily", question_text=question,
            )
            found = engine.find_forbidden(text)
            assert not found, f"{card_id} / {question} / {found}"


def test_言い訳めいた前置きを置かない(
    engine: InterpretationEngine, three_cards: list[str]
) -> None:
    """「動かせるものではありません」等はオーナー判断で不採用（2026-09-12）。"""
    text = _reading(engine, three_cards, LUCK_QUESTION)
    for phrase in ("動かせるもの", "occurred", "ではありません。カード"):
        assert phrase not in text


# --- 5. マスタが素材を持たなくても落ちない（fail-soft）----------------------


def test_マスタが無ければ従来どおり(engine: InterpretationEngine) -> None:
    content = load_card_content()
    content["question_stances"] = []
    bare = InterpretationEngine(content)
    text = bare.compose_reading(
        ["japanese_mythology_card_001"], "money", "2026-09-12", "ses_x", "fb",
        spread_id="daily", question_text=LUCK_QUESTION,
    )
    assert text and text != "fb"
