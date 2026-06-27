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

## Test

```bash
python3 -m py_compile app.py handlers.py storage.py auth.py tests/test_app.py ../common/auth_identity/resolver.py
python3 -m unittest discover -s tests
```
