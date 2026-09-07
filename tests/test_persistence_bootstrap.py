from __future__ import annotations

import pytest

from oracle_app.config import AppConfig
from oracle_app.models import HistoryItem, PlanType, ReadingResult
from oracle_app.orchestrator import _build_store
from oracle_app.persistence.hybrid_store import HybridStore
from oracle_app.time_utils import now_jst


class _FakePostgres:
    def __init__(self) -> None:
        self.results: dict[str, ReadingResult] = {}
        self.histories: dict[str, list[HistoryItem]] = {}
        self.trim_calls: list[tuple[str, int]] = []

    def upsert_reading_result(self, result: ReadingResult) -> None:
        self.results[result.session_id] = result

    def fetch_reading_result(self, session_id: str) -> ReadingResult | None:
        return self.results.get(session_id)

    def insert_history_item(self, item: HistoryItem) -> None:
        self.histories.setdefault(item.user_id, []).append(item)

    def fetch_history(self, user_id: str, limit: int = 100) -> list[HistoryItem]:
        return sorted(
            self.histories.get(user_id, []),
            key=lambda x: x.created_at,
            reverse=True,
        )[:limit]

    def trim_history_for_user(self, user_id: str, max_items: int) -> None:
        self.trim_calls.append((user_id, max_items))
        if max_items <= 0:
            self.histories[user_id] = []
            return
        items = self.fetch_history(user_id, limit=max_items)
        self.histories[user_id] = items


class _FakeRedis:
    def __init__(self) -> None:
        self.kv: dict[str, dict] = {}
        self.list_kv: dict[str, list[dict]] = {}
        self.deleted_keys: list[str] = []

    def set_json(self, key: str, value: dict, ttl_seconds: int | None = None) -> None:
        self.kv[key] = value

    def get_json(self, key: str) -> dict | None:
        return self.kv.get(key)

    def set_json_list(
        self,
        key: str,
        values: list[dict],
        ttl_seconds: int | None = None,
    ) -> None:
        self.list_kv[key] = values

    def get_json_list(self, key: str) -> list[dict] | None:
        return self.list_kv.get(key)

    def delete(self, key: str) -> None:
        self.deleted_keys.append(key)
        self.kv.pop(key, None)
        self.list_kv.pop(key, None)



def test_app_config_reads_persistence_env(monkeypatch):
    monkeypatch.setenv("ORACLE_RUNTIME_MODE", "staging")
    monkeypatch.setenv("ORACLE_PERSISTENCE_BACKEND", "hybrid")
    monkeypatch.setenv("ORACLE_POSTGRES_ENABLED", "true")
    monkeypatch.setenv("ORACLE_POSTGRES_DSN", "postgresql+psycopg://x:y@localhost:5432/z")
    monkeypatch.setenv("ORACLE_REDIS_ENABLED", "yes")
    monkeypatch.setenv("ORACLE_REDIS_URL", "redis://localhost:6379/1")
    monkeypatch.setenv("ORACLE_REDIS_PREFIX", "oracle-test:")
    monkeypatch.setenv("ORACLE_REDIS_TTL_SECONDS", "42")

    config = AppConfig()

    assert config.runtime_mode == "staging"
    assert config.persistence_backend == "hybrid"
    assert config.postgres.enabled is True
    assert config.postgres.dsn.endswith("/z")
    assert config.redis.enabled is True
    assert config.redis.url.endswith("/1")
    assert config.redis.prefix == "oracle-test:"
    assert config.redis.ttl_seconds == 42


def test_build_store_rejects_inmemory_in_staging(monkeypatch):
    monkeypatch.setenv("ORACLE_RUNTIME_MODE", "staging")
    monkeypatch.setenv("ORACLE_PERSISTENCE_BACKEND", "inmemory")

    config = AppConfig()

    with pytest.raises(RuntimeError) as exc_info:
        _build_store(config)

    assert "inmemory" in str(exc_info.value).lower()



def test_hybrid_store_dual_write_and_rehydrate_from_postgres():
    config = AppConfig()
    fake_postgres = _FakePostgres()
    fake_redis = _FakeRedis()
    store = HybridStore(config, postgres=fake_postgres, redis_cache=fake_redis)

    result = ReadingResult(
        session_id="ses_test",
        user_id="u_test",
        theme_id="love",
        deck_id="japanese_mythology",
        card_id="japanese_mythology_card_001",
        card_name="日本神話デッキ 1",
        keywords=["示唆1", "内省", "行動"],
        interpretation_text="テスト解釈",
        caution_text="注意",
        created_at=now_jst(),
        copied=False,
    )

    store.save_result(result)

    assert fake_postgres.results["ses_test"].card_id == result.card_id
    assert fake_redis.kv["reading_result:ses_test"]["session_id"] == "ses_test"

    store._results.clear()
    fake_redis.kv.clear()

    loaded = store.get_result("ses_test")
    assert loaded is not None
    assert loaded.card_name == "日本神話デッキ 1"



def test_hybrid_store_history_cache_and_trim_propagation():
    config = AppConfig()
    fake_postgres = _FakePostgres()
    fake_redis = _FakeRedis()
    store = HybridStore(config, postgres=fake_postgres, redis_cache=fake_redis)

    item = HistoryItem(
        history_id="his_test",
        user_id="u_history",
        session_id="ses_test",
        created_at=now_jst(),
        theme_id="love",
        deck_id="japanese_mythology",
        card_id="japanese_mythology_card_001",
        summary="summary",
        full_text="full_text",
        plan_at_creation=PlanType.FREE,
    )

    store.add_history_item(item)
    assert "history:u_history" in fake_redis.deleted_keys

    store._history.clear()
    loaded = store.list_history("u_history")
    assert len(loaded) == 1
    assert loaded[0].history_id == "his_test"
    assert fake_redis.list_kv["history:u_history"][0]["history_id"] == "his_test"

    store.trim_history_for_user("u_history", 0)
    assert fake_postgres.trim_calls[-1] == ("u_history", 0)
    assert "history:u_history" in fake_redis.deleted_keys
