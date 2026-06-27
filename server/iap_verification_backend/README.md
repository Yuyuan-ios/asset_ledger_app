# FleetLedger IAP Verification Backend

This service verifies App Store transactions and stores subscription
entitlements by App Store `appAccountToken`. New account-level cloud-backup
checks also bind verified subscriptions to the logged-in FleetLedger `user_id`.

## API

- `POST /iap/apple/verify-purchase`
  - Body: App Store purchase verification payload including `appAccountToken`.
  - Optional auth: `Authorization: Bearer <app-login-token>`.
  - With valid auth, the backend binds the Apple-verified entitlement to the
    server-side `user_id` from the bearer token. Without auth, the legacy
    appAccountToken-only flow remains available and `user_id` stays null.
- `GET /iap/apple/current-entitlement?appAccountToken=...`
  - Legacy appAccountToken lookup. Kept for existing clients.
- `POST /internal/v1/entitlements/verify`
  - Auth: `Authorization: Bearer <IAP_INTERNAL_ENTITLEMENT_TOKEN>`.
  - Body:
    `{"user_id":"...","required_capability":"cloud_backup","required_plan":"max"}`.
  - Allows only account-bound active/grace Max entitlements.
- `GET /healthz`
  - No auth.

## Account Binding

`appAccountToken` is an App Store purchase identity, not the FleetLedger account
id. The service keeps `app_account_token` as the primary key and adds nullable
`user_id` for account binding.

For new purchases, Apple verification still strictly checks that the
transaction `appAccountToken` matches the request `appAccountToken`. If the
request includes a valid FleetLedger bearer token, the verified record stores
that token's `user_id`.

For legacy restores, the backend treats Apple's verified
`original_transaction_id` as the subscription identity:

- if the original transaction is not bound, bind it to the current `user_id`;
- if it is already bound to the same `user_id`, refresh the entitlement;
- if it is bound to another `user_id`, return
  `409 subscription_bound_to_other_user`.

The client body must not include or control `user_id`. The binding source is
only the login bearer token.

## Internal Entitlement Contract

Cloud backup should call:

```bash
POST /internal/v1/entitlements/verify
Authorization: Bearer <IAP_INTERNAL_ENTITLEMENT_TOKEN>
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
`user_id`. Unbound legacy appAccountToken records never unlock cloud backup.

## Environment

Copy `env.example` outside the repo and edit secrets there. Do not commit real
tokens, Apple keys, receipts, or Authorization headers.

Important variables:

- `IAP_INTERNAL_ENTITLEMENT_TOKEN`: required for the internal entitlement
  endpoint. There is no production default.
- `FLEET_IAP_AUTH_HS256_SECRET`: validates login JWTs locally.
- `FLEET_IAP_AUTH_INTROSPECTION_URL`: HTTPS account-service introspection
  endpoint for opaque login tokens.
- `FLEET_IAP_AUTH_INTROSPECTION_TOKEN`: optional server-to-server token for
  introspection.
- `FLEET_IAP_AUTH_TIMEOUT_SECONDS`: introspection timeout, default 5 seconds.

## Test

```bash
python3 -m py_compile app.py handlers.py storage.py auth.py tests/test_app.py
python3 -m unittest discover -s tests
```
