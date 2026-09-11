"""カード番号の読み（2026-09-11 承認）。

WEB調査の結論:
  - オラクルデッキに標準の数秘体系は無く、意味づけは制作者が決めてよい。
  - タロットの期日の読みは「スート＝時間の単位／数字＝数量」で定型化している。
∴ 本デッキが既に持つ**エレメント**をスートに置き、確立した手順を移植した。

守りたいこと:
  - **問われたときだけ**数字を語る（常時は語らない＝オラクルの作法）
  - 単位はエレメント、数は番号
  - 年数などが非現実的にならないよう、上限を超えたら幅で述べる
"""

from __future__ import annotations

import pytest

from oracle_app.content_loader import load_card_content
from oracle_app.services.interpretation_engine import InterpretationEngine


@pytest.fixture(scope="module")
def engine() -> InterpretationEngine:
    return InterpretationEngine(load_card_content())


def _card(engine: InterpretationEngine, no: int) -> dict:
    return engine.card_for(f"japanese_mythology_card_{no:03d}")


def test_master_holds_the_table(engine: InterpretationEngine) -> None:
    """対応表はマスタが持つ（コードに直書きしない）。"""
    assert len(engine._number_readings) == 5
    assert set(engine._number_readings) == {"火", "風", "水", "地", "エーテル"}
    assert engine._number_readings["火"]["unit"] == "日"
    assert engine._number_readings["地"]["unit"] == "年"
    assert engine._number_readings["エーテル"]["unit"] == ""


@pytest.mark.parametrize(
    "question, expected",
    [
        ("いつごろ転職すべきですか", "時期"),
        ("どのくらいで結果が出ますか", "時期"),
        ("何人と出会えますか", "数量"),
        ("彼の気持ちが知りたい", None),
        ("転職すべきか迷っています", None),
        ("", None),
        (None, None),
    ],
)
def test_only_speaks_when_asked(
    engine: InterpretationEngine, question: str | None, expected: str | None
) -> None:
    """期日・数量を問われたときだけ数字を語る。"""
    assert engine.number_question_kind(question) == expected


def test_element_decides_the_unit(engine: InterpretationEngine) -> None:
    # No.6 須佐之男命 = 風 → 週
    text = engine.compose_number_reading([_card(engine, 6)], "いつごろですか")
    assert text is not None
    assert "6週" in text

    # No.2 高御産巣日神 = 火 → 日
    text = engine.compose_number_reading([_card(engine, 2)], "いつごろですか")
    assert "2日" in text


def test_aether_does_not_give_a_date(engine: InterpretationEngine) -> None:
    """根源の3柱は期日を定めない（大アルカナと同じ扱い）。"""
    text = engine.compose_number_reading([_card(engine, 1)], "いつごろですか")
    assert text is not None
    assert "時期は定まっていません" in text


def test_over_the_limit_uses_a_range(engine: InterpretationEngine) -> None:
    """上限を超える数は「40年」のような非現実的な言い方をしない。"""
    earth = [
        card
        for card in load_card_content()["cards"]
        if card["element"] == "地" and card["no"] > 10
    ]
    assert earth, "地で上限(10)を超える番号のカードが無い"
    text = engine.compose_number_reading([earth[-1]], "いつごろですか")
    assert text is not None
    assert "年" not in text or "長い目" in text
    assert str(earth[-1]["no"]) not in text


def test_multiple_cards_take_the_slower_unit_on_a_tie(
    engine: InterpretationEngine,
) -> None:
    """最頻が割れたら遅いほうを採る（外して落胆させるより遅めに言う）。"""
    # 火1枚・地1枚 → 同数。地（年）を採る。
    fire = next(c for c in load_card_content()["cards"] if c["element"] == "火")
    earth = next(
        c for c in load_card_content()["cards"] if c["element"] == "地" and c["no"] <= 10
    )
    text = engine.compose_number_reading([fire, earth], "いつごろですか")
    assert text is not None
    assert f"{earth['no']}年" in text


def test_quantity_uses_the_number(engine: InterpretationEngine) -> None:
    text = engine.compose_number_reading([_card(engine, 6)], "何人と出会えますか")
    assert text is not None
    assert "6" in text


def test_reading_text_includes_it_only_when_asked(
    engine: InterpretationEngine,
) -> None:
    """託宣文の段落として入るのは、問われたときだけ。"""
    common = {
        "card_ids": ["japanese_mythology_card_006"],
        "theme_id": "work",
        "date_key": "2026-09-11",
        "session_id": "s",
        "fallback_text": "",
        "spread_id": "daily",
    }
    asked = engine.compose_reading(**common, question_text="いつごろ動くべきですか")
    not_asked = engine.compose_reading(**common, question_text="転職すべきでしょうか")

    assert "時期でいえば" in asked
    assert "時期でいえば" not in not_asked


def test_number_reading_passes_the_forbidden_check(
    engine: InterpretationEngine,
) -> None:
    """期日の言い回しが「必ず」「絶対」を含まないこと（断定しない）。"""
    for card in load_card_content()["cards"]:
        for question in ("いつごろですか", "何人ですか"):
            text = engine.compose_number_reading([card], question)
            if text:
                assert engine.find_forbidden(text) == [], text
