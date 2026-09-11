"""ルビ・羅列の解消・結論を先に述べる（2026-09-12 承認 ア／ウ第1段）。

ご指摘:
  ①神名にルビが無い（本文・組み合わせ解釈）
  ②質問への回答が完結せず、マスタやカードのキーワードを羅列しているだけに見える

守りたいこと:
  - 神名は本文でも `須佐之男命（スサノオノミコト）` の形で出る（承認ア＝全出現）
  - テーマ別の意味は**1つだけ**出す（マスタの列挙をそのまま流さない）
  - **問いがあるときだけ**結論を先に置き、問いの主題語を本文で使う
"""

from __future__ import annotations

import pytest

from oracle_app.content_loader import load_card_content
from oracle_app.services.interpretation_engine import InterpretationEngine

THREE = [f"japanese_mythology_card_{no:03d}" for no in (31, 3, 42)]


@pytest.fixture(scope="module")
def engine() -> InterpretationEngine:
    return InterpretationEngine(load_card_content())


def _reading(engine: InterpretationEngine, question: str | None, theme: str = "money") -> str:
    return engine.compose_reading(
        THREE, theme, "2026-09-12", "ses_ruby", "fb",
        spread_id="three", question_text=question,
    )


# --- ① ルビ ------------------------------------------------------------------


def test_本文の神名にルビが付く(engine: InterpretationEngine) -> None:
    text = _reading(engine, None)
    for card_id in THREE:
        card = engine.card_for(card_id)
        assert f"{card['name_ja']}（{card['reading']}）" in text, card["name_ja"]


def test_組み合わせ解釈の神名にもルビが付く(engine: InterpretationEngine) -> None:
    text = engine.compose_combination(THREE[0], THREE[-1])
    assert text
    for card_id in (THREE[0], THREE[-1]):
        card = engine.card_for(card_id)
        assert f"{card['name_ja']}（{card['reading']}）" in text


def test_ルビが空なら括弧を出さない(engine: InterpretationEngine) -> None:
    assert engine._with_ruby({"name_ja": "某神", "reading": ""}) == "某神"
    assert engine._with_ruby({"name_ja": "某神"}) == "某神"


def test_全44柱にルビがある(engine: InterpretationEngine) -> None:
    """素材側の欠けをここで捕まえる（欠けても落ちないが、括弧が出なくなる）。"""
    missing = [
        card["name_ja"]
        for no in range(1, 45)
        if (card := engine.card_for(f"japanese_mythology_card_{no:03d}"))
        and not str(card.get("reading", "")).strip()
    ]
    assert not missing, missing


# --- ② 羅列の解消 -------------------------------------------------------------


def test_テーマの意味は1つだけ出る(engine: InterpretationEngine) -> None:
    """列挙を全部繋いでいたのが「羅列」に見えた直接の原因。"""
    text = _reading(engine, None)
    for card_id in THREE:
        card = engine.card_for(card_id)
        items = [
            part.strip()
            for part in card["theme_meanings"]["money"].split("。")
            if part.strip()
        ]
        used = [item for item in items if item in text]
        assert len(used) <= 1, f"{card['name_ja']}: {used}"


def test_段落ごとに違う意味が当たる(engine: InterpretationEngine) -> None:
    """1つに絞っても、3枚引きなら全体では複数の意味が読み手に届く。"""
    text = _reading(engine, None)
    used = set()
    for card_id in THREE:
        card = engine.card_for(card_id)
        for item in card["theme_meanings"]["money"].split("。"):
            if item.strip() and item.strip() in text:
                used.add(item.strip())
    assert len(used) >= 2


# --- ② 結論を先に述べる -------------------------------------------------------


def test_主題語を取り出す(engine: InterpretationEngine) -> None:
    cases = {
        "宝くじのロト7で1等を当てたい": "ロト7",
        "転職すべきか迷っています": "転職",
        "彼の気持ちが知りたい": "彼",
        "いつごろ結婚できますか": "結婚",
        "なぜ人間関係がうまくいかないのでしょうか": "人間関係",
    }
    for question, expected in cases.items():
        assert engine.question_subject(question) == expected, question


def test_問いの言い回しは主題にしない(engine: InterpretationEngine) -> None:
    """「気持ち」「どちら」等は型の判定語であって主題ではない。"""
    assert engine.question_subject("彼の気持ちが知りたい") != "気持"


def test_問いの型を判定する(engine: InterpretationEngine) -> None:
    cases = {
        "いつごろ結婚できますか": "時期",
        "転職すべきか迷っています": "選択",
        "彼の気持ちが知りたい": "気持ち",
        "なぜうまくいかないのでしょうか": "原因",
        "どうすれば良くなりますか": "方法",
    }
    for question, expected in cases.items():
        assert (engine.question_form(question) or {}).get("kind") == expected, question


def test_結論に主題語が現れる(engine: InterpretationEngine) -> None:
    text = _reading(engine, "宝くじのロト7で1等を当てたい")
    conclusion = text.split("\n\n")[1]
    assert "ロト7" in conclusion, conclusion


def test_結論は導入の直後に置かれる(engine: InterpretationEngine) -> None:
    text = _reading(engine, "転職すべきか迷っています")
    paragraphs = text.split("\n\n")
    assert "という問いに" in paragraphs[0]
    assert "転職" in paragraphs[1]
    assert paragraphs[2].startswith("【")


def test_問いが無ければ結論を出さない(engine: InterpretationEngine) -> None:
    """本日の託宣は問いを持たない。従来どおりに保つ（退行防止）。"""
    paragraphs = _reading(engine, None).split("\n\n")
    assert paragraphs[1].startswith("【")


def test_主題が取れなければ結論を出さない(engine: InterpretationEngine) -> None:
    """一般論を語るより、何も言わないほうが害が小さい（fail-soft）。"""
    assert engine.question_subject("ああ、うう") is None
    paragraphs = _reading(engine, "ああ、うう").split("\n\n")
    assert paragraphs[1].startswith("【")


def test_結論と最後のカードは違う意味を使う(engine: InterpretationEngine) -> None:
    """同じ文を二度言わない。"""
    text = _reading(engine, "宝くじのロト7で1等を当てたい")
    paragraphs = text.split("\n\n")
    conclusion = paragraphs[1]
    last = engine.card_for(THREE[-1])
    items = [
        part.strip()
        for part in last["theme_meanings"]["money"].split("。")
        if part.strip()
    ]
    in_conclusion = [item for item in items if item in conclusion]
    assert len(in_conclusion) == 1
    future = next(p for p in paragraphs if p.startswith("【未来】"))
    assert in_conclusion[0] not in future


def test_同じ引きなら何度でも同じ文になる(engine: InterpretationEngine) -> None:
    question = "宝くじのロト7で1等を当てたい"
    assert _reading(engine, question) == _reading(engine, question)


def test_全44柱で禁止表現が出ない(engine: InterpretationEngine) -> None:
    questions = [
        "宝くじのロト7で1等を当てたい",
        "いつごろ結婚できますか",
        "彼の気持ちが知りたい",
        None,
    ]
    for no in range(1, 45):
        card_id = f"japanese_mythology_card_{no:03d}"
        if engine.card_for(card_id) is None:
            continue
        for question in questions:
            text = engine.compose_reading(
                [card_id], "love", "2026-09-12", "ses_f", "fb",
                spread_id="daily", question_text=question,
            )
            found = engine.find_forbidden(text)
            assert not found, f"{card_id} / {question} / {found}"
