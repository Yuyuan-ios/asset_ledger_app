# Cloud Sync Launch Runbook

Status: B7 pre-launch operations runbook. This document is sanitized; replace
all angle-bracket placeholders locally and never commit real hosts, tokens, or
secrets.

Scope:
- Deploy and verify the cloud sync backend behind HTTPS.
- Run backend smoke checks and real-device rehearsal.
- Stop before the App Store / Play production release decision.

Out of scope:
- Publishing a production App build.
- Database schema migrations.
- Exposing port 8009 to the public internet.
- Storing real hosts, HS256 secrets, bearer tokens, phone numbers, or SMS codes
  in this repository.

## O1 Upload And Install

On the ECS host, upload `server/cloud_sync_backend/` to:

```bash
/opt/fleet-ledger-cloud-sync
```

Then run:

```bash
cd /opt/fleet-ledger-cloud-sync
sudo bash deploy/install_on_ecs.sh
```

Expected result:
- `fleetsync` user exists.
- Data and log directories exist.
- Python virtual environment is created.
- `/etc/fleet-ledger-cloud-sync.env` is created from `env.example`.
- The systemd unit is installed.
- The service is not started while placeholders remain in the env file.

If the installer detects placeholder dev-token values such as
`local-sync-token` or `test-account`, do not start the service.

## O2 Configure And Start

Edit the environment file on ECS. Do not paste any secret into chat or docs.

```bash
sudoedit /etc/fleet-ledger-cloud-sync.env
```

Required production auth configuration:
- Either set `FLEET_BACKUP_AUTH_HS256_SECRET` to the same HS256 secret used by
  the account service that signs sync tokens.
- Or configure the account-service introspection endpoint and service bearer
  token. The bearer token is a server-to-server credential and must only be
  edited directly on ECS.

Storage:
- Confirm `FLEET_SYNC_DB_PATH` points to a persistent disk path.

Nginx:
- Copy `deploy/nginx.conf.example` to the active nginx config location.
- Replace `server_name` with `<sync-host>`.
- Replace certificate paths with the local TLS certificate and key paths.
- Keep the backend bound to loopback. Do not expose port 8009 publicly.

Validate and reload nginx:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

Start the service:

```bash
sudo systemctl enable --now fleet-ledger-cloud-sync
sudo systemctl status fleet-ledger-cloud-sync --no-pager
```

Health check:

```bash
curl -sS https://<sync-host>/healthz
```

Expected:

```json
{"ok":true}
```

Production clients require HTTPS. A deployed backend does not enable live sync
for production users by itself.

## O3 Smoke

Auth-only smoke can run without real account tokens:

```bash
cd /opt/fleet-ledger-cloud-sync
python3 deploy/smoke_test.py --base-url https://<sync-host> --auth-only
```

Expected:
- `PASS /healthz returns ok without auth`
- `PASS unauthenticated /sync/changes returns 401`

Full smoke needs two real test-account tokens. Export them directly in the
operator shell and do not paste them into chat:

```bash
export TOKEN_A='<real-test-account-token-a>'
export TOKEN_B='<real-test-account-token-b>'
python3 deploy/smoke_test.py \
  --base-url https://<sync-host> \
  --token "$TOKEN_A" \
  --other-token "$TOKEN_B"
unset TOKEN_A TOKEN_B
```

Expected:
- `PASS /healthz returns ok without auth`
- `PASS unauthenticated /sync/changes returns 401`
- `PASS push accepted and assigned server_seq/version`
- `PASS push-pull round trip`
- `PASS stale base_version is reported as conflict`
- `PASS cross-account isolation`

Smoke writes use the internal `smoke_probe` entity type. Do not change smoke to
write `timing_record`; production clients parse `timing_record` payloads
strictly.

## O4 Logs

Check structured sync telemetry in journald:

```bash
sudo journalctl -u fleet-ledger-cloud-sync --since "15 min ago" --no-pager \
  | grep sync_event
```

Expected fields:
- `account_id`
- `op`
- push counts: `accepted`, `conflicts`
- pull counts: `applied`, `returned`, `since`, `next_cursor`
- `duration_ms`
- `status`

Sensitive data must not appear in `sync_event` lines:

```bash
sudo journalctl -u fleet-ledger-cloud-sync --since "15 min ago" --no-pager \
  | grep sync_event \
  | grep -Eiq 'authorization|bearer|token|secret|payload_json|phone|sms|record' \
  && echo 'FAIL sensitive-looking field found' \
  || echo 'PASS no obvious sensitive fields in sync_event logs'
```

Expected:

```text
PASS no obvious sensitive fields in sync_event logs
```

## O5 Real-Device Rehearsal

On the operator Mac, run an internal build against the live backend. Enter the
real HTTPS base URL only in the local shell.

```bash
printf 'SYNC_BASE_URL (https URL, hidden): '
stty -echo
IFS= read -r SYNC_BASE_URL
stty echo
printf '\n'

flutter run --profile --dart-define=FLEET_LEDGER_SYNC_BASE_URL="$SYNC_BASE_URL"

unset SYNC_BASE_URL
```

Rehearsal checks:
- Launch with a real phone-login session.
- Foreground the app to trigger device registration and pull.
- Create or edit one timing record.
- Background and foreground the app again to trigger push.
- Confirm ECS logs show `pull` and `push` `sync_event` lines with `status:"ok"`.
- Confirm at least one `push` line has `accepted` greater than `0`.
- Confirm the app remains dormant when built without
  `FLEET_LEDGER_SYNC_BASE_URL`.

If push logs show `status:"error"`:
- Check client telemetry `sync.telemetry.lastResult.v1`.
- Check `sync_outbox.last_error` in a local copy of the device app container.
- Confirm the backend accepts both `payload_json` and client `payload` change
  fields.

## O6 Teardown, Documentation, And Go-Live Gate

If dev tokens were used for smoke, remove them before declaring launch
readiness:

```bash
sudoedit /etc/fleet-ledger-cloud-sync.env
sudo systemctl restart fleet-ledger-cloud-sync
python3 deploy/smoke_test.py --base-url https://<sync-host> --auth-only
```

Confirm the env file contains no placeholder or dev-token remnants:

```bash
sudo grep -E 'local-sync-token|test-account|FLEET_BACKUP_DEV_TOKENS_JSON' \
  /etc/fleet-ledger-cloud-sync.env \
  && echo 'FAIL dev token residue found' \
  || echo 'PASS no dev token residue found'
```

Go-live boundary:
- Backend live plus smoke plus real-device rehearsal is not the production App
  release.
- True live enablement for users requires an App build that includes:

```bash
--dart-define=FLEET_LEDGER_SYNC_BASE_URL=https://<sync-host>
```

- App Store / Play release is a separate release decision and must coordinate
  with the version-policy / forced-update track.

Rollback:
- Backend rollback: stop the service and keep nginx returning no sync backend.

```bash
sudo systemctl stop fleet-ledger-cloud-sync
```

- Config rollback: remove or correct the sync backend env values, then restart
  only after health and smoke are ready.
- App rollback: ship or keep a build without
  `FLEET_LEDGER_SYNC_BASE_URL`; that build remains dormant for cloud sync.

## B7 Rehearsal Notes

Issues found and fixed during launch rehearsal:
- Journald did not emit `INFO` sync telemetry until backend logging was
  explicitly configured.
- Smoke originally wrote a fake `timing_record` entity and polluted real
  account pull streams. Smoke now writes `smoke_probe`, which clients skip as an
  unsupported entity type.
- The backend now accepts the production client `payload` object field as well
  as the smoke-compatible `payload_json` string field.

Keep all future smoke and troubleshooting output sanitized. Do not paste real
tokens, service bearer credentials, phone numbers, SMS codes, or real hosts into
agent chat or repository files.
