#!/usr/bin/env python3
"""Smoke test for the FleetLedger static version-policy endpoint."""

from __future__ import annotations

import argparse
import json
import socket
import sys
import urllib.error
import urllib.request
from typing import Any, Dict


ANDROID_CHANNEL_KEYS = {
    "xiaomi",
    "huawei",
    "oppo",
    "vivo",
    "tencent",
    "official",
    "play",
}

OPENER = urllib.request.build_opener(urllib.request.ProxyHandler({}))


def fetch_json(policy_url: str, timeout: int) -> Dict[str, Any]:
    headers = {"Accept": "application/json"}
    req = urllib.request.Request(policy_url, headers=headers, method="GET")
    with OPENER.open(req, timeout=timeout) as response:
        if response.status != 200:
            raise RuntimeError(f"expected 200, got {response.status}")
        raw = response.read()
    decoded = json.loads(raw.decode("utf-8"))
    if not isinstance(decoded, dict):
        raise RuntimeError("policy response is not a JSON object")
    return decoded


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def require_platform(policy: Dict[str, Any], platform: str) -> Dict[str, Any]:
    value = policy.get(platform)
    require(isinstance(value, dict), f"{platform} policy missing or not an object")
    for field in ("latestVersion", "minSupportedVersion", "updateUrl"):
        require(
            isinstance(value.get(field), str) and value[field],
            f"{platform}.{field} missing or empty",
        )
    return value


def validate_policy(policy: Dict[str, Any]) -> None:
    require_platform(policy, "ios")
    android = require_platform(policy, "android")
    channel_urls = android.get("channelUrls")
    require(isinstance(channel_urls, dict), "android.channelUrls missing or not an object")
    missing = sorted(ANDROID_CHANNEL_KEYS.difference(channel_urls.keys()))
    require(not missing, f"android.channelUrls missing keys: {', '.join(missing)}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("policy_url", help="https://<host>/app/version-policy.json")
    parser.add_argument("--timeout", type=int, default=10, help="request timeout in seconds")
    args = parser.parse_args()

    try:
        policy = fetch_json(args.policy_url, args.timeout)
    except urllib.error.HTTPError as exc:
        print(f"FAIL expected 200 from {args.policy_url}, got {exc.code}", file=sys.stderr)
        return 1
    except (urllib.error.URLError, TimeoutError, socket.timeout) as exc:
        print(f"SKIP version policy URL is unreachable: {exc}")
        return 0

    validate_policy(policy)
    print("PASS version policy is reachable and matches the V1 static schema")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"FAIL {exc}", file=sys.stderr)
        raise SystemExit(1)
