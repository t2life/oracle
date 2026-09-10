"""託宣文の3層合成（2026-09-10 承認方針§4.3）の検証。

観点:
  - マスタ（スプレッド定義・ポジション定義・接続表現・テーマジャンル対応）が読み込まれる
  - 複数枚リーディングで位置名・位置の意味が段落に反映される
  - 2枚以上のとき組み合わせ解釈が本配線される（従来はlatent）
  - 相談内容の有無でトーン（導入句・締め句）が切り替わる
  - 体言止めの素材が文へ埋め込まれ、句点の連続が残らない
  - 決定性（同じ入力→同じ文）と fail-soft（未知カード→fallback）
"""

from __future__ import annotations

from oracle_app.content_loader import load_card_content
from oracle_app.services.interpretation_engine import InterpretationEngine

CARD_A = "japanese_mythology_card_001"
CARD_B = "japanese_mythology_card_007"
CARD_C = "japanese_mythology_card_021"


def _engine() -> InterpretationEngine:
    return InterpretationEngine(load_card_content())


def test_master_tables_are_loaded() -> None:
    content = load_card_content()
    assert len(content["spreads"]) == 5
    assert content["theme_genres"]["subconscious"] == "精神"
    assert len(content["connectors"]) == 10
    # 3枚スプレッドは過去・現在・未来の3ポジションを持つ
    three = content["positions"]["three"]
    assert [item["name"] for item in three] == ["過去", "現在", "未来"]


def test_spread_definition_matches_billing_policy() -> None:
    """承認内容: リーディングは一律5枚消費・無料ユーザーは託宣のみ。"""
    engine = _engine()
    daily = engine.spread_for("daily")
    assert daily is not None
    assert daily["required_tickets"] == 0
    assert "free" in daily["allowed_plans"]

    for spread_id in ("three", "five", "seven", "free"):
        spread = engine.spread_for(spread_id)
        assert spread is not None, spread_id
        assert spread["required_tickets"] == 5, spread_id
        assert "free" not in spread["allowed_plans"], spread_id


def test_positions_are_filled_for_free_spread() -> None:
    """フリーは枚数可変。定義が足りない枚数は汎用名で補われる。"""
    engine = _engine()
    positions = engine.positions_for("free", 3)
    assert len(positions) == 3
    assert positions[0]["name"] == "一枚目"


def test_multi_card_reading_uses_positions_and_combination() -> None:
    engine = _engine()
    text = engine.compose_reading(
        card_ids=[CARD_A, CARD_B, CARD_C],
        theme_id="work",
        date_key="2026-09-10",
        session_id="ses_multi",
        fallback_text="fallback",
        spread_id="three",
        question_text="転職すべきか迷っています。",
    )
    # 位置名が段落見出しとして入る
    for label in ("【過去】", "【現在】", "【未来】"):
        assert label in text
    # 組み合わせ解釈（従来latent）が本配線されている
    assert "組み合わせは" in text
    # 相談内容が導入で受け止められている
    assert "という問いに" in text
    assert "{" not in text and "}" not in text


def test_question_text_switches_tone() -> None:
    """相談内容から質問タイプを判定し、導入句・締め句が変わる。"""
    engine = _engine()
    common = {
        "card_id": CARD_B,
        "theme_id": "love",
        "date_key": "2026-09-10",
        "session_id": "ses_tone",
        "fallback_text": "fallback",
    }
    without = engine.compose_ja(**common)
    with_question = engine.compose_ja(
        **common,
        question_text="彼との関係が上手くいきません。別れるべきか悩んでいます。",
    )
    assert without != with_question
    assert "という問いに" in with_question


def test_taigen_dome_material_is_smoothed() -> None:
    """体言止めの列挙が文へ埋め込まれ、句点の連続が残らない。"""
    engine = _engine()
    text = engine.compose_ja(
        card_id="japanese_mythology_card_032",
        theme_id="work",
        date_key="2026-09-10",
        session_id="ses_smooth",
        fallback_text="fallback",
    )
    assert "、といった意味を帯びています。" in text
    for paragraph in text.split("\n\n"):
        assert "。。" not in paragraph
        assert paragraph.endswith(("。", "！", "？")), paragraph


def test_deterministic_and_fail_soft() -> None:
    engine = _engine()
    args = {
        "card_ids": [CARD_A, CARD_B],
        "theme_id": "money",
        "date_key": "2026-09-10",
        "session_id": "ses_det",
        "fallback_text": "fallback",
        "spread_id": "three",
    }
    assert engine.compose_reading(**args) == engine.compose_reading(**args)
    assert (
        engine.compose_reading(
            **{**args, "card_ids": ["unknown_card_001"]},
        )
        == "fallback"
    )
