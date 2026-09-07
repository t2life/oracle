from __future__ import annotations

import json
from typing import Any


class RedisCache:
    """Small JSON cache wrapper for hot-path reads during migration."""

    def __init__(
        self,
        url: str,
        prefix: str = "oracle:",
        default_ttl_seconds: int = 600,
    ) -> None:
        redis = _import_redis()
        self._client = redis.Redis.from_url(url, decode_responses=True)
        self._prefix = prefix
        self._default_ttl_seconds = default_ttl_seconds

    def check_connection(self) -> None:
        self._client.ping()

    def close(self) -> None:
        self._client.close()

    def set_json(self, key: str, value: dict[str, Any], ttl_seconds: int | None = None) -> None:
        ttl = ttl_seconds if ttl_seconds is not None else self._default_ttl_seconds
        self._client.set(self._full_key(key), json.dumps(value, ensure_ascii=False), ex=ttl)

    def get_json(self, key: str) -> dict[str, Any] | None:
        raw = self._client.get(self._full_key(key))
        if raw is None:
            return None
        decoded = json.loads(raw)
        if not isinstance(decoded, dict):
            return None
        return decoded

    def set_json_list(
        self,
        key: str,
        values: list[dict[str, Any]],
        ttl_seconds: int | None = None,
    ) -> None:
        ttl = ttl_seconds if ttl_seconds is not None else self._default_ttl_seconds
        self._client.set(self._full_key(key), json.dumps(values, ensure_ascii=False), ex=ttl)

    def get_json_list(self, key: str) -> list[dict[str, Any]] | None:
        raw = self._client.get(self._full_key(key))
        if raw is None:
            return None
        decoded = json.loads(raw)
        if not isinstance(decoded, list):
            return None
        values: list[dict[str, Any]] = []
        for item in decoded:
            if isinstance(item, dict):
                values.append(item)
        return values

    def delete(self, key: str) -> None:
        self._client.delete(self._full_key(key))

    def _full_key(self, key: str) -> str:
        return f"{self._prefix}{key}"



def _import_redis() -> Any:
    try:
        import redis  # type: ignore
    except ImportError as exc:
        raise RuntimeError(
            "Redis cache requires redis-py. Install with: pip install redis"
        ) from exc
    return redis
