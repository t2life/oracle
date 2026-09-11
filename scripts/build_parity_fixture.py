from __future__ import annotations

"""オンライン（Python）とオフライン（Dart）の託宣文パリティ用の期待値を作る。

出力: mobile_app/test/interpretation_parity_expected.json（手動編集禁止）

`interpretation_engine.py` の出力をそのまま保存し、Dart 側の
`InterpretationComposer` が同じ文章を出すことを
`mobile_app/test/interpretation_parity_test.dart` が検証する。

合成ロジックか素材（DB/*.xlsx → card_content.json）を変えたら、
import_card_db.py → export_master_assets.py → **本スクリプト** の順で
作り直すこと。作り直さずに素材だけ変えるとパリティテストが落ちる
（＝両実装がずれた、という正しい失敗である）。
"""

import json
import sys
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT_DIR / "src"))

from oracle_app.content_loader import load_card_content  # noqa: E402
from oracle_app.services.interpretation_engine import (  # noqa: E402
    InterpretationEngine,
)

OUTPUT_PATH = ROOT_DIR / "mobile_app" / "test" / "interpretation_parity_expected.json"

# 期待値を作るケース。日替わり要素を固定するため date_key / session_id も定数。
DATE_KEY = "2026-09-10"
SESSION_ID = "ses_parity"
FALLBACK = "（素材が見つかりませんでした）"

CASES: dict[str, dict] = {
    "daily_work": {
        "card_ids": ["japanese_mythology_card_032"],
        "theme_id": "work",
        "spread_id": "daily",
        "question_text": None,
    },
    "daily_love_q": {
        "card_ids": ["japanese_mythology_card_007"],
        "theme_id": "love",
        "spread_id": "daily",
        "question_text": "彼との関係が上手くいきません。別れるべきか悩んでいます。",
    },
    # 2026-09-11 番号の読み（期日・数量）。エレメントが単位を、番号が数を決める。
    # 片方の実装だけ直すとここが落ちる＝ずれに気づける。
    "daily_timing_q": {
        "card_ids": ["japanese_mythology_card_006"],
        "theme_id": "work",
        "spread_id": "daily",
        "question_text": "いつごろ転職すべきですか。",
    },
    "daily_quantity_q": {
        "card_ids": ["japanese_mythology_card_001"],
        "theme_id": "love",
        "spread_id": "daily",
        "question_text": "何人くらいと出会えますか。",
    },
    "three_work_q": {
        "card_ids": [
            "japanese_mythology_card_032",
            "japanese_mythology_card_007",
            "japanese_mythology_card_021",
        ],
        "theme_id": "work",
        "spread_id": "three",
        "question_text": "転職すべきか迷っています。",
    },
}


def main() -> int:
    engine = InterpretationEngine(load_card_content())
    fixture: dict[str, dict] = {}
    for name, case in CASES.items():
        fixture[name] = {
            # 日替わり選択（date_key/session_id のハッシュ）を含むため、
            # 生成条件も期待値と一緒に保存して Dart 側へ渡す。
            "input": {**case, "date_key": DATE_KEY, "session_id": SESSION_ID},
            "expected": engine.compose_reading(
                card_ids=list(case["card_ids"]),
                theme_id=case["theme_id"],
                date_key=DATE_KEY,
                session_id=SESSION_ID,
                fallback_text=FALLBACK,
                spread_id=case["spread_id"],
                question_text=case["question_text"],
            ),
        }

    OUTPUT_PATH.write_text(
        json.dumps(fixture, ensure_ascii=False, indent=1) + "\n", encoding="utf-8"
    )
    print(f"パリティ期待値を書き出しました: {OUTPUT_PATH}（{len(fixture)}ケース）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
