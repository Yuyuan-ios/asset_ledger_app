# FleetLedger Cloud Sync Backend

This is the independent backend skeleton for owner multi-device sync:

```text
FleetLedger App -> HTTPS /sync/changes -> backend -> SQLite change log
```

It is parallel to `server/cloud_backup_backend/` and intentionally does not
couple to the backup service. B1 only provides the server skeleton, storage,
auth, deploy assets, smoke test, and unit tests. Flutter client wiring remains
out of scope for B2/B6.

## API

- `POST /sync/changes`
  - Auth: `Authorization: Bearer <app-login-token>`
  - Body: `{"changes":[...]}` where each change includes
    `entity_type`, `entity_id`, `op`, `base_version`, `payload_json`, and
    `payload_hash`. Optional fields: top-level `device_id`, per-change
    `origin_device_id`, `transaction_group_id`, and `local_sequence`.
  - Response:
    `{"accepted":[{"entity","server_seq","new_version"}],"conflicts":[{"entity","server_version"}]}`.
- `GET /sync/changes?since=<cursor>&limit=N`
  - Auth required.
  - Returns account-scoped changes with `server_seq > cursor`, sorted ascending,
    paginated, including tombstones as `deleted:true`.
- `POST /sync/devices`
  - Auth required.
  - Body: `{"device_id":"...","name":"..."}`.
  - Upserts `(account_id, device_id, name, last_seen)`.
- `GET /healthz`
  - No auth; returns `{"ok":true}` and exposes no config.

The service derives `account_id` from the bearer token (`sub`, `user_id`, or
`phone`) or the configured introspection response. It never trusts an account
value supplied in the request body.

## Push Semantics

For each pushed change, inside one SQLite transaction:

1. If `(account_id, entity_type, entity_id, payload_hash)` already exists, the
   service returns the existing `server_seq` and `new_version` without writing
   another row.
2. Otherwise it reads the current version from `sync_entity_heads`.
3. If `base_version == current_version`, it accepts the change, assigns the
   account-local monotonic `server_seq`, sets `new_version = current + 1`, and
   writes both `sync_changes` and `sync_entity_heads`.
4. If versions differ, it returns a conflict and does not overwrite the head.

Deletes are stored as ordinary changes with `deleted = 1`, so pull includes
tombstones.

## Storage

SQLite tables:

- `sync_changes(account_id, server_seq, entity_type, entity_id, base_version,
  new_version, payload_json, payload_hash, deleted, origin_device_id,
  server_ts, PRIMARY KEY(account_id, server_seq))`
- `sync_devices(account_id, device_id, name, last_seen,
  PRIMARY KEY(account_id, device_id))`
- `sync_entity_heads(account_id, entity_type, entity_id, version, deleted,
  payload_hash, server_seq, updated_at)` for O(1) current-version checks.

Indexes support entity-head lookup, pull by `server_seq`, and idempotency by
`(account_id, entity_type, entity_id, payload_hash)`.

## Runtime

Python 3.9+ is enough. No third-party packages are required.

```bash
cd /opt/fleet-ledger-cloud-sync
cp env.example .env
# edit .env, then:
set -a
. ./.env
set +a
python3 app.py
```

Put nginx with HTTPS in front of `127.0.0.1:8009`. Do not expose the Python
process directly to the public internet.

## Auth

Production should configure one of these:

- `FLEET_BACKUP_AUTH_HS256_SECRET`: the same HS256 secret used by the account
  service that issues the phone-login token. The token must contain one of
  `sub`, `user_id`, or `phone`, and may contain `exp`.
- `FLEET_BACKUP_AUTH_INTROSPECTION_URL`: HTTPS endpoint on the account service
  for opaque login tokens. The backend posts `{"token":"..."}` and accepts JSON
  containing `active:true` or `ok:true` plus one of `sub`, `user_id`, `phone`,
  or `user.id`.

`FLEET_BACKUP_AUTH_INTROSPECTION_BEARER_TOKEN` is optional for server-to-server
authorization to the introspection endpoint.

For one-machine smoke tests only, set:

```bash
FLEET_BACKUP_DEV_TOKENS_JSON='{"local-sync-token-a":"test-account-a","local-sync-token-b":"test-account-b"}'
```

Do not enable dev tokens in production.

Optional JWT hardening:

- `FLEET_BACKUP_AUTH_JWT_ISSUER`: expected `iss` claim.
- `FLEET_BACKUP_AUTH_JWT_AUDIENCE`: expected `aud` claim.

## Security Notes

- All storage queries are scoped by server-derived `account_id`.
- Request size is limited by `FLEET_SYNC_MAX_REQUEST_BYTES`.
- Logs must not include Authorization headers, bearer tokens, or payload bodies.
- The health check only returns `{"ok":true}` and must not expose config.
- Keep `/etc/fleet-ledger-cloud-sync.env` owned by `root:root` with `0600`
  permissions.

## Test

```bash
python3 -m py_compile app.py tests/test_app.py deploy/smoke_test.py
python3 -m unittest discover -s tests
```

Tests use a temporary SQLite database and do not call real cloud services.

## Deployment Assets

`deploy/` contains an ECS installer, Nginx sample, and smoke-test script. The
installer creates the service user, venv, data/log directories, systemd unit,
and root-owned `0600` env file, but it does not start the service while the env
file still contains placeholders.
