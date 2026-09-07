from __future__ import annotations

from ..config import AppConfig
from ..logging_utils import get_logger
from ..store import InMemoryStore


class AnalyticsService:
    def __init__(self, store: InMemoryStore, config: AppConfig) -> None:
        self._store = store
        self._config = config
        self._logger = get_logger(self.__class__.__name__)

    def track_event(
        self,
        event_name: str,
        user_id: str | None,
        properties: dict[str, str] | None,
    ):
        event = self._store.add_analytics_event(
            event_name=event_name,
            user_id=user_id,
            properties=properties,
        )
        self._logger.debug("分析イベント記録: event=%s user_id=%s", event_name, user_id)
        return event

    def get_kpi_snapshot(self) -> dict[str, int]:
        required = {event_name: 0 for event_name in self._config.analytics.required_events}
        for event in self._store.list_analytics_events():
            if event.event_name in required:
                required[event.event_name] += 1
        return required
