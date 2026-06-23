from __future__ import annotations

import dataclasses
import os
import sqlite3
from contextlib import closing
from typing import Any, Dict, List, Optional

from http_helpers import utc_now_iso


@dataclasses.dataclass(frozen=True)
class IncomingChange:
    entity_type: str
    entity_id: str
    operation: str
    base_version: int
    payload_json: str
    payload_hash: str
    origin_device_id: Optional[str] = None

    @property
    def deleted(self) -> int:
        return 1 if self.operation == "delete" else 0

    @property
    def entity(self) -> Dict[str, str]:
        return {"entity_type": self.entity_type, "entity_id": self.entity_id}


class SyncStore:
    def __init__(self, db_path: str):
        self.db_path = db_path
        parent = os.path.dirname(os.path.abspath(db_path))
        if parent:
            os.makedirs(parent, exist_ok=True)
        self._init_schema()

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn

    def _init_schema(self) -> None:
        with closing(self._connect()) as conn:
            with conn:
                conn.execute("PRAGMA foreign_keys = ON")
                conn.execute(
                    """
                    CREATE TABLE IF NOT EXISTS sync_changes (
                      account_id TEXT NOT NULL,
                      server_seq INTEGER NOT NULL,
                      entity_type TEXT NOT NULL,
                      entity_id TEXT NOT NULL,
                      base_version INTEGER NOT NULL,
                      new_version INTEGER NOT NULL,
                      payload_json TEXT NOT NULL,
                      payload_hash TEXT NOT NULL,
                      deleted INTEGER NOT NULL,
                      origin_device_id TEXT,
                      server_ts TEXT NOT NULL,
                      PRIMARY KEY(account_id, server_seq)
                    )
                    """
                )
                conn.execute(
                    """
                    CREATE INDEX IF NOT EXISTS idx_sync_changes_entity_head
                    ON sync_changes(account_id, entity_type, entity_id, new_version DESC)
                    """
                )
                conn.execute(
                    """
                    CREATE INDEX IF NOT EXISTS idx_sync_changes_pull
                    ON sync_changes(account_id, server_seq)
                    """
                )
                conn.execute(
                    """
                    CREATE UNIQUE INDEX IF NOT EXISTS idx_sync_changes_idempotency
                    ON sync_changes(account_id, entity_type, entity_id, payload_hash)
                    """
                )
                conn.execute(
                    """
                    CREATE TABLE IF NOT EXISTS sync_devices (
                      account_id TEXT NOT NULL,
                      device_id TEXT NOT NULL,
                      name TEXT NOT NULL,
                      last_seen TEXT NOT NULL,
                      PRIMARY KEY(account_id, device_id)
                    )
                    """
                )
                conn.execute(
                    """
                    CREATE TABLE IF NOT EXISTS sync_entity_heads (
                      account_id TEXT NOT NULL,
                      entity_type TEXT NOT NULL,
                      entity_id TEXT NOT NULL,
                      version INTEGER NOT NULL,
                      deleted INTEGER NOT NULL,
                      payload_hash TEXT NOT NULL,
                      server_seq INTEGER NOT NULL,
                      updated_at TEXT NOT NULL,
                      PRIMARY KEY(account_id, entity_type, entity_id),
                      FOREIGN KEY(account_id, server_seq)
                        REFERENCES sync_changes(account_id, server_seq)
                    )
                    """
                )
                conn.execute(
                    """
                    CREATE INDEX IF NOT EXISTS idx_sync_entity_heads_account
                    ON sync_entity_heads(account_id, entity_type, entity_id)
                    """
                )

    def push_changes(self, account_id: str, changes: List[IncomingChange]) -> Dict[str, List[Dict[str, Any]]]:
        accepted: List[Dict[str, Any]] = []
        conflicts: List[Dict[str, Any]] = []
        conn = self._connect()
        try:
            conn.execute("PRAGMA foreign_keys = ON")
            conn.execute("BEGIN IMMEDIATE")
            for change in changes:
                existing = conn.execute(
                    """
                    SELECT server_seq, new_version
                    FROM sync_changes
                    WHERE account_id = ?
                      AND entity_type = ?
                      AND entity_id = ?
                      AND payload_hash = ?
                    """,
                    (account_id, change.entity_type, change.entity_id, change.payload_hash),
                ).fetchone()
                if existing is not None:
                    accepted.append(
                        {
                            "entity": change.entity,
                            "server_seq": int(existing["server_seq"]),
                            "new_version": int(existing["new_version"]),
                        }
                    )
                    continue

                head = conn.execute(
                    """
                    SELECT version
                    FROM sync_entity_heads
                    WHERE account_id = ? AND entity_type = ? AND entity_id = ?
                    """,
                    (account_id, change.entity_type, change.entity_id),
                ).fetchone()
                current_version = int(head["version"]) if head is not None else 0
                if change.base_version != current_version:
                    conflicts.append(
                        {
                            "entity": change.entity,
                            "server_version": current_version,
                        }
                    )
                    continue

                server_seq = int(
                    conn.execute(
                        "SELECT COALESCE(MAX(server_seq), 0) + 1 AS next_seq FROM sync_changes WHERE account_id = ?",
                        (account_id,),
                    ).fetchone()["next_seq"]
                )
                new_version = current_version + 1
                server_ts = utc_now_iso()
                conn.execute(
                    """
                    INSERT INTO sync_changes (
                      account_id, server_seq, entity_type, entity_id, base_version,
                      new_version, payload_json, payload_hash, deleted,
                      origin_device_id, server_ts
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        account_id,
                        server_seq,
                        change.entity_type,
                        change.entity_id,
                        change.base_version,
                        new_version,
                        change.payload_json,
                        change.payload_hash,
                        change.deleted,
                        change.origin_device_id,
                        server_ts,
                    ),
                )
                conn.execute(
                    """
                    INSERT INTO sync_entity_heads (
                      account_id, entity_type, entity_id, version, deleted,
                      payload_hash, server_seq, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(account_id, entity_type, entity_id) DO UPDATE SET
                      version = excluded.version,
                      deleted = excluded.deleted,
                      payload_hash = excluded.payload_hash,
                      server_seq = excluded.server_seq,
                      updated_at = excluded.updated_at
                    """,
                    (
                        account_id,
                        change.entity_type,
                        change.entity_id,
                        new_version,
                        change.deleted,
                        change.payload_hash,
                        server_seq,
                        server_ts,
                    ),
                )
                accepted.append(
                    {
                        "entity": change.entity,
                        "server_seq": server_seq,
                        "new_version": new_version,
                    }
                )
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()
        return {"accepted": accepted, "conflicts": conflicts}

    def pull_changes(self, account_id: str, since: int, limit: int) -> Dict[str, Any]:
        with closing(self._connect()) as conn:
            with conn:
                rows = conn.execute(
                    """
                    SELECT *
                    FROM sync_changes
                    WHERE account_id = ? AND server_seq > ?
                    ORDER BY server_seq ASC
                    LIMIT ?
                    """,
                    (account_id, since, limit),
                ).fetchall()
        changes = [change_row_to_json(row) for row in rows]
        next_cursor = max((int(row["server_seq"]) for row in rows), default=since)
        return {"changes": changes, "next_cursor": next_cursor}

    def register_device(self, account_id: str, device_id: str, name: str) -> Dict[str, str]:
        last_seen = utc_now_iso()
        with closing(self._connect()) as conn:
            with conn:
                conn.execute(
                    """
                    INSERT INTO sync_devices (account_id, device_id, name, last_seen)
                    VALUES (?, ?, ?, ?)
                    ON CONFLICT(account_id, device_id) DO UPDATE SET
                      name = excluded.name,
                      last_seen = excluded.last_seen
                    """,
                    (account_id, device_id, name, last_seen),
                )
        return {"device_id": device_id, "name": name, "last_seen": last_seen}

    def get_head(self, account_id: str, entity_type: str, entity_id: str) -> Optional[Dict[str, Any]]:
        with closing(self._connect()) as conn:
            with conn:
                row = conn.execute(
                    """
                    SELECT *
                    FROM sync_entity_heads
                    WHERE account_id = ? AND entity_type = ? AND entity_id = ?
                    """,
                    (account_id, entity_type, entity_id),
                ).fetchone()
        return dict(row) if row is not None else None

    def get_device(self, account_id: str, device_id: str) -> Optional[Dict[str, Any]]:
        with closing(self._connect()) as conn:
            with conn:
                row = conn.execute(
                    """
                    SELECT *
                    FROM sync_devices
                    WHERE account_id = ? AND device_id = ?
                    """,
                    (account_id, device_id),
                ).fetchone()
        return dict(row) if row is not None else None

    def count_changes(self, account_id: str) -> int:
        with closing(self._connect()) as conn:
            with conn:
                row = conn.execute(
                    "SELECT COUNT(*) AS count FROM sync_changes WHERE account_id = ?",
                    (account_id,),
                ).fetchone()
        return int(row["count"])


def change_row_to_json(row: sqlite3.Row) -> Dict[str, Any]:
    return {
        "server_seq": int(row["server_seq"]),
        "entity_type": row["entity_type"],
        "entity_id": row["entity_id"],
        "base_version": int(row["base_version"]),
        "new_version": int(row["new_version"]),
        "payload_json": row["payload_json"],
        "payload_hash": row["payload_hash"],
        "deleted": bool(row["deleted"]),
        "origin_device_id": row["origin_device_id"],
        "server_ts": row["server_ts"],
    }
