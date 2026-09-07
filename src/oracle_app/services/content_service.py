from __future__ import annotations

from ..models import Announcement, Card, Deck, Product, Theme
from ..store import InMemoryStore


class ContentService:
    def __init__(self, store: InMemoryStore) -> None:
        self._store = store

    def list_themes(self) -> list[Theme]:
        return self._store.list_themes()

    def list_decks(self) -> list[Deck]:
        return self._store.list_decks()

    def list_cards(self, deck_id: str | None = None, query: str | None = None) -> list[Card]:
        return self._store.list_cards(deck_id=deck_id, query=query)

    def list_announcements(self) -> list[Announcement]:
        return self._store.list_announcements()

    def list_products(self) -> list[Product]:
        return self._store.list_products()
