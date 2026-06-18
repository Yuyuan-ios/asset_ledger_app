#!/usr/bin/env python3
"""Smoke test for the FleetLedger cloud sync backend.

The script never prints bearer tokens or sync payload bodies.
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
SMOKE_ENTITY_TYPE = "smoke_probe"
SMOKE_ENTITY_ID = "smoke-probe-record"


def make_change(entity_id: str, op: str, base_version: int, mark: str) -> Dict[str, Any]:
    payload_json = json.dumps({"record": {"id": entity_id, "mark": mark}}, separators=(",", ":"))
    return {
        # Keep smoke data out of production client entity streams. The Flutter
        # client applies timing_record payloads strictly and skips unknown
        # entity types after advancing the cursor.
        "entity_type": SMOKE_ENTITY_TYPE,
        "entity_id": entity_id,
        "op": op,
        "base_version": base_version,
        "payload_json": payload_json,
        "payload_hash": hashlib.sha256(payload_json.encode("utf-8")).hexdigest(),
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
    parser.add_argument("--base-url", required=True, help="https://sync-api.example.com")
    parser.add_argument("--token", help="test account bearer token")
    parser.add_argument("--other-token", help="second test account bearer token")
    parser.add_argument(
        "--auth-only",
        action="store_true",
        help="only verify health and unauthenticated /sync/changes rejection",
    )
    args = parser.parse_args()

    status, body = request(args.base_url, "GET", "/healthz")
    require(status == 200 and body.get("ok") is True, f"expected /healthz 200 ok, got {status}")
    print("PASS /healthz returns ok without auth")

    status, _ = request(args.base_url, "GET", "/sync/changes?since=0")
    require(status == 401, f"expected unauthenticated GET /sync/changes to return 401, got {status}")
    print("PASS unauthenticated /sync/changes returns 401")

    if args.auth_only:
        return 0
    require(args.token, "--token is required unless --auth-only is set")

    entity_id = SMOKE_ENTITY_ID
    first_change = make_change(entity_id, "create", 0, "first")
    status, body = request(
        args.base_url,
        "POST",
        "/sync/changes",
        token=args.token,
        body={"device_id": "smoke-device", "changes": [first_change]},
    )
    require(status == 200, f"expected push to return 200, got {status}")
    accepted = body.get("accepted")
    require(isinstance(accepted, list) and len(accepted) == 1, "push response missing accepted change")
    server_seq = accepted[0].get("server_seq")
    require(server_seq == 1, "first account server_seq did not start at 1")
    require(accepted[0].get("new_version") == 1, "first push did not assign version 1")
    print("PASS push accepted and assigned server_seq/version")

    status, body = request(args.base_url, "GET", "/sync/changes?since=0&limit=10", token=args.token)
    require(status == 200, f"expected pull to return 200, got {status}")
    changes = body.get("changes")
    require(isinstance(changes, list) and len(changes) == 1, "pull did not return pushed change")
    require(changes[0].get("server_seq") == server_seq, "pull returned unexpected server_seq")
    require(body.get("next_cursor") == server_seq, "pull next_cursor did not advance")
    print("PASS push-pull round trip")

    stale = make_change(entity_id, "update", 0, "stale")
    status, body = request(
        args.base_url,
        "POST",
        "/sync/changes",
        token=args.token,
        body={"changes": [stale]},
    )
    require(status == 200, f"expected stale push to return 200, got {status}")
    conflicts = body.get("conflicts")
    require(isinstance(conflicts, list) and len(conflicts) == 1, "stale push did not report conflict")
    require(conflicts[0].get("server_version") == 1, "conflict did not report server version 1")
    print("PASS stale base_version is reported as conflict")

    if args.other_token:
        status, body = request(args.base_url, "GET", "/sync/changes?since=0", token=args.other_token)
        require(status == 200, f"expected other account pull to return 200, got {status}")
        require(body.get("changes") == [], "other account can see first account changes")

        other_change = make_change(entity_id, "create", 0, "other")
        status, body = request(
            args.base_url,
            "POST",
            "/sync/changes",
            token=args.other_token,
            body={"changes": [other_change]},
        )
        require(status == 200, f"expected other account push to return 200, got {status}")
        other_accepted = body.get("accepted")
        require(
            isinstance(other_accepted, list)
            and other_accepted[0].get("server_seq") == 1
            and other_accepted[0].get("new_version") == 1,
            "other account did not get isolated server_seq/version",
        )
        print("PASS cross-account isolation")

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"FAIL {exc}", file=sys.stderr)
        raise SystemExit(1)
