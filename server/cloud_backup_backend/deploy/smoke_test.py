#!/usr/bin/env python3
"""Smoke test for the FleetLedger cloud backup backend.

The script never prints bearer tokens or backup payload bodies.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from typing import Any, Dict, Optional, Tuple


OPENER = urllib.request.build_opener(urllib.request.ProxyHandler({}))


def make_envelope() -> Dict[str, Any]:
    payload_json = json.dumps(
        {"data": {"devices": [{"id": "smoke-device", "name": "Smoke Test"}]}},
        separators=(",", ":"),
    )
    return {
        "kind": "cloud_backup",
        "format_version": 1,
        "created_at": "2026-06-12T00:00:00.000Z",
        "db_schema_version": 36,
        "payload_sha256": hashlib.sha256(payload_json.encode("utf-8")).hexdigest(),
        "payload_bytes": len(payload_json.encode("utf-8")),
        "payload_json": payload_json,
    }


def request(
    base_url: str,
    method: str,
    path: str,
    *,
    token: Optional[str] = None,
    body: Optional[Dict[str, Any]] = None,
    timeout: int = 30,
) -> Tuple[int, Dict[str, Any]]:
    data = None
    headers = {"Accept": "application/json"}
    if body is not None:
        data = json.dumps(body, separators=(",", ":")).encode("utf-8")
        headers["Content-Type"] = "application/json"
    if token:
        headers["Authorization"] = f"Bearer {token}"
    url = urllib.parse.urljoin(base_url.rstrip("/") + "/", path.lstrip("/"))
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with OPENER.open(req, timeout=timeout) as response:
            raw = response.read()
            return response.status, decode_json(raw)
    except urllib.error.HTTPError as exc:
        return exc.code, decode_json(exc.read())


def decode_json(raw: bytes) -> Dict[str, Any]:
    if not raw:
        return {}
    decoded = json.loads(raw.decode("utf-8"))
    if not isinstance(decoded, dict):
        raise RuntimeError("response is not a JSON object")
    return decoded


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", required=True, help="https://backup-api.example.com")
    parser.add_argument("--token", help="test account bearer token")
    parser.add_argument("--other-token", help="second test account bearer token")
    parser.add_argument(
        "--auth-only",
        action="store_true",
        help="only verify that unauthenticated /v1/backups is rejected",
    )
    args = parser.parse_args()

    status, body = request(args.base_url, "GET", "/v1/backups")
    require(status == 401, f"expected unauthenticated GET /v1/backups to return 401, got {status}")
    print("PASS unauthenticated /v1/backups returns 401")

    status, body = request(args.base_url, "GET", "/v1/account/backup-key")
    require(
        status == 401,
        f"expected unauthenticated GET /v1/account/backup-key to return 401, got {status}",
    )
    print("PASS unauthenticated /v1/account/backup-key returns 401")

    if args.auth_only:
        return 0
    require(args.token, "--token is required unless --auth-only is set")

    status, body = request(args.base_url, "GET", "/v1/account/backup-key", token=args.token)
    require(status == 200, f"expected backup-key to return 200, got {status} (set FLEET_BACKUP_ACCOUNT_KEY_SECRET?)")
    secret = body.get("backup_secret")
    require(isinstance(secret, str) and len(secret) >= 32, "backup_secret missing or too short")
    # Stable per-account: a second call returns the same secret.
    status2, body2 = request(args.base_url, "GET", "/v1/account/backup-key", token=args.token)
    require(status2 == 200, f"expected repeated backup-key to return 200, got {status2}")
    require(body2.get("backup_secret") == secret, "backup_secret is not stable across calls")
    print("PASS account backup-key is issued and stable (encryption can activate)")

    status, body = request(args.base_url, "POST", "/v1/backups", token=args.token, body=make_envelope())
    require(status == 200, f"expected upload to return 200, got {status}")
    backup_id = body.get("backup_id")
    require(isinstance(backup_id, str) and backup_id, "upload response missing backup_id")
    print("PASS upload returns backup_id")

    status, body = request(args.base_url, "GET", "/v1/backups", token=args.token)
    require(status == 200, f"expected list to return 200, got {status}")
    backups = body.get("backups")
    require(isinstance(backups, list), "list response missing backups array")
    require(any(item.get("backup_id") == backup_id for item in backups if isinstance(item, dict)), "uploaded backup not listed")
    print("PASS uploaded backup is visible to owner")

    status, body = request(args.base_url, "GET", f"/v1/backups/{backup_id}", token=args.token)
    require(status == 200, f"expected download to return 200, got {status}")
    require(body.get("payload_sha256") == make_envelope()["payload_sha256"], "downloaded payload hash mismatch")
    print("PASS owner can download uploaded backup")

    if args.other_token:
        status, body = request(args.base_url, "GET", "/v1/account/backup-key", token=args.other_token)
        require(status == 200, f"expected second account backup-key to return 200, got {status}")
        require(body.get("backup_secret") != secret, "second account received the same backup_secret")
        print("PASS account backup-key is scoped per account")

        status, body = request(args.base_url, "GET", "/v1/backups", token=args.other_token)
        require(status == 200, f"expected second account list to return 200, got {status}")
        other_backups = body.get("backups")
        require(isinstance(other_backups, list), "second account list response missing backups array")
        require(
            not any(item.get("backup_id") == backup_id for item in other_backups if isinstance(item, dict)),
            "second account can see first account backup",
        )
        status, body = request(args.base_url, "GET", f"/v1/backups/{backup_id}", token=args.other_token)
        require(status == 404, f"expected second account direct download to return 404, got {status}")
        print("PASS cross-account isolation")

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"FAIL {exc}", file=sys.stderr)
        raise SystemExit(1)
