from __future__ import annotations

import argparse
import sys
from pathlib import Path
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

ROOT_DIR = Path(__file__).resolve().parents[1]
SRC_DIR = ROOT_DIR / "src"
if str(SRC_DIR) not in sys.path:
    sys.path.insert(0, str(SRC_DIR))

from oracle_app.config import AppConfig


def _load_sql(direction: str) -> str:
    migration_path = (
        ROOT_DIR
        / "scripts"
        / "migrations"
        / f"001_expand_persistence_{direction}.sql"
    )
    return migration_path.read_text(encoding="utf-8")


def _split_sql_statements(sql_text: str) -> list[str]:
    statements: list[str] = []
    for chunk in sql_text.split(";"):
        statement = chunk.strip()
        if statement == "" or statement.startswith("--") and "\n" not in statement:
            continue
        statements.append(statement)
    return statements


def _build_engine(dsn: str):
    try:
        import sqlalchemy as sa  # type: ignore
    except ImportError as exc:
        raise RuntimeError(
            "sqlalchemy が必要です。requirements.txt の依存をインストールしてください。"
        ) from exc
    normalized_dsn = _ensure_connect_timeout(dsn, timeout_seconds=5)
    return sa.create_engine(normalized_dsn, future=True)


def _ensure_connect_timeout(dsn: str, timeout_seconds: int) -> str:
    parsed = urlsplit(dsn)
    query_pairs = dict(parse_qsl(parsed.query, keep_blank_values=True))
    query_pairs.setdefault("connect_timeout", str(timeout_seconds))
    return urlunsplit(
        (
            parsed.scheme,
            parsed.netloc,
            parsed.path,
            urlencode(query_pairs),
            parsed.fragment,
        )
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Run DB migration SQL (up/down)")
    parser.add_argument(
        "direction",
        choices=["up", "down"],
        help="Migration direction",
    )
    args = parser.parse_args()

    config = AppConfig()
    engine = _build_engine(config.postgres.dsn)
    sql_text = _load_sql(args.direction)
    statements = _split_sql_statements(sql_text)

    try:
        with engine.begin() as connection:
            for statement in statements:
                connection.exec_driver_sql(statement)
    except Exception as exc:  # noqa: BLE001
        print(f"migration {args.direction} failed: {exc}", file=sys.stderr)
        raise SystemExit(1) from exc

    print(f"migration {args.direction} completed")


if __name__ == "__main__":
    main()
