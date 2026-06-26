#!/usr/bin/env python3
"""Smoke test for the FleetLedger IAP verification backend.

This smoke proves the production entrypoint fails closed for fake purchase
data. A deployment without Apple credentials returns verificationUnavailable;
a deployment with real Apple verification returns verificationFailed. Both are
valid non-unlocking results. Real Apple sandbox smoke tests require signed
StoreKit payloads and are intentionally outside this local script.
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid
from typing import Any, Dict, Optional, Tuple


OPENER = urllib.request.build_opener(urllib.request.ProxyHandler({}))
PRO_PRODUCT_ID = "com.yuyuan.assetledger.pro.yearly"
FAIL_CLOSED_OUTCOMES = {"verificationFailed", "verificationUnavailable"}


def request(
    base_url: str,
    method: str,
    path: str,
    *,
    body: Optional[Dict[str, Any]] = None,
    timeout: int = 30,
) -> Tuple[int, Dict[str, Any]]:
    data = None
    headers = {"Accept": "application/json"}
    if body is not None:
        data = json.dumps(body, separators=(",", ":")).encode("utf-8")
        headers["Content-Type"] = "application/json"
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


def purchase_body(app_account_token: str, fake_token: str) -> Dict[str, str]:
    return {
        "platform": "ios",
        "productId": PRO_PRODUCT_ID,
        "serverVerificationData": fake_token,
        "localVerificationData": "fake:local",
        "source": "app_store",
        "status": "purchased",
        "appAccountToken": app_account_token,
        "bundleId": "com.yuyuan.asset-ledger",
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", required=True, help="https://api.example.com/fleet-ledger")
    args = parser.parse_args()

    app_account_token = str(uuid.uuid4())
    status, body = request(args.base_url, "GET", "/healthz")
    require(status == 200 and body.get("ok") is True, f"expected /healthz 200 ok, got {status}")
    print("PASS /healthz returns ok")

    status, body = request(
        args.base_url,
        "POST",
        "/iap/apple/verify-purchase",
        body=purchase_body(app_account_token, "fake:pro-active"),
    )
    require(status == 200 and body.get("outcome") in FAIL_CLOSED_OUTCOMES, "expected fail-closed response")
    require(body.get("entitlementTier") == "none", "fake token must not unlock entitlement")
    print(f"PASS fake Pro token fails closed as {body.get('outcome')}")

    path = f"/iap/apple/current-entitlement?appAccountToken={urllib.parse.quote(app_account_token)}"
    status, body = request(args.base_url, "GET", path)
    require(
        status == 200 and body.get("outcome") in {"noActiveEntitlement", "verificationFailed"},
        "expected no active entitlement after fake verify",
    )
    require(body.get("entitlementTier") == "none", "current entitlement must not unlock")
    print(f"PASS current-entitlement remains non-unlocking as {body.get('outcome')}")

    status, body = request(args.base_url, "GET", "/iap/apple/current-entitlement")
    require(status == 400 and body.get("error", {}).get("code") == "missing_app_account_token", "expected 400")
    print("PASS missing appAccountToken is rejected")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"FAIL {exc}", file=sys.stderr)
        raise SystemExit(1)
