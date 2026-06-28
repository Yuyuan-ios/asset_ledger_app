#!/usr/bin/env bash
set -uo pipefail

APP_DIR="${IAP_APP_DIR:-/opt/fleet-ledger-iap}"
VENV_PYTHON="${IAP_VENV_PYTHON:-$APP_DIR/venv/bin/python}"
APP_ENTRYPOINT="${IAP_ENTRYPOINT:-$APP_DIR/app.py}"
COMMON_DIR="${IAP_COMMON_DIR:-/opt/common}"
ENV_FILE="${IAP_ENV_FILE:-/etc/fleet-ledger/iap.env}"
SERVICE_NAME="${IAP_SERVICE_NAME:-fleet-ledger-iap.service}"
EXPECTED_EXEC_START="${IAP_EXPECTED_EXEC_START:-/opt/fleet-ledger-iap/venv/bin/python /opt/fleet-ledger-iap/app.py}"
TMP_DIR="$(mktemp -d /tmp/fleet-ledger-iap.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

FAILURES=0
WARNINGS=0

fail() {
  echo "FAIL $*"
  FAILURES=$((FAILURES + 1))
}

pass() {
  echo "PASS $*"
}

warn() {
  echo "WARN $*"
  WARNINGS=$((WARNINGS + 1))
}

server_context_detected() {
  [[ -e "$APP_DIR" || -e "$ENV_FILE" ]] && return 0
  if command -v systemctl >/dev/null 2>&1; then
    systemctl cat "$SERVICE_NAME" >/dev/null 2>&1 && return 0
  fi
  return 1
}

check_path() {
  local kind="$1"
  local path="$2"
  case "$kind" in
    dir)
      [[ -d "$path" ]] && pass "$path exists" || fail "$path is missing"
      ;;
    file)
      [[ -f "$path" ]] && pass "$path exists" || fail "$path is missing"
      ;;
    executable)
      [[ -x "$path" ]] && pass "$path exists and is executable" || fail "$path is missing or not executable"
      ;;
  esac
}

check_env_file() {
  if [[ ! -f "$ENV_FILE" ]]; then
    fail "$ENV_FILE is missing"
    return
  fi

  pass "$ENV_FILE exists"
  if grep -Eq '^[[:space:]]*(export[[:space:]]+)?SERVICE_INTERNAL_TOKEN[[:space:]]*=' "$ENV_FILE"; then
    pass "$ENV_FILE contains SERVICE_INTERNAL_TOKEN key"
  else
    fail "$ENV_FILE does not contain SERVICE_INTERNAL_TOKEN key"
  fi

  local configured_port
  configured_port="$(sed -n -E 's/^[[:space:]]*(export[[:space:]]+)?FLEET_IAP_PORT[[:space:]]*=[[:space:]]*"?([0-9]+)"?[[:space:]]*$/\2/p' "$ENV_FILE" | tail -n 1)"
  if [[ -z "$configured_port" ]]; then
    pass "FLEET_IAP_PORT is not set; app default is 8010"
  elif [[ "$configured_port" == "8010" ]]; then
    pass "FLEET_IAP_PORT is 8010"
  else
    fail "FLEET_IAP_PORT must be 8010 for IAP, got $configured_port"
  fi
}

check_systemd() {
  if ! command -v systemctl >/dev/null 2>&1; then
    fail "systemctl is not available"
    return
  fi

  if systemctl cat "$SERVICE_NAME" > "$TMP_DIR/$SERVICE_NAME.unit" 2>/dev/null; then
    pass "$SERVICE_NAME exists"
  else
    fail "$SERVICE_NAME is missing"
    return
  fi

  local exec_start
  exec_start="$(systemctl show "$SERVICE_NAME" -p ExecStart --value 2>/dev/null)"
  if [[ "$exec_start" == *"$EXPECTED_EXEC_START"* ]]; then
    pass "$SERVICE_NAME ExecStart matches expected IAP command"
  else
    fail "$SERVICE_NAME ExecStart must include: $EXPECTED_EXEC_START"
  fi

  if [[ "$exec_start" == *"8009"* || "$exec_start" == *"fleet-ledger-cloud-sync"* ]]; then
    fail "$SERVICE_NAME ExecStart references cloud-sync or 8009"
  else
    pass "$SERVICE_NAME ExecStart does not reference 8009/cloud-sync"
  fi
}

check_python_compile() {
  if [[ ! -x "$VENV_PYTHON" || ! -f "$APP_ENTRYPOINT" ]]; then
    fail "cannot run py_compile because the venv python or app.py is missing"
    return
  fi

  shopt -s nullglob
  local python_files=("$APP_DIR"/*.py)
  shopt -u nullglob
  if [[ "${#python_files[@]}" -eq 0 ]]; then
    fail "no Python files found under $APP_DIR"
    return
  fi

  if PYTHONDONTWRITEBYTECODE=1 "$VENV_PYTHON" - "${python_files[@]}" <<'PY'
import os
import py_compile
import sys

for path in sys.argv[1:]:
    py_compile.compile(path, cfile=os.devnull, doraise=True)
PY
  then
    pass "$APP_DIR Python files compile"
  else
    fail "$APP_DIR Python files failed py_compile"
  fi
}

check_imports() {
  if [[ ! -x "$VENV_PYTHON" || ! -f "$APP_ENTRYPOINT" ]]; then
    fail "cannot validate imports because the venv python or app.py is missing"
    return
  fi

  if (cd "$APP_DIR" && PYTHONDONTWRITEBYTECODE=1 PYTHONPATH="/opt:${PYTHONPATH:-}" "$VENV_PYTHON" - <<'PY')
import jwt
import app
PY
  then
    pass "PyJWT and app imports are valid"
  else
    fail "PyJWT or app import failed"
  fi
}

main() {
  if ! server_context_detected; then
    echo "server-only check skipped / path missing: $APP_DIR"
    echo "IAP_PREDEPLOY_CHECK_PASS"
    return 0
  fi

  check_path dir "$APP_DIR"
  check_path executable "$VENV_PYTHON"
  check_path file "$APP_ENTRYPOINT"
  check_path dir "$COMMON_DIR"
  check_env_file
  check_systemd
  check_python_compile
  check_imports

  if [[ "$FAILURES" -eq 0 ]]; then
    [[ "$WARNINGS" -gt 0 ]] && echo "WARNINGS=$WARNINGS"
    echo "IAP_PREDEPLOY_CHECK_PASS"
    return 0
  fi

  [[ "$WARNINGS" -gt 0 ]] && echo "WARNINGS=$WARNINGS"
  echo "IAP_PREDEPLOY_CHECK_FAIL"
  return 1
}

main "$@"
