from __future__ import annotations

import contextlib
import contextvars
import dataclasses
import os
import sqlite3
from contextlib import closing
from typing import Any, Mapping, Optional

from http_helpers import utc_now_iso
from subscription_event_model import (
    SubscriptionEvent,
    canonical_payload_json,
    event_type_for_payload,
    payload_hash,
)


class SubscriptionEventReplay(RuntimeError):
    pass


@dataclasses.dataclass(frozen=True)
class SubscriptionEventAppendResult:
    event_id: int
    appended: bool
    event: SubscriptionEvent


_ACTIVE_EVENT_STORE_APPEND: contextvars.ContextVar[bool] = contextvars.ContextVar(
    "fleet_ledger_active_event_store_append",
    default=False,
)


class SubscriptionEventStore:
    """Append-only source of truth for subscription events."""

    def __init__(self, db_path_or_store: Any):
        if isinstance(db_path_or_store, str):
            self.db_path = db_path_or_store
        else:
            self.db_path = str(db_path_or_store.db_path)
        parent = os.path.dirname(os.path.abspath(self.db_path))
        if parent:
            os.makedirs(parent, exist_ok=True)
        self._init_schema()

    def append(self, event: Any) -> int:
        return self.append_with_result(event).event_id

    def append_with_result(
        self,
        event: Any,
        *,
        authority_score: int = 0,
        event_type: Optional[str] = None,
        event_time: Optional[str] = None,
        payload_digest: Optional[str] = None,
        server_time: Optional[str] = None,
        event_version: Optional[int] = None,
    ) -> SubscriptionEventAppendResult:
        raw_payload = _raw_payload_for_event(event)
        normalized_hash = payload_digest or payload_hash(raw_payload)
        transaction_id = _required_text(getattr(event, "transaction_id", None), "transaction_id")
        with closing(self._connect()) as conn:
            with conn:
                existing = conn.execute(
                    """
                    SELECT *
                    FROM iap_subscription_events
                    WHERE transaction_id = ?
                    """,
                    (transaction_id,),
                ).fetchone()
                if existing is not None:
                    existing_event = SubscriptionEvent.from_row(existing)
                    if existing_event.payload_hash == normalized_hash:
                        return SubscriptionEventAppendResult(
                            event_id=existing_event.event_id,
                            appended=False,
                            event=existing_event,
                        )
                    raise SubscriptionEventReplay(
                        "transaction_id already exists with a different payload"
                    )

                normalized_event_type = (
                    event_type
                    or event_type_for_payload(raw_payload)
                )
                normalized_server_time = server_time or utc_now_iso()
                normalized_event_time = _optional_text(event_time) or _optional_text(
                    getattr(event, "event_time", None)
                )
                normalized_event_version = event_version
                if normalized_event_version is None:
                    raw_version = getattr(event, "event_version", None)
                    normalized_event_version = int(raw_version) if raw_version is not None else None
                with self._authorized_append():
                    cursor = conn.execute(
                        """
                        INSERT INTO iap_subscription_events (
                          user_id, product_id, channel, event_type, authority_score,
                          event_time, server_time, payload_hash, transaction_id,
                          source, event_version, raw_payload_json
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                        (
                            _required_text(getattr(event, "user_id", None), "user_id"),
                            _required_text(getattr(event, "product_id", None), "product_id"),
                            _required_text(getattr(event, "channel", None), "channel"),
                            _required_text(normalized_event_type, "event_type"),
                            int(authority_score),
                            normalized_event_time,
                            normalized_server_time,
                            normalized_hash,
                            transaction_id,
                            _optional_text(getattr(event, "source", None)),
                            normalized_event_version,
                            canonical_payload_json(raw_payload),
                        ),
                    )
                event_id = int(cursor.lastrowid)
                row = conn.execute(
                    """
                    SELECT *
                    FROM iap_subscription_events
                    WHERE event_id = ?
                    """,
                    (event_id,),
                ).fetchone()
        return SubscriptionEventAppendResult(
            event_id=event_id,
            appended=True,
            event=SubscriptionEvent.from_row(row),
        )

    def get_events(self, user_id: str) -> list[SubscriptionEvent]:
        with closing(self._connect()) as conn:
            rows = conn.execute(
                """
                SELECT *
                FROM iap_subscription_events
                WHERE user_id = ?
                ORDER BY event_id ASC
                """,
                (_required_text(user_id, "user_id"),),
            ).fetchall()
        return [SubscriptionEvent.from_row(row) for row in rows]

    def get_events_by_time_range(
        self,
        *,
        start_time: Optional[str] = None,
        end_time: Optional[str] = None,
        user_id: Optional[str] = None,
    ) -> list[SubscriptionEvent]:
        clauses = []
        parameters: list[Any] = []
        if start_time is not None:
            clauses.append("server_time >= ?")
            parameters.append(start_time)
        if end_time is not None:
            clauses.append("server_time <= ?")
            parameters.append(end_time)
        if user_id is not None:
            clauses.append("user_id = ?")
            parameters.append(_required_text(user_id, "user_id"))
        where = f"WHERE {' AND '.join(clauses)}" if clauses else ""
        with closing(self._connect()) as conn:
            rows = conn.execute(
                f"""
                SELECT *
                FROM iap_subscription_events
                {where}
                ORDER BY event_id ASC
                """,
                tuple(parameters),
            ).fetchall()
        return [SubscriptionEvent.from_row(row) for row in rows]

    def get_all_events(self) -> list[SubscriptionEvent]:
        with closing(self._connect()) as conn:
            rows = conn.execute(
                """
                SELECT *
                FROM iap_subscription_events
                ORDER BY event_id ASC
                """
            ).fetchall()
        return [SubscriptionEvent.from_row(row) for row in rows]

    def list_user_ids(self) -> list[str]:
        with closing(self._connect()) as conn:
            rows = conn.execute(
                """
                SELECT DISTINCT user_id
                FROM iap_subscription_events
                ORDER BY user_id ASC
                """
            ).fetchall()
        return [str(row["user_id"]) for row in rows]

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        conn.create_function(
            "subscription_event_store_write_allowed",
            0,
            lambda: 1 if _ACTIVE_EVENT_STORE_APPEND.get() else 0,
        )
        return conn

    def _init_schema(self) -> None:
        with closing(self._connect()) as conn:
            with conn:
                conn.execute(
                    """
                    CREATE TABLE IF NOT EXISTS iap_subscription_events (
                      event_id INTEGER PRIMARY KEY AUTOINCREMENT,
                      user_id TEXT NOT NULL,
                      product_id TEXT NOT NULL,
                      channel TEXT NOT NULL,
                      event_type TEXT NOT NULL,
                      authority_score INTEGER NOT NULL,
                      event_time TEXT,
                      server_time TEXT NOT NULL,
                      payload_hash TEXT NOT NULL,
                      transaction_id TEXT NOT NULL UNIQUE,
                      source TEXT,
                      event_version INTEGER,
                      raw_payload_json TEXT NOT NULL
                    )
                    """
                )
                conn.execute(
                    """
                    CREATE INDEX IF NOT EXISTS idx_iap_subscription_events_user_id
                    ON iap_subscription_events(user_id, event_id)
                    """
                )
                conn.execute(
                    """
                    CREATE INDEX IF NOT EXISTS idx_iap_subscription_events_time
                    ON iap_subscription_events(server_time, event_id)
                    """
                )
                conn.execute(
                    """
                    CREATE TRIGGER IF NOT EXISTS guard_iap_subscription_events_insert
                    BEFORE INSERT ON iap_subscription_events
                    WHEN subscription_event_store_write_allowed() != 1
                    BEGIN
                      SELECT RAISE(ABORT, 'iap_subscription_events only accepts SubscriptionEventStore appends');
                    END
                    """
                )
                conn.execute(
                    """
                    CREATE TRIGGER IF NOT EXISTS prevent_iap_subscription_events_update
                    BEFORE UPDATE ON iap_subscription_events
                    BEGIN
                      SELECT RAISE(ABORT, 'iap_subscription_events is append-only');
                    END
                    """
                )
                conn.execute(
                    """
                    CREATE TRIGGER IF NOT EXISTS prevent_iap_subscription_events_delete
                    BEFORE DELETE ON iap_subscription_events
                    BEGIN
                      SELECT RAISE(ABORT, 'iap_subscription_events is append-only');
                    END
                    """
                )

    @contextlib.contextmanager
    def _authorized_append(self):
        token = _ACTIVE_EVENT_STORE_APPEND.set(True)
        try:
            yield
        finally:
            _ACTIVE_EVENT_STORE_APPEND.reset(token)


def _raw_payload_for_event(event: Any) -> Mapping[str, Any]:
    raw_payload = getattr(event, "raw_payload", None)
    if not isinstance(raw_payload, Mapping):
        raise ValueError("raw_payload is required")
    return raw_payload


def _required_text(value: Any, field_name: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{field_name} is required")
    return value.strip()


def _optional_text(value: Any) -> Optional[str]:
    if not isinstance(value, str):
        return None
    normalized = value.strip()
    return normalized or None
