# Cloud Backup Deployment Assets

These files are deployment aids only. They do not contain production secrets.

## ECS install

Upload `server/cloud_backup_backend/` to `/opt/fleet-ledger-cloud-backup` on ECS,
then run:

```bash
cd /opt/fleet-ledger-cloud-backup
sudo bash deploy/install_on_ecs.sh
```

The installer creates the `fleetbackup` system user, data/log directories, a
Python venv, `/etc/fleet-ledger-cloud-backup.env`, and the systemd unit. It does
not start the service while placeholders remain in the env file.

Set `FLEET_BACKUP_ACCOUNT_KEY_SECRET` in the env file before enabling encrypted
cloud backup. It must be a long random value and must stay stable across
deployments; losing or rotating it makes existing encrypted backups
unrecoverable.

## Nginx

Copy `deploy/nginx.conf.example` to the ECS Nginx config directory and replace
`backup-api.example.com` and certificate paths. Keep `client_max_body_size` at
least `70m`. The sample proxies both `/v1/backups` and
`/v1/account/backup-key`.

## Smoke test

From any machine that can reach the HTTPS endpoint:

```bash
python3 deploy/smoke_test.py --base-url https://backup-api.example.com --auth-only
python3 deploy/smoke_test.py --base-url https://backup-api.example.com --token "$TOKEN"
python3 deploy/smoke_test.py --base-url https://backup-api.example.com --token "$TOKEN_A" --other-token "$TOKEN_B"
```

The script verifies auth rejection, account backup-key issuance/stability,
backup round-trip, and optional cross-account isolation. It does not print
bearer tokens, account secrets, or payload bodies.
