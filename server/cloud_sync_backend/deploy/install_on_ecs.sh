#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${FLEET_SYNC_APP_DIR:-/opt/fleet-ledger-cloud-sync}"
DATA_DIR="${FLEET_SYNC_DATA_DIR:-/var/lib/fleet-ledger-cloud-sync}"
LOG_DIR="${FLEET_SYNC_LOG_DIR:-/var/log/fleet-ledger-cloud-sync}"
ENV_FILE="${FLEET_SYNC_ENV_FILE:-/etc/fleet-ledger-cloud-sync.env}"
SERVICE_FILE="${FLEET_SYNC_SERVICE_FILE:-/etc/systemd/system/fleet-ledger-cloud-sync.service}"
SERVICE_USER="${FLEET_SYNC_SERVICE_USER:-fleetsync}"
SERVICE_GROUP="${FLEET_SYNC_SERVICE_GROUP:-fleetsync}"

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
  echo "Missing $APP_DIR/app.py. Upload server/cloud_sync_backend/ before installing." >&2
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
  "$APP_DIR/fleet-ledger-cloud-sync.service.example" \
  "$SERVICE_FILE"

systemctl daemon-reload

if grep -Eq 'replace-with|local-sync-token|test-account' "$ENV_FILE"; then
  echo "Service installed but not started because $ENV_FILE still contains placeholders."
  echo "Edit $ENV_FILE, then run: systemctl enable --now fleet-ledger-cloud-sync"
  exit 0
fi

if [[ "${FLEET_SYNC_START:-0}" == "1" ]]; then
  systemctl enable --now fleet-ledger-cloud-sync
  systemctl status fleet-ledger-cloud-sync --no-pager
else
  echo "Service installed. Start with: systemctl enable --now fleet-ledger-cloud-sync"
fi
