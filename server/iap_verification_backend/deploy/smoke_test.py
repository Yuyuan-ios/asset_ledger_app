#!/usr/bin/env python3
"""Smoke test for the FleetLedger IAP verification backend.

The script uses fake verifier tokens only and never prints receipt payloads.
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
        "bundleId": "com.yuyuan.assetledger",
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
    require(status == 200 and body.get("outcome") == "verifiedActivePro", "expected fake Pro verification")
    print("PASS verify-purchase returns verifiedActivePro for fake Pro token")

    path = f"/iap/apple/current-entitlement?appAccountToken={urllib.parse.quote(app_account_token)}"
    status, body = request(args.base_url, "GET", path)
    require(status == 200 and body.get("outcome") == "verifiedActivePro", "expected persisted Pro entitlement")
    print("PASS current-entitlement returns persisted entitlement")

    outage_token = str(uuid.uuid4())
    status, body = request(
        args.base_url,
        "POST",
        "/iap/apple/verify-purchase",
        body=purchase_body(outage_token, "fake:outage"),
    )
    require(status == 200 and body.get("outcome") == "verificationUnavailable", "expected fake outage")
    print("PASS fake Apple outage returns verificationUnavailable")

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
