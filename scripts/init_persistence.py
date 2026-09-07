from __future__ import annotations

import sys
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parents[1]
SRC_DIR = ROOT_DIR / "src"
if str(SRC_DIR) not in sys.path:
    sys.path.insert(0, str(SRC_DIR))

from oracle_app.config import AppConfig
from oracle_app.persistence import PostgresPersistence, RedisCache


def main() -> None:
    config = AppConfig()
    backend = config.persistence_backend.strip().lower()
    runtime_mode = config.runtime_mode.strip().lower()

    wants_postgres = backend in {"postgres", "postgresql", "hybrid"} or config.postgres.enabled
    wants_redis = backend in {"redis", "hybrid"} or config.redis.enabled

    postgres: PostgresPersistence | None = None
    redis_cache: RedisCache | None = None

    print(f"runtime_mode={config.runtime_mode}")
    print(f"persistence_backend={config.persistence_backend}")

    if runtime_mode in {"staging", "production"} and backend == "inmemory":
        raise RuntimeError("staging/productionではinmemory backendを利用できません。")

    try:
        if wants_postgres:
            print("[postgres] connecting...")
            postgres = PostgresPersistence(config.postgres.dsn, echo=config.postgres.echo)
            postgres.initialize_schema()
            postgres.check_connection()
            print("[postgres] schema ready")
        else:
            print("[postgres] skipped")

        if wants_redis:
            print("[redis] connecting...")
            redis_cache = RedisCache(
                url=config.redis.url,
                prefix=config.redis.prefix,
                default_ttl_seconds=config.redis.ttl_seconds,
            )
            redis_cache.check_connection()
            print("[redis] connection ok")
        else:
            print("[redis] skipped")

        print("persistence initialization completed")

    finally:
        if postgres is not None:
            postgres.close()
        if redis_cache is not None:
            redis_cache.close()


if __name__ == "__main__":
    main()
