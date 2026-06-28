# FleetLedger IAP Verification Backend

This service verifies App Store transactions and stores subscription
entitlements by App Store `appAccountToken`. New account-level cloud-backup
checks also bind verified subscriptions to the logged-in FleetLedger `user_id`.

## API

- `POST /iap/apple/verify-purchase`
  - Body: App Store purchase verification payload including `appAccountToken`.
  - Optional auth: `Authorization: Bearer <app-login-token>`.
  - With valid auth, the backend binds the Apple-verified entitlement to the
    server-side `user_id` from the bearer token. Without auth, the
    appAccountToken-only flow remains available and `user_id` stays null.
- `GET /iap/apple/current-entitlement?appAccountToken=...`
  - AppAccountToken lookup kept for existing clients.
- `POST /iap/gateway/apple/purchase`
  - Body: the same App Store purchase verification payload.
  - Auth: `Authorization: Bearer <app-login-token>`.
  - New unified gateway path for account-bound Apple purchases. The legacy
    `/iap/apple/verify-purchase` endpoint remains available for existing iOS
    clients.
- `POST /iap/webhooks/{channel}`
  - Server-to-server callback endpoint for `google_play`, `oppo`, `xiaomi`,
    `huawei`, and `vivo`.
  - Body includes `channel`, `user_id`, `product_id`, `transaction_id`,
    `status`, and `signature`.
  - The backend verifies the channel signature, normalizes the payload to a
    `PurchaseEvent`, rejects replayed `transaction_id` values with different
    payloads, ignores exact duplicates, and forwards only normalized events to
    the entitlement engine.
- `POST /internal/v1/entitlements/verify`
  - Auth: `Authorization: Bearer <SERVICE_INTERNAL_TOKEN>`.
  - Body:
    `{"user_id":"...","required_capability":"cloud_backup","required_plan":"max"}`.
  - Allows only account-bound active/grace Max entitlements.
- `GET /healthz`
  - No auth.

## Trust Model

The backend separates token use into three auth planes:

- `USER_AUTH_TOKEN`: the app login bearer token used only to resolve the
  stable FleetLedger account `user_id` during purchase verification.
- `SERVICE_INTERNAL_TOKEN`: server-to-server authority for CloudBackup -> IAP
  internal entitlement verification. `/internal/v1/entitlements/verify` accepts
  only this plane.
- `EXTERNAL_CLIENT_TOKEN`: Flutter/App-only client identity. IAP does not
  accept it as binding authority and never uses it for account binding,
  entitlement, or identity resolution. `EXTERNAL_CLIENT_TOKEN_REQUIRED = False`
  is a config statement only; there is no runtime token fallback.

`user_id` is the unique FleetLedger account identity. It is not a session id,
device id, or Apple `appAccountToken`. Token refresh must resolve back to the
same `user_id` for the same account.

## Account Binding

`appAccountToken` is an App Store purchase identity, not the FleetLedger account
id. The service keeps `app_account_token` as the primary key and adds nullable
`user_id` for account binding.

For new purchases, Apple verification still strictly checks that the
transaction `appAccountToken` matches the request `appAccountToken`. If the
request includes a valid FleetLedger bearer token, the verified record stores
that token's `user_id`.

For older restores, the backend treats Apple's verified
`original_transaction_id` as the subscription identity:

- if the original transaction is not bound, bind it to the current `user_id`;
- if it is already bound to the same `user_id`, refresh the entitlement;
- if it is bound to another `user_id`, return
  `409 subscription_bound_to_other_user`.

Binding policy is explicit:

- `BIND_ONLY_IF_UNBOUND`
- `NEVER_OVERWRITE_DIFFERENT_USER`
- `TRANSACTION_IS_VERIFICATION_ONLY`

The client body must not include or control `user_id`. The binding source is
only the server-verified login bearer token. Apple transaction
`appAccountToken`, record-carried `user_id`, and unauthenticated fallback paths
are read-only verification inputs and must not create or overwrite account
binding.

## Unified Subscription Gateway

All new payment channels follow the same server-side flow:

```text
PurchaseEvent -> channel signature verification -> normalized PurchaseEvent -> EntitlementEngine.apply(event)
```

Adapters only verify and parse channel payloads. They do not decide whether a
user receives Free, Pro, or Max. `EntitlementEngine` maps the verified
`product_id` to the entitlement tier and applies purchase status consistently
across Apple, Google Play, OPPO, Xiaomi, Huawei, and Vivo.

The gateway ignores client-declared plan fields such as `plan=max`; only the
verified `product_id` and normalized purchase status can affect entitlement.
`iap_purchase_transactions.transaction_id` is the replay and idempotency guard:
exact duplicate payloads are ignored, while reused transaction ids with changed
payloads are rejected.

## Internal Entitlement Contract

Cloud backup should call:

```bash
POST /internal/v1/entitlements/verify
Authorization: Bearer <SERVICE_INTERNAL_TOKEN>
Content-Type: application/json
```

Allowed response:

```json
{"allowed":true,"entitlementTier":"max","entitlementActive":true,"status":"active"}
```

Denied response:

```json
{"allowed":false,"entitlementTier":"pro","entitlementActive":false,"status":"active","reason":"requires_max"}
```

The endpoint ignores client-declared plan/tier headers such as
`X-Subscription-Tier`. It only reads the database entitlement bound to
`user_id`. Unbound appAccountToken-only records never unlock cloud backup.

## Environment

Copy `env.example` outside the repo and edit secrets there. Do not commit real
tokens, Apple keys, receipts, or Authorization headers.

Important variables:

- `SERVICE_INTERNAL_TOKEN`: required for the internal entitlement
  endpoint. There is no production default.
- `USER_AUTH_HS256_SECRET`: validates login JWTs locally.
- `USER_AUTH_INTROSPECTION_URL`: HTTPS account-service introspection
  endpoint for opaque login tokens.
- `USER_AUTH_INTROSPECTION_SERVICE_TOKEN`: optional server-to-server token for
  introspection.
- `USER_AUTH_TIMEOUT_SECONDS`: introspection timeout, default 5 seconds.
- `USER_AUTH_IDENTITY_CACHE_TTL_SECONDS`: successful token -> `user_id` cache
  TTL, default 900 seconds. Failed resolutions are not cached.
- `FLEET_IAP_GOOGLE_PLAY_SIGNATURE_SECRET`,
  `FLEET_IAP_OPPO_SIGNATURE_SECRET`, `FLEET_IAP_XIAOMI_SIGNATURE_SECRET`,
  `FLEET_IAP_HUAWEI_SIGNATURE_SECRET`, and
  `FLEET_IAP_VIVO_SIGNATURE_SECRET`: required before accepting the
  corresponding channel webhook. Missing secrets fail closed.

Breaking migration required: deprecated auth and internal entitlement env names
are rejected at startup with `ConfigMigrationError`. Use only `USER_AUTH_*` and
`SERVICE_INTERNAL_TOKEN`; the deprecated names are listed in `env.example` for
operator cleanup.

Env migration checklist:

- Replace deprecated auth variables with the `USER_AUTH_*` names in
  `env.example`.
- Replace the deprecated internal entitlement token name with
  `SERVICE_INTERNAL_TOKEN`.
- Confirm startup fails with `ConfigMigrationError` if any deprecated name
  remains set.

## Production Runtime Runbook

The current ECS deployment uses:

- App directory: `/opt/fleet-ledger-iap`
- Service venv: `/opt/fleet-ledger-iap/venv`
- Service unit: `fleet-ledger-iap.service`
- Runtime command:
  `/opt/fleet-ledger-iap/venv/bin/python /opt/fleet-ledger-iap/app.py`
- Loopback listener: `127.0.0.1:8010`
- Env file: `/etc/fleet-ledger/iap.env`

Do not confuse this service with cloud sync. `127.0.0.1:8009` belongs to
`fleet-ledger-cloud-sync.service`; BOL billing explain is part of
`fleet-ledger-iap.service` on `8010`.

The deployed artifact must include the shared package at
`/opt/common/auth_identity/`, because the IAP backend adds `/opt` to
`sys.path` before importing `common.auth_identity`. If the service restart logs
`ModuleNotFoundError: No module named 'common'`, deploy that shared package
before retrying the service restart.

Rebuild the service venv without deleting secrets or data:

```bash
cd /opt/fleet-ledger-iap
python3 -m venv venv
sudo chown -R fleetiap:fleetiap venv
sudo -u fleetiap ./venv/bin/python -m pip install --upgrade pip
sudo -u fleetiap ./venv/bin/python -m pip install -r requirements.txt
```

`GET /internal/v3/billing/explain/{user_id}` and
`GET /internal/v3/billing/explain/event/{event_id}` are internal-only BOL
diagnostic APIs. They must not be added to a public nginx route without an
explicit operations approval. Public nginx routes should continue to expose only
the public IAP paths, such as `/fleet-ledger/iap/healthz` and
`/fleet-ledger/iap/apple/`, to `127.0.0.1:8010`.

Internal explain auth uses only `SERVICE_INTERNAL_TOKEN`. Generate it on the
server, write it directly to `/etc/fleet-ledger/iap.env`, and never print,
paste, commit, or screenshot the token value:

```bash
sudo cp /etc/fleet-ledger/iap.env \
  /etc/fleet-ledger/iap.env.before-bol-auth-$(date +%Y%m%d-%H%M%S)
sudo sh -c 'token=$(openssl rand -hex 32); printf "\nSERVICE_INTERNAL_TOKEN=%s\n" "$token" >> /etc/fleet-ledger/iap.env'
sudo systemctl restart fleet-ledger-iap.service
sudo systemctl is-active fleet-ledger-iap.service
```

Runtime smoke template:

```bash
sudo sh -c '. /etc/fleet-ledger/iap.env; curl -sS -o /tmp/bol-valid-body.txt -D /tmp/bol-valid-headers.txt -w "VALID=%{http_code}\n" -H "Authorization: Bearer $SERVICE_INTERNAL_TOKEN" http://127.0.0.1:8010/internal/v3/billing/explain/test-user'
curl -sS -o /tmp/bol-invalid-body.txt -D /tmp/bol-invalid-headers.txt -w "INVALID=%{http_code}\n" -H "Authorization: Bearer definitely-wrong-token" http://127.0.0.1:8010/internal/v3/billing/explain/test-user
grep -Eiq 'purchaseToken|signature|transaction_id|transactionId|bearer|secret|JWS' /tmp/bol-valid-body.txt \
  && echo 'FAIL forbidden explain field present' \
  || echo 'PASS no forbidden explain field'
```

Expected results:

- Valid `SERVICE_INTERNAL_TOKEN`: `200` JSON or an explicit not-found JSON for
  the requested user/event.
- Missing, invalid, ordinary user, or client token: `401`.
- No `500`, empty reply, raw webhook payload, JWS, purchase token, signature,
  transaction id, bearer token, or secret in explain output.

## Test

```bash
python3 -m py_compile app.py handlers.py storage.py auth.py verifier.py payment_channel_adapters.py subscription_gateway.py tests/test_app.py ../common/auth_identity/resolver.py
python3 -m unittest discover -s tests
```
