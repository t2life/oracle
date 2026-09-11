from __future__ import annotations

from datetime import datetime
from typing import Any

from ..config import AppConfig
from ..models import (
    Announcement,
    AuditLog,
    HistoryItem,
    Inquiry,
    NotificationSetting,
    PlanType,
    Profile,
    ReadingResult,
    User,
)
from ..store import InMemoryStore
from ..time_utils import now_jst
from .postgres import PostgresPersistence
from .redis_cache import RedisCache


class HybridStore(InMemoryStore):
    """InMemory互換を維持しつつPostgreSQL/Redisを段階的に併用するストア。"""

    def __init__(
        self,
        config: AppConfig,
        postgres: PostgresPersistence | None = None,
        redis_cache: RedisCache | None = None,
    ) -> None:
        super().__init__(config)
        self._postgres = postgres
        self._redis_cache = redis_cache

    def get_or_create_user(self, user_id: str) -> User:
        existed = self._users.get(user_id)
        if existed is not None:
            return existed

        if self._postgres is not None:
            try:
                loaded = self._postgres.fetch_user(user_id)
            except Exception:
                loaded = None

            if loaded is not None:
                self._users[user_id] = loaded
                self._profiles.setdefault(user_id, Profile(user_id=user_id, display_name=user_id))
                self._notification_settings.setdefault(
                    user_id,
                    NotificationSetting(user_id=user_id),
                )
                return loaded

        user = super().get_or_create_user(user_id)
        if self._postgres is not None:
            try:
                self._postgres.upsert_user(user)
            except Exception:
                pass
        return user

    def update_user(self, user: User) -> None:
        super().update_user(user)

        if self._postgres is not None:
            try:
                self._postgres.upsert_user(user)
            except Exception:
                pass

    def list_users(self) -> list[User]:
        users = super().list_users()
        if self._postgres is not None:
            try:
                loaded = self._postgres.fetch_users(limit=5000)
            except Exception:
                loaded = []

            for user in loaded:
                self._users[user.user_id] = user
                self._profiles.setdefault(
                    user.user_id,
                    Profile(user_id=user.user_id, display_name=user.user_id),
                )
                self._notification_settings.setdefault(
                    user.user_id,
                    NotificationSetting(user_id=user.user_id),
                )
            users = super().list_users()
        return users

    def save_result(self, result: ReadingResult) -> None:
        super().save_result(result)

        if self._postgres is not None:
            try:
                self._postgres.upsert_reading_result(result)
            except Exception:
                # 段階導入中は永続化障害で業務フローを止めない
                pass

        if self._redis_cache is not None:
            try:
                self._redis_cache.set_json(
                    _result_cache_key(result.session_id),
                    _result_to_dict(result),
                    ttl_seconds=1800,
                )
            except Exception:
                pass

    def get_result(self, session_id: str) -> ReadingResult | None:
        if self._redis_cache is not None:
            try:
                cached = self._redis_cache.get_json(_result_cache_key(session_id))
                if cached is not None:
                    return _result_from_dict(cached)
            except Exception:
                pass

        result = super().get_result(session_id)
        if result is None and self._postgres is not None:
            try:
                result = self._postgres.fetch_reading_result(session_id)
            except Exception:
                result = None

            if result is not None:
                super().save_result(result)

        if result is not None and self._redis_cache is not None:
            try:
                self._redis_cache.set_json(
                    _result_cache_key(result.session_id),
                    _result_to_dict(result),
                    ttl_seconds=1800,
                )
            except Exception:
                pass

        return result

    def add_history_item(self, item: HistoryItem) -> None:
        super().add_history_item(item)

        if self._postgres is not None:
            try:
                self._postgres.insert_history_item(item)
            except Exception:
                pass

        if self._redis_cache is not None:
            try:
                self._redis_cache.delete(_history_cache_key(item.user_id))
            except Exception:
                pass

    def trim_history_for_user(self, user_id: str, max_items: int) -> None:
        super().trim_history_for_user(user_id, max_items)

        if self._postgres is not None:
            try:
                self._postgres.trim_history_for_user(user_id=user_id, max_items=max_items)
            except Exception:
                pass

        if self._redis_cache is not None:
            try:
                self._redis_cache.delete(_history_cache_key(user_id))
            except Exception:
                pass

    def delete_history_item(self, user_id: str, history_id: str) -> bool:
        deleted = super().delete_history_item(user_id, history_id)

        if self._postgres is not None:
            try:
                self._postgres.delete_history_item(
                    user_id=user_id, history_id=history_id
                )
            except Exception:
                pass

        if self._redis_cache is not None:
            try:
                self._redis_cache.delete(_history_cache_key(user_id))
            except Exception:
                pass

        return deleted

    def list_history(self, user_id: str) -> list[HistoryItem]:
        if self._redis_cache is not None:
            try:
                cached = self._redis_cache.get_json_list(_history_cache_key(user_id))
                if cached is not None:
                    return [_history_from_dict(item) for item in cached]
            except Exception:
                pass

        items = super().list_history(user_id)
        if not items and self._postgres is not None:
            try:
                items = self._postgres.fetch_history(user_id=user_id)
            except Exception:
                items = []

            if items:
                existing_ids = {item.history_id for item in super().list_history(user_id)}
                for item in reversed(items):
                    if item.history_id not in existing_ids:
                        super().add_history_item(item)
                        existing_ids.add(item.history_id)
                items = super().list_history(user_id)

        if self._redis_cache is not None:
            try:
                self._redis_cache.set_json_list(
                    _history_cache_key(user_id),
                    [_history_to_dict(item) for item in items],
                    ttl_seconds=120,
                )
            except Exception:
                pass

        return items

    def create_announcement(
        self,
        title: str,
        body: str,
        category: str,
        start_at,
        end_at,
        is_important: bool,
        link_url: str | None,
    ) -> Announcement:
        announcement = super().create_announcement(
            title=title,
            body=body,
            category=category,
            start_at=start_at,
            end_at=end_at,
            is_important=is_important,
            link_url=link_url,
        )

        if self._postgres is not None:
            try:
                self._postgres.upsert_announcement(announcement)
            except Exception:
                pass

        if self._redis_cache is not None:
            try:
                self._redis_cache.delete(_announcements_cache_key(active_only=True))
                self._redis_cache.delete(_announcements_cache_key(active_only=False))
            except Exception:
                pass

        return announcement

    def list_announcements(self) -> list[Announcement]:
        if self._redis_cache is not None:
            try:
                cached = self._redis_cache.get_json_list(_announcements_cache_key(active_only=True))
                if cached is not None:
                    return [_announcement_from_dict(item) for item in cached]
            except Exception:
                pass

        announcements = super().list_announcements()
        if self._postgres is not None:
            try:
                loaded = self._postgres.fetch_active_announcements(now=now_jst())
            except Exception:
                loaded = []

            if loaded:
                for item in loaded:
                    self._announcements[item.announcement_id] = item
                announcements = loaded

        if self._redis_cache is not None:
            try:
                self._redis_cache.set_json_list(
                    _announcements_cache_key(active_only=True),
                    [_announcement_to_dict(item) for item in announcements],
                    ttl_seconds=120,
                )
            except Exception:
                pass

        return announcements

    def list_all_announcements(self) -> list[Announcement]:
        if self._redis_cache is not None:
            try:
                cached = self._redis_cache.get_json_list(_announcements_cache_key(active_only=False))
                if cached is not None:
                    return [_announcement_from_dict(item) for item in cached]
            except Exception:
                pass

        announcements = super().list_all_announcements()
        if self._postgres is not None:
            try:
                loaded = self._postgres.fetch_all_announcements(limit=1000)
            except Exception:
                loaded = []

            if loaded:
                for item in loaded:
                    self._announcements[item.announcement_id] = item
                announcements = loaded

        if self._redis_cache is not None:
            try:
                self._redis_cache.set_json_list(
                    _announcements_cache_key(active_only=False),
                    [_announcement_to_dict(item) for item in announcements],
                    ttl_seconds=120,
                )
            except Exception:
                pass

        return announcements

    def add_inquiry(self, user_id: str, category: str, body: str, email: str | None) -> Inquiry:
        inquiry = super().add_inquiry(
            user_id=user_id,
            category=category,
            body=body,
            email=email,
        )

        if self._postgres is not None:
            try:
                self._postgres.insert_inquiry(inquiry)
            except Exception:
                pass

        if self._redis_cache is not None:
            try:
                self._redis_cache.delete(_inquiries_cache_key())
            except Exception:
                pass

        return inquiry

    def list_inquiries(self) -> list[Inquiry]:
        if self._redis_cache is not None:
            try:
                cached = self._redis_cache.get_json_list(_inquiries_cache_key())
                if cached is not None:
                    return [_inquiry_from_dict(item) for item in cached]
            except Exception:
                pass

        inquiries = super().list_inquiries()
        if self._postgres is not None:
            try:
                loaded = self._postgres.fetch_inquiries(limit=1000)
            except Exception:
                loaded = []

            if loaded:
                existing_ids = {item.inquiry_id for item in self._inquiries}
                for item in reversed(loaded):
                    if item.inquiry_id not in existing_ids:
                        self._inquiries.append(item)
                        existing_ids.add(item.inquiry_id)
                inquiries = super().list_inquiries()

        if self._redis_cache is not None:
            try:
                self._redis_cache.set_json_list(
                    _inquiries_cache_key(),
                    [_inquiry_to_dict(item) for item in inquiries],
                    ttl_seconds=120,
                )
            except Exception:
                pass

        return inquiries

    def add_audit_log(
        self,
        actor_type: str,
        actor_id: str,
        action: str,
        resource_type: str,
        resource_id: str | None,
        detail: dict[str, str] | None,
    ) -> AuditLog:
        log = super().add_audit_log(
            actor_type=actor_type,
            actor_id=actor_id,
            action=action,
            resource_type=resource_type,
            resource_id=resource_id,
            detail=detail,
        )

        if self._postgres is not None:
            try:
                self._postgres.insert_audit_log(log)
            except Exception:
                pass
        return log

    def list_audit_logs(self, limit: int = 200) -> list[AuditLog]:
        logs = super().list_audit_logs(limit=limit)
        if logs:
            return logs

        if self._postgres is not None:
            try:
                loaded = self._postgres.fetch_audit_logs(limit=limit)
            except Exception:
                loaded = []

            if loaded:
                self._audit_logs.extend(loaded)
                return super().list_audit_logs(limit=limit)

        return logs



def _result_cache_key(session_id: str) -> str:
    return f"reading_result:{session_id}"



def _history_cache_key(user_id: str) -> str:
    return f"history:{user_id}"


def _announcements_cache_key(active_only: bool) -> str:
    return f"announcements:{'active' if active_only else 'all'}"


def _inquiries_cache_key() -> str:
    return "inquiries:all"



def _result_to_dict(result: ReadingResult) -> dict[str, Any]:
    return {
        "session_id": result.session_id,
        "user_id": result.user_id,
        "theme_id": result.theme_id,
        "deck_id": result.deck_id,
        "card_id": result.card_id,
        "card_name": result.card_name,
        "keywords": result.keywords,
        "interpretation_text": result.interpretation_text,
        "caution_text": result.caution_text,
        "created_at": result.created_at.isoformat(),
        "copied": result.copied,
    }



def _result_from_dict(data: dict[str, Any]) -> ReadingResult:
    return ReadingResult(
        session_id=str(data["session_id"]),
        user_id=str(data["user_id"]),
        theme_id=str(data["theme_id"]),
        deck_id=str(data["deck_id"]),
        card_id=str(data["card_id"]),
        card_name=str(data["card_name"]),
        keywords=[str(item) for item in data.get("keywords", [])],
        interpretation_text=str(data["interpretation_text"]),
        caution_text=(
            str(data["caution_text"])
            if data.get("caution_text") is not None
            else None
        ),
        created_at=_parse_datetime(data.get("created_at")),
        copied=bool(data.get("copied", False)),
    )



def _history_to_dict(item: HistoryItem) -> dict[str, Any]:
    return {
        "history_id": item.history_id,
        "user_id": item.user_id,
        "session_id": item.session_id,
        "created_at": item.created_at.isoformat(),
        "theme_id": item.theme_id,
        "deck_id": item.deck_id,
        "card_id": item.card_id,
        "summary": item.summary,
        "full_text": item.full_text,
        "plan_at_creation": item.plan_at_creation.value,
        "spread_id": item.spread_id,
    }



def _history_from_dict(data: dict[str, Any]) -> HistoryItem:
    return HistoryItem(
        history_id=str(data["history_id"]),
        user_id=str(data["user_id"]),
        session_id=str(data["session_id"]),
        created_at=_parse_datetime(data.get("created_at")),
        theme_id=str(data["theme_id"]),
        deck_id=str(data["deck_id"]),
        card_id=str(data["card_id"]),
        summary=str(data["summary"]),
        full_text=str(data["full_text"]),
        plan_at_creation=PlanType(str(data.get("plan_at_creation", PlanType.FREE.value))),
        spread_id=str(data.get("spread_id") or "daily"),
    )


def _announcement_to_dict(item: Announcement) -> dict[str, Any]:
    return {
        "announcement_id": item.announcement_id,
        "title": item.title,
        "body": item.body,
        "category": item.category,
        "start_at": item.start_at.isoformat(),
        "end_at": item.end_at.isoformat(),
        "is_important": item.is_important,
        "link_url": item.link_url,
    }


def _announcement_from_dict(data: dict[str, Any]) -> Announcement:
    return Announcement(
        announcement_id=str(data["announcement_id"]),
        title=str(data["title"]),
        body=str(data["body"]),
        category=str(data["category"]),
        start_at=_parse_datetime(data.get("start_at")),
        end_at=_parse_datetime(data.get("end_at")),
        is_important=bool(data.get("is_important", False)),
        link_url=(
            str(data["link_url"])
            if data.get("link_url") is not None
            else None
        ),
    )


def _inquiry_to_dict(item: Inquiry) -> dict[str, Any]:
    return {
        "inquiry_id": item.inquiry_id,
        "user_id": item.user_id,
        "category": item.category,
        "body": item.body,
        "email": item.email,
        "created_at": item.created_at.isoformat(),
    }


def _inquiry_from_dict(data: dict[str, Any]) -> Inquiry:
    return Inquiry(
        inquiry_id=str(data["inquiry_id"]),
        user_id=str(data["user_id"]),
        category=str(data["category"]),
        body=str(data["body"]),
        email=(str(data["email"]) if data.get("email") is not None else None),
        created_at=_parse_datetime(data.get("created_at")),
    )



def _parse_datetime(raw: Any) -> datetime:
    if isinstance(raw, datetime):
        return raw
    if raw is None:
        return datetime.now().astimezone()
    return datetime.fromisoformat(str(raw))
