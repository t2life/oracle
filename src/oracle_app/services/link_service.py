from __future__ import annotations

from ..models import ExternalLink, LiveEvent
from ..store import InMemoryStore


class LinkService:
    def __init__(self, store: InMemoryStore) -> None:
        self._store = store

    def list_shop_links(self) -> list[ExternalLink]:
        return self._store.list_external_links("shop")

    def list_consultation_links(self) -> list[ExternalLink]:
        return self._store.list_external_links("consultation")

    def list_live_links(self) -> list[ExternalLink]:
        return self._store.list_external_links("live")

    def list_live_events(self) -> list[LiveEvent]:
        return self._store.list_live_events()
