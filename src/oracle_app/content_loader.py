from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path
from typing import Any

CONTENT_PATH = Path(__file__).resolve().parent / "data" / "card_content.json"


@lru_cache(maxsize=1)
def load_card_content() -> dict[str, Any]:
    """カードコンテンツ（scripts/import_card_db.py の生成物）を読み込む。

    ファイル欠損はデプロイ不整合（⚡135型）であるため起動時に即失敗させる。
    """
    if not CONTENT_PATH.exists():
        raise RuntimeError(
            "card_content.json が見つかりません。"
            "scripts/import_card_db.py を実行して生成してください。"
        )
    return json.loads(CONTENT_PATH.read_text(encoding="utf-8"))
