from __future__ import annotations

import json
from datetime import datetime
from typing import Any

from ..models import Announcement, AuditLog, HistoryItem, Inquiry, PlanType, ReadingResult, User


class PostgresPersistence:
    """PostgreSQL adapter used for staged migration from InMemory storage."""

    def __init__(self, dsn: str, echo: bool = False) -> None:
        sa = _import_sqlalchemy()
        self._sa = sa
        self._engine = sa.create_engine(dsn, echo=echo, future=True)
        self._metadata = sa.MetaData()

        self._users = sa.Table(
            "users",
            self._metadata,
            sa.Column("user_id", sa.String(128), primary_key=True),
            sa.Column("plan", sa.String(32), nullable=False),
            sa.Column("tickets", sa.Integer(), nullable=False),
            sa.Column("subscription_expires_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("visit_count", sa.Integer(), nullable=False),
        )

        self._subscriptions = sa.Table(
            "subscriptions",
            self._metadata,
            sa.Column("user_id", sa.String(128), primary_key=True),
            sa.Column("plan_id", sa.String(64), nullable=False),
            sa.Column("status", sa.String(32), nullable=False),
            sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        )

        self._ticket_wallets = sa.Table(
            "ticket_wallets",
            self._metadata,
            sa.Column("user_id", sa.String(128), primary_key=True),
            sa.Column("balance", sa.Integer(), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        )

        self._reading_results = sa.Table(
            "reading_results",
            self._metadata,
            sa.Column("session_id", sa.String(64), primary_key=True),
            sa.Column("user_id", sa.String(128), nullable=False, index=True),
            sa.Column("theme_id", sa.String(64), nullable=False),
            sa.Column("deck_id", sa.String(64), nullable=False),
            sa.Column("card_id", sa.String(128), nullable=False),
            sa.Column("card_name", sa.String(255), nullable=False),
            sa.Column("keywords_json", sa.Text(), nullable=False),
            sa.Column("interpretation_text", sa.Text(), nullable=False),
            sa.Column("caution_text", sa.Text(), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("copied", sa.Boolean(), nullable=False),
        )

        self._reading_history = sa.Table(
            "reading_history",
            self._metadata,
            sa.Column("history_id", sa.String(64), primary_key=True),
            sa.Column("user_id", sa.String(128), nullable=False, index=True),
            sa.Column("session_id", sa.String(64), nullable=False),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, index=True),
            sa.Column("theme_id", sa.String(64), nullable=False),
            sa.Column("deck_id", sa.String(64), nullable=False),
            sa.Column("card_id", sa.String(128), nullable=False),
            sa.Column("summary", sa.Text(), nullable=False),
            sa.Column("full_text", sa.Text(), nullable=False),
            sa.Column("plan_at_creation", sa.String(32), nullable=False),
            # 2026-09-12 追加。既存行のために server_default を置く（移行 002）。
            sa.Column(
                "spread_id",
                sa.String(64),
                nullable=False,
                server_default="daily",
            ),
        )

        self._announcements = sa.Table(
            "announcements",
            self._metadata,
            sa.Column("announcement_id", sa.String(64), primary_key=True),
            sa.Column("title", sa.String(255), nullable=False),
            sa.Column("body", sa.Text(), nullable=False),
            sa.Column("category", sa.String(64), nullable=False),
            sa.Column("start_at", sa.DateTime(timezone=True), nullable=False, index=True),
            sa.Column("end_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("is_important", sa.Boolean(), nullable=False),
            sa.Column("link_url", sa.Text(), nullable=True),
        )

        self._inquiries = sa.Table(
            "inquiries",
            self._metadata,
            sa.Column("inquiry_id", sa.String(64), primary_key=True),
            sa.Column("user_id", sa.String(128), nullable=False, index=True),
            sa.Column("category", sa.String(128), nullable=False),
            sa.Column("body", sa.Text(), nullable=False),
            sa.Column("email", sa.String(255), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, index=True),
        )

        self._audit_logs = sa.Table(
            "audit_logs",
            self._metadata,
            sa.Column("audit_id", sa.String(64), primary_key=True),
            sa.Column("actor_type", sa.String(64), nullable=False),
            sa.Column("actor_id", sa.String(128), nullable=False),
            sa.Column("action", sa.String(128), nullable=False),
            sa.Column("resource_type", sa.String(64), nullable=False),
            sa.Column("resource_id", sa.String(128), nullable=True),
            sa.Column("detail_json", sa.Text(), nullable=False),
            sa.Column("occurred_at", sa.DateTime(timezone=True), nullable=False, index=True),
        )

    def initialize_schema(self) -> None:
        self._metadata.create_all(self._engine)

    def check_connection(self) -> None:
        with self._engine.connect() as connection:
            connection.execute(self._sa.text("SELECT 1"))

    def close(self) -> None:
        self._engine.dispose()

    def upsert_user(self, user: User) -> None:
        postgres_insert = _import_postgres_insert()
        user_statement = postgres_insert(self._users).values(
            user_id=user.user_id,
            plan=user.plan.value,
            tickets=user.tickets,
            subscription_expires_at=user.subscription_expires_at,
            created_at=user.created_at,
            updated_at=user.updated_at,
            visit_count=user.visit_count,
        )
        user_statement = user_statement.on_conflict_do_update(
            index_elements=["user_id"],
            set_={
                "plan": user_statement.excluded.plan,
                "tickets": user_statement.excluded.tickets,
                "subscription_expires_at": user_statement.excluded.subscription_expires_at,
                "updated_at": user_statement.excluded.updated_at,
                "visit_count": user_statement.excluded.visit_count,
            },
        )

        sub_statement = postgres_insert(self._subscriptions).values(
            user_id=user.user_id,
            plan_id=(
                "subscription_monthly_500"
                if user.plan == PlanType.SUBSCRIPTION
                else user.plan.value
            ),
            status="active" if user.plan == PlanType.SUBSCRIPTION else "inactive",
            expires_at=user.subscription_expires_at,
            updated_at=user.updated_at,
        )
        sub_statement = sub_statement.on_conflict_do_update(
            index_elements=["user_id"],
            set_={
                "plan_id": sub_statement.excluded.plan_id,
                "status": sub_statement.excluded.status,
                "expires_at": sub_statement.excluded.expires_at,
                "updated_at": sub_statement.excluded.updated_at,
            },
        )

        wallet_statement = postgres_insert(self._ticket_wallets).values(
            user_id=user.user_id,
            balance=user.tickets,
            updated_at=user.updated_at,
        )
        wallet_statement = wallet_statement.on_conflict_do_update(
            index_elements=["user_id"],
            set_={
                "balance": wallet_statement.excluded.balance,
                "updated_at": wallet_statement.excluded.updated_at,
            },
        )

        with self._engine.begin() as connection:
            connection.execute(user_statement)
            connection.execute(sub_statement)
            connection.execute(wallet_statement)

    def fetch_user(self, user_id: str) -> User | None:
        query = self._sa.select(self._users).where(self._users.c.user_id == user_id)
        with self._engine.connect() as connection:
            row = connection.execute(query).mappings().first()

        if row is None:
            return None

        return User(
            user_id=row["user_id"],
            plan=PlanType(row["plan"]),
            tickets=int(row["tickets"]),
            subscription_expires_at=_to_datetime_or_none(row["subscription_expires_at"]),
            created_at=_to_datetime(row["created_at"]),
            updated_at=_to_datetime(row["updated_at"]),
            visit_count=int(row["visit_count"]),
        )

    def fetch_users(self, limit: int = 500) -> list[User]:
        query = (
            self._sa.select(self._users)
            .order_by(self._users.c.created_at.asc())
            .limit(limit)
        )
        with self._engine.connect() as connection:
            rows = connection.execute(query).mappings().all()

        return [
            User(
                user_id=row["user_id"],
                plan=PlanType(row["plan"]),
                tickets=int(row["tickets"]),
                subscription_expires_at=_to_datetime_or_none(row["subscription_expires_at"]),
                created_at=_to_datetime(row["created_at"]),
                updated_at=_to_datetime(row["updated_at"]),
                visit_count=int(row["visit_count"]),
            )
            for row in rows
        ]

    def upsert_announcement(self, announcement: Announcement) -> None:
        postgres_insert = _import_postgres_insert()
        statement = postgres_insert(self._announcements).values(
            announcement_id=announcement.announcement_id,
            title=announcement.title,
            body=announcement.body,
            category=announcement.category,
            start_at=announcement.start_at,
            end_at=announcement.end_at,
            is_important=announcement.is_important,
            link_url=announcement.link_url,
        )
        statement = statement.on_conflict_do_update(
            index_elements=["announcement_id"],
            set_={
                "title": statement.excluded.title,
                "body": statement.excluded.body,
                "category": statement.excluded.category,
                "start_at": statement.excluded.start_at,
                "end_at": statement.excluded.end_at,
                "is_important": statement.excluded.is_important,
                "link_url": statement.excluded.link_url,
            },
        )

        with self._engine.begin() as connection:
            connection.execute(statement)

    def fetch_active_announcements(self, now: datetime) -> list[Announcement]:
        query = (
            self._sa.select(self._announcements)
            .where(self._announcements.c.start_at <= now)
            .where(self._announcements.c.end_at >= now)
            .order_by(self._announcements.c.start_at.desc())
        )
        with self._engine.connect() as connection:
            rows = connection.execute(query).mappings().all()

        return [
            Announcement(
                announcement_id=row["announcement_id"],
                title=row["title"],
                body=row["body"],
                category=row["category"],
                start_at=_to_datetime(row["start_at"]),
                end_at=_to_datetime(row["end_at"]),
                is_important=bool(row["is_important"]),
                link_url=row["link_url"],
            )
            for row in rows
        ]

    def fetch_all_announcements(self, limit: int = 500) -> list[Announcement]:
        query = (
            self._sa.select(self._announcements)
            .order_by(self._announcements.c.start_at.desc())
            .limit(limit)
        )
        with self._engine.connect() as connection:
            rows = connection.execute(query).mappings().all()

        return [
            Announcement(
                announcement_id=row["announcement_id"],
                title=row["title"],
                body=row["body"],
                category=row["category"],
                start_at=_to_datetime(row["start_at"]),
                end_at=_to_datetime(row["end_at"]),
                is_important=bool(row["is_important"]),
                link_url=row["link_url"],
            )
            for row in rows
        ]

    def insert_inquiry(self, inquiry: Inquiry) -> None:
        postgres_insert = _import_postgres_insert()
        statement = postgres_insert(self._inquiries).values(
            inquiry_id=inquiry.inquiry_id,
            user_id=inquiry.user_id,
            category=inquiry.category,
            body=inquiry.body,
            email=inquiry.email,
            created_at=inquiry.created_at,
        )
        statement = statement.on_conflict_do_nothing(index_elements=["inquiry_id"])

        with self._engine.begin() as connection:
            connection.execute(statement)

    def fetch_inquiries(self, limit: int = 500) -> list[Inquiry]:
        query = (
            self._sa.select(self._inquiries)
            .order_by(self._inquiries.c.created_at.desc())
            .limit(limit)
        )
        with self._engine.connect() as connection:
            rows = connection.execute(query).mappings().all()

        return [
            Inquiry(
                inquiry_id=row["inquiry_id"],
                user_id=row["user_id"],
                category=row["category"],
                body=row["body"],
                email=row["email"],
                created_at=_to_datetime(row["created_at"]),
            )
            for row in rows
        ]

    def insert_audit_log(self, audit_log: AuditLog) -> None:
        postgres_insert = _import_postgres_insert()
        statement = postgres_insert(self._audit_logs).values(
            audit_id=audit_log.audit_id,
            actor_type=audit_log.actor_type,
            actor_id=audit_log.actor_id,
            action=audit_log.action,
            resource_type=audit_log.resource_type,
            resource_id=audit_log.resource_id,
            detail_json=json.dumps(audit_log.detail, ensure_ascii=False),
            occurred_at=audit_log.occurred_at,
        )
        statement = statement.on_conflict_do_nothing(index_elements=["audit_id"])
        with self._engine.begin() as connection:
            connection.execute(statement)

    def fetch_audit_logs(self, limit: int = 500) -> list[AuditLog]:
        query = (
            self._sa.select(self._audit_logs)
            .order_by(self._audit_logs.c.occurred_at.desc())
            .limit(limit)
        )
        with self._engine.connect() as connection:
            rows = connection.execute(query).mappings().all()

        logs: list[AuditLog] = []
        for row in rows:
            detail = json.loads(str(row["detail_json"]))
            logs.append(
                AuditLog(
                    audit_id=row["audit_id"],
                    actor_type=row["actor_type"],
                    actor_id=row["actor_id"],
                    action=row["action"],
                    resource_type=row["resource_type"],
                    resource_id=row["resource_id"],
                    detail=detail if isinstance(detail, dict) else {},
                    occurred_at=_to_datetime(row["occurred_at"]),
                )
            )
        return logs

    def upsert_reading_result(self, result: ReadingResult) -> None:
        postgres_insert = _import_postgres_insert()
        payload = {
            "session_id": result.session_id,
            "user_id": result.user_id,
            "theme_id": result.theme_id,
            "deck_id": result.deck_id,
            "card_id": result.card_id,
            "card_name": result.card_name,
            "keywords_json": json.dumps(result.keywords, ensure_ascii=False),
            "interpretation_text": result.interpretation_text,
            "caution_text": result.caution_text,
            "created_at": result.created_at,
            "copied": result.copied,
        }

        statement = postgres_insert(self._reading_results).values(**payload)
        statement = statement.on_conflict_do_update(
            index_elements=["session_id"],
            set_={
                "card_name": statement.excluded.card_name,
                "keywords_json": statement.excluded.keywords_json,
                "interpretation_text": statement.excluded.interpretation_text,
                "caution_text": statement.excluded.caution_text,
                "created_at": statement.excluded.created_at,
                "copied": statement.excluded.copied,
            },
        )

        with self._engine.begin() as connection:
            connection.execute(statement)

    def fetch_reading_result(self, session_id: str) -> ReadingResult | None:
        query = self._sa.select(self._reading_results).where(
            self._reading_results.c.session_id == session_id
        )
        with self._engine.connect() as connection:
            row = connection.execute(query).mappings().first()

        if row is None:
            return None

        return ReadingResult(
            session_id=row["session_id"],
            user_id=row["user_id"],
            theme_id=row["theme_id"],
            deck_id=row["deck_id"],
            card_id=row["card_id"],
            card_name=row["card_name"],
            keywords=list(json.loads(str(row["keywords_json"]))),
            interpretation_text=row["interpretation_text"],
            caution_text=row["caution_text"],
            created_at=_to_datetime(row["created_at"]),
            copied=bool(row["copied"]),
        )

    def insert_history_item(self, item: HistoryItem) -> None:
        postgres_insert = _import_postgres_insert()
        statement = postgres_insert(self._reading_history).values(
            history_id=item.history_id,
            user_id=item.user_id,
            session_id=item.session_id,
            created_at=item.created_at,
            theme_id=item.theme_id,
            deck_id=item.deck_id,
            card_id=item.card_id,
            summary=item.summary,
            full_text=item.full_text,
            plan_at_creation=item.plan_at_creation.value,
            spread_id=item.spread_id,
        )
        statement = statement.on_conflict_do_nothing(index_elements=["history_id"])

        with self._engine.begin() as connection:
            connection.execute(statement)

    def delete_history_item(self, user_id: str, history_id: str) -> None:
        statement = (
            self._sa.delete(self._reading_history)
            .where(self._reading_history.c.history_id == history_id)
            .where(self._reading_history.c.user_id == user_id)
        )
        with self._engine.begin() as connection:
            connection.execute(statement)

    def fetch_history(self, user_id: str, limit: int = 100) -> list[HistoryItem]:
        query = (
            self._sa.select(self._reading_history)
            .where(self._reading_history.c.user_id == user_id)
            .order_by(self._reading_history.c.created_at.desc())
            .limit(limit)
        )

        with self._engine.connect() as connection:
            rows = connection.execute(query).mappings().all()

        items: list[HistoryItem] = []
        for row in rows:
            items.append(
                HistoryItem(
                    history_id=row["history_id"],
                    user_id=row["user_id"],
                    session_id=row["session_id"],
                    created_at=_to_datetime(row["created_at"]),
                    theme_id=row["theme_id"],
                    deck_id=row["deck_id"],
                    card_id=row["card_id"],
                    summary=row["summary"],
                    full_text=row["full_text"],
                    plan_at_creation=PlanType(row["plan_at_creation"]),
                    spread_id=row["spread_id"] or "daily",
                )
            )
        return items

    def trim_history_for_user(self, user_id: str, max_items: int) -> None:
        if max_items <= 0:
            delete_all = self._reading_history.delete().where(
                self._reading_history.c.user_id == user_id
            )
            with self._engine.begin() as connection:
                connection.execute(delete_all)
            return

        trim_sql = self._sa.text(
            """
            DELETE FROM reading_history
            WHERE user_id = :user_id
              AND history_id NOT IN (
                SELECT history_id
                FROM reading_history
                WHERE user_id = :user_id
                ORDER BY created_at DESC
                LIMIT :max_items
              )
            """
        )

        with self._engine.begin() as connection:
            connection.execute(trim_sql, {"user_id": user_id, "max_items": max_items})


def _to_datetime(raw: Any) -> datetime:
    if isinstance(raw, datetime):
        return raw
    return datetime.fromisoformat(str(raw))


def _to_datetime_or_none(raw: Any) -> datetime | None:
    if raw is None:
        return None
    return _to_datetime(raw)



def _import_sqlalchemy() -> Any:
    try:
        import sqlalchemy as sa  # type: ignore
    except ImportError as exc:
        raise RuntimeError(
            "PostgreSQL persistence requires sqlalchemy and psycopg. "
            "Install with: pip install sqlalchemy psycopg[binary]"
        ) from exc
    return sa



def _import_postgres_insert():
    try:
        from sqlalchemy.dialects.postgresql import insert as postgres_insert  # type: ignore
    except ImportError as exc:
        raise RuntimeError(
            "PostgreSQL persistence requires sqlalchemy postgresql dialect support."
        ) from exc
    return postgres_insert
