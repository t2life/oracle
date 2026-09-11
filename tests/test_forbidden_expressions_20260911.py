"""託宣文の禁止表現テスト（2026-09-11）。

先行アプリ（吉凶羅針盤）は生成AIによる文章生成を意図的に見送り、代わりに
**人のレビューに頼らず機械で守る**禁止語を置いて全生成文へ当てている
（`Constants.FORTUNE_FORBIDDEN_ASSERTIONS` / `ReadingDiversityTest`）。

本アプリも 2026-09-11 に同じ判断（外部AIを使わない）をしたため、規律も揃える。
語はマスタ「禁止表現マスタ」が単一真実源で、コードに直書きしない。

このテストが守るのは、**素材（44柱.xlsx）へ不用意な語が入ったときに気づけること**。
健康の治癒・金銭の増減・恐怖訴求・保証と読める語は、ストア審査と信頼の両方に関わる。
"""

from __future__ import annotations

import pytest

from oracle_app.content_loader import load_card_content
from oracle_app.services.interpretation_engine import InterpretationEngine

THEMES = ("love", "work", "money", "health", "subconscious", "higher_self")


@pytest.fixture(scope="module")
def engine() -> InterpretationEngine:
    return InterpretationEngine(load_card_content())


def test_master_provides_the_words(engine: InterpretationEngine) -> None:
    """語はマスタが持つ（コードに直書きしない）。"""
    entries = engine.forbidden_expressions()
    assert len(entries) >= 18
    categories = {entry["category"] for entry in entries}
    assert {"健康", "金銭", "恐怖訴求", "断定"} <= categories


def test_detects_and_passes(engine: InterpretationEngine) -> None:
    assert engine.find_forbidden("この病気が必ず治ります。") 
    assert engine.find_forbidden("穏やかに進んでみてください。") == []


def test_tone_avoid_words_are_checked(engine: InterpretationEngine) -> None:
    """トーンの「避けるべき表現」も併せて見る（マスタの別列）。"""
    assert engine.find_forbidden("あなたには無理です。", tone_name="励ましトーン")


def test_composed_readings_contain_no_forbidden_expression(
    engine: InterpretationEngine,
) -> None:
    """**全カード×全テーマ**の託宣文に禁止表現が出ないこと。

    素材を直した誰かが気づけるよう、生成物そのものを走査する。
    """
    card_ids = [card["card_id"] for card in load_card_content()["cards"]]
    assert len(card_ids) == 44

    for card_id in card_ids:
        for theme_id in THEMES:
            text = engine.compose_reading(
                card_ids=[card_id],
                theme_id=theme_id,
                date_key="2026-09-11",
                session_id="forbidden-check",
                fallback_text="",
                spread_id="daily",
            )
            hits = engine.find_forbidden(text)
            assert not hits, f"{card_id}/{theme_id} に禁止表現: {hits}\n{text}"
