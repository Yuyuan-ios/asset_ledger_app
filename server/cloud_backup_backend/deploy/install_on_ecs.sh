#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${FLEET_BACKUP_APP_DIR:-/opt/fleet-ledger-cloud-backup}"
DATA_DIR="${FLEET_BACKUP_DATA_DIR:-/var/lib/fleet-ledger-cloud-backup}"
LOG_DIR="${FLEET_BACKUP_LOG_DIR:-/var/log/fleet-ledger-cloud-backup}"
ENV_FILE="${FLEET_BACKUP_ENV_FILE:-/etc/fleet-ledger-cloud-backup.env}"
SERVICE_FILE="${FLEET_BACKUP_SERVICE_FILE:-/etc/systemd/system/fleet-ledger-cloud-backup.service}"
SERVICE_USER="${FLEET_BACKUP_SERVICE_USER:-fleetbackup}"
SERVICE_GROUP="${FLEET_BACKUP_SERVICE_GROUP:-fleetbackup}"

if [[ "$(id -u)" != "0" ]]; then
  echo "Run this installer as root on ECS." >&2
  exit 1
fi

if ! id "$SERVICE_USER" >/dev/null 2>&1; then
  useradd --system --home "$APP_DIR" --shell /usr/sbin/nologin "$SERVICE_USER"
fi

install -d -m 0755 -o "$SERVICE_USER" -g "$SERVICE_GROUP" "$APP_DIR"
install -d -m 0750 -o "$SERVICE_USER" -g "$SERVICE_GROUP" "$DATA_DIR"
install -d -m 0750 -o "$SERVICE_USER" -g "$SERVICE_GROUP" "$LOG_DIR"

if [[ ! -f "$APP_DIR/app.py" ]]; then
  echo "Missing $APP_DIR/app.py. Upload server/cloud_backup_backend/ before installing." >&2
  exit 1
fi

python3 -m venv "$APP_DIR/.venv"
chown -R "$SERVICE_USER:$SERVICE_GROUP" "$APP_DIR/.venv"
runuser -u "$SERVICE_USER" -- "$APP_DIR/.venv/bin/python" -m pip install --upgrade pip
runuser -u "$SERVICE_USER" -- "$APP_DIR/.venv/bin/python" -m pip install -r "$APP_DIR/requirements.txt"

if [[ ! -f "$ENV_FILE" ]]; then
  install -m 0600 -o root -g root "$APP_DIR/env.example" "$ENV_FILE"
  echo "Created $ENV_FILE from env.example. Replace placeholders before starting."
else
  chmod 0600 "$ENV_FILE"
  chown root:root "$ENV_FILE"
fi

install -m 0644 -o root -g root \
  "$APP_DIR/fleet-ledger-cloud-backup.service.example" \
  "$SERVICE_FILE"

systemctl daemon-reload

if grep -Eq 'replace-with|local-test-token|test-user' "$ENV_FILE"; then
  echo "Service installed but not started because $ENV_FILE still contains placeholders."
  echo "Edit $ENV_FILE, then run: systemctl enable --now fleet-ledger-cloud-backup"
  exit 0
fi

if [[ "${FLEET_BACKUP_START:-0}" == "1" ]]; then
  systemctl enable --now fleet-ledger-cloud-backup
  systemctl status fleet-ledger-cloud-backup --no-pager
else
  echo "Service installed. Start with: systemctl enable --now fleet-ledger-cloud-backup"
fi
