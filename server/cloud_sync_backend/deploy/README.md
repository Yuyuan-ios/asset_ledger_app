# Cloud Sync Deployment Assets

These files are deployment aids only. They do not contain production secrets.

## ECS install

Upload `server/cloud_sync_backend/` to `/opt/fleet-ledger-cloud-sync` on ECS,
then run:

```bash
cd /opt/fleet-ledger-cloud-sync
sudo bash deploy/install_on_ecs.sh
```

The installer creates the `fleetsync` system user, data/log directories, a
Python venv, `/etc/fleet-ledger-cloud-sync.env`, and the systemd unit. It does
not start the service while placeholders remain in the env file.

## Nginx

Copy `deploy/nginx.conf.example` to the ECS Nginx config directory and replace
`sync-api.example.com` and certificate paths. The sample proxies only
`/sync/changes`, `/sync/devices`, and `/healthz` to `127.0.0.1:8009`.

## Smoke test

From any machine that can reach the HTTPS endpoint:

```bash
python3 deploy/smoke_test.py --base-url https://sync-api.example.com --auth-only
python3 deploy/smoke_test.py --base-url https://sync-api.example.com --token "$TOKEN"
python3 deploy/smoke_test.py --base-url https://sync-api.example.com --token "$TOKEN_A" --other-token "$TOKEN_B"
```

The script verifies auth rejection, push/pull round trip, stale-base conflict,
and optional cross-account isolation. It does not print bearer tokens or sync
payload bodies.
