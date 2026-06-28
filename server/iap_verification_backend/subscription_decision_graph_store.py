from __future__ import annotations

import os
import sqlite3
from contextlib import closing
from typing import Any, Optional

from http_helpers import utc_now_iso
from subscription_decision_graph import DecisionGraph


class SubscriptionDecisionGraphStore:
    """Cache-only graph snapshot store; never source of truth for billing state."""

    def __init__(self, db_path_or_store: Any):
        if isinstance(db_path_or_store, str):
            self.db_path = db_path_or_store
        else:
            self.db_path = str(db_path_or_store.db_path)
        parent = os.path.dirname(os.path.abspath(self.db_path))
        if parent:
            os.makedirs(parent, exist_ok=True)

    def store_graph(self, graph: DecisionGraph) -> None:
        self._init_schema()
        with closing(self._connect()) as conn:
            with conn:
                conn.execute(
                    """
                    INSERT INTO iap_subscription_decision_graph_cache (
                      user_id, graph_id, graph_json, generated_at, cached_at
                    ) VALUES (?, ?, ?, ?, ?)
                    ON CONFLICT(user_id) DO UPDATE SET
                      graph_id = excluded.graph_id,
                      graph_json = excluded.graph_json,
                      generated_at = excluded.generated_at,
                      cached_at = excluded.cached_at
                    """,
                    (
                        graph.user_id,
                        graph.graph_id,
                        graph.canonical_json(),
                        graph.generated_at,
                        utc_now_iso(),
                    ),
                )

    def get_latest_graph(self, user_id: str) -> Optional[dict[str, Any]]:
        self._init_schema()
        with closing(self._connect()) as conn:
            row = conn.execute(
                """
                SELECT graph_id, graph_json, generated_at, cached_at
                FROM iap_subscription_decision_graph_cache
                WHERE user_id = ?
                """,
                (user_id,),
            ).fetchone()
        if row is None:
            return None
        return {
            "graph_id": row["graph_id"],
            "graph_json": row["graph_json"],
            "generated_at": row["generated_at"],
            "cached_at": row["cached_at"],
            "cache_only": True,
        }

    def delete_cached_graph(self, user_id: str) -> None:
        self._init_schema()
        with closing(self._connect()) as conn:
            with conn:
                conn.execute(
                    """
                    DELETE FROM iap_subscription_decision_graph_cache
                    WHERE user_id = ?
                    """,
                    (user_id,),
                )

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn

    def _init_schema(self) -> None:
        with closing(self._connect()) as conn:
            with conn:
                conn.execute(
                    """
                    CREATE TABLE IF NOT EXISTS iap_subscription_decision_graph_cache (
                      user_id TEXT PRIMARY KEY,
                      graph_id TEXT NOT NULL,
                      graph_json TEXT NOT NULL,
                      generated_at TEXT NOT NULL,
                      cached_at TEXT NOT NULL
                    )
                    """
                )
