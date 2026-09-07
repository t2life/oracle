from __future__ import annotations

import os
import sys
from pathlib import Path

import uvicorn

ROOT_DIR = Path(__file__).resolve().parents[1]
SRC_DIR = ROOT_DIR / "src"
if str(SRC_DIR) not in sys.path:
    sys.path.insert(0, str(SRC_DIR))


def main() -> None:
    # 既定はローカル専用（127.0.0.1）。実機のWi-Fi接続検証時のみ
    # ORACLE_SERVER_HOST=0.0.0.0 を指定してLANへ公開する。
    host = os.getenv("ORACLE_SERVER_HOST", "127.0.0.1")
    port = int(os.getenv("ORACLE_SERVER_PORT", "8000"))
    uvicorn.run(
        "oracle_app.main:app",
        host=host,
        port=port,
        reload=True,
    )


if __name__ == "__main__":
    main()
