from __future__ import annotations

import contextlib
import contextvars
import hashlib
import os
import sqlite3
from contextlib import closing
from typing import Any, Optional

from http_helpers import utc_now_iso
from subscription_event_explainer import EventExplanation, explanation_from_json


class SubscriptionExplanationConflict(RuntimeError):
    pass


_ACTIVE_EXPLANATION_STORE_APPEND: contextvars.ContextVar[bool] = contextvars.ContextVar(
    "fleet_ledger_active_explanation_store_append",
    default=False,
)


class SubscriptionEventExplanationStore:
    """Append-only immutable storage for event explanation objects."""

    def __init__(self, db_path_or_store: Any):
        if isinstance(db_path_or_store, str):
            self.db_path = db_path_or_store
        else:
            self.db_path = str(db_path_or_store.db_path)
        parent = os.path.dirname(os.path.abspath(self.db_path))
        if parent:
            os.makedirs(parent, exist_ok=True)
        self._init_schema()

    def store_explanation(self, event_id: int, explanation: EventExplanation) -> bool:
        normalized_event_id = _normalize_event_id(event_id)
        if normalized_event_id != explanation.event_id:
            raise SubscriptionExplanationConflict(
                "explanation event_id does not match storage key"
            )
        explanation_json = explanation.canonical_json()
        explanation_hash = _explanation_hash(explanation_json)
        with closing(self._connect()) as conn:
            with conn:
                existing = conn.execute(
                    """
                    SELECT explanation_hash
                    FROM iap_subscription_event_explanations
                    WHERE event_id = ?
                    ORDER BY id DESC
                    """,
                    (normalized_event_id,),
                ).fetchall()
                if any(str(row["explanation_hash"]) == explanation_hash for row in existing):
                    return False
                with self._authorized_append():
                    conn.execute(
                        """
                        INSERT INTO iap_subscription_event_explanations (
                          event_id, user_id, explanation_json,
                          explanation_hash, created_at
                        ) VALUES (?, ?, ?, ?, ?)
                        """,
                        (
                            normalized_event_id,
                            _normalize_required(explanation.user_id, "user_id"),
                            explanation_json,
                            explanation_hash,
                            utc_now_iso(),
                        ),
                    )
        return True

    def get_explanation(self, user_id: str) -> list[EventExplanation]:
        with closing(self._connect()) as conn:
            rows = conn.execute(
                """
                SELECT explanation_json
                FROM iap_subscription_event_explanations
                WHERE id IN (
                  SELECT MAX(id)
                  FROM iap_subscription_event_explanations
                  WHERE user_id = ?
                  GROUP BY event_id
                )
                ORDER BY event_id ASC
                """,
                (_normalize_required(user_id, "user_id"),),
            ).fetchall()
        return [explanation_from_json(str(row["explanation_json"])) for row in rows]

    def get_explanation_by_event(self, event_id: int) -> Optional[EventExplanation]:
        with closing(self._connect()) as conn:
            row = conn.execute(
                """
                SELECT explanation_json
                FROM iap_subscription_event_explanations
                WHERE event_id = ?
                ORDER BY id DESC
                LIMIT 1
                """,
                (_normalize_event_id(event_id),),
            ).fetchone()
        if row is None:
            return None
        return explanation_from_json(str(row["explanation_json"]))

    def explained_event_ids(self, user_id: Optional[str] = None) -> set[int]:
        parameters: tuple[Any, ...] = ()
        where = ""
        if user_id is not None:
            where = "WHERE user_id = ?"
            parameters = (_normalize_required(user_id, "user_id"),)
        with closing(self._connect()) as conn:
            rows = conn.execute(
                f"""
                SELECT event_id
                FROM iap_subscription_event_explanations
                {where}
                GROUP BY event_id
                ORDER BY event_id ASC
                """,
                parameters,
            ).fetchall()
        return {int(row["event_id"]) for row in rows}

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        conn.create_function(
            "subscription_explanation_store_write_allowed",
            0,
            lambda: 1 if _ACTIVE_EXPLANATION_STORE_APPEND.get() else 0,
        )
        return conn

    def _init_schema(self) -> None:
        with closing(self._connect()) as conn:
            with conn:
                conn.execute(
                    """
                    CREATE TABLE IF NOT EXISTS iap_subscription_event_explanations (
                      id INTEGER PRIMARY KEY AUTOINCREMENT,
                      event_id INTEGER NOT NULL,
                      user_id TEXT NOT NULL,
                      explanation_json TEXT NOT NULL,
                      explanation_hash TEXT NOT NULL,
                      created_at TEXT NOT NULL
                    )
                    """
                )
                conn.execute(
                    """
                    CREATE INDEX IF NOT EXISTS idx_iap_subscription_event_explanations_user
                    ON iap_subscription_event_explanations(user_id, event_id)
                    """
                )
                conn.execute(
                    """
                    CREATE INDEX IF NOT EXISTS idx_iap_subscription_event_explanations_event
                    ON iap_subscription_event_explanations(event_id, id)
                    """
                )
                conn.execute(
                    """
                    CREATE TRIGGER IF NOT EXISTS guard_iap_subscription_event_explanations_insert
                    BEFORE INSERT ON iap_subscription_event_explanations
                    WHEN subscription_explanation_store_write_allowed() != 1
                    BEGIN
                      SELECT RAISE(ABORT, 'iap_subscription_event_explanations only accepts SubscriptionEventExplanationStore appends');
                    END
                    """
                )
                conn.execute(
                    """
                    CREATE TRIGGER IF NOT EXISTS prevent_iap_subscription_event_explanations_update
                    BEFORE UPDATE ON iap_subscription_event_explanations
                    BEGIN
                      SELECT RAISE(ABORT, 'iap_subscription_event_explanations is append-only');
                    END
                    """
                )
                conn.execute(
                    """
                    CREATE TRIGGER IF NOT EXISTS prevent_iap_subscription_event_explanations_delete
                    BEFORE DELETE ON iap_subscription_event_explanations
                    BEGIN
                      SELECT RAISE(ABORT, 'iap_subscription_event_explanations is append-only');
                    END
                    """
                )

    @contextlib.contextmanager
    def _authorized_append(self):
        token = _ACTIVE_EXPLANATION_STORE_APPEND.set(True)
        try:
            yield
        finally:
            _ACTIVE_EXPLANATION_STORE_APPEND.reset(token)


def _explanation_hash(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def _normalize_event_id(value: int) -> int:
    normalized = int(value)
    if normalized <= 0:
        raise ValueError("event_id must be positive")
    return normalized


def _normalize_required(value: str, name: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{name} is required")
    return value.strip()
