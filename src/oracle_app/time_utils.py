from __future__ import annotations

from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo
from zoneinfo import ZoneInfoNotFoundError

try:
    JST = ZoneInfo("Asia/Tokyo")
except ZoneInfoNotFoundError:
    # Windows環境でtzdata未導入の場合もJST運用を継続する。
    JST = timezone(timedelta(hours=9), name="JST")


def now_jst() -> datetime:
    return datetime.now(tz=JST)


def date_key_jst(dt: datetime | None = None) -> str:
    target = dt or now_jst()
    return target.astimezone(JST).date().isoformat()
