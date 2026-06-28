#!/usr/bin/env bash
set -uo pipefail

IAP_BASE_URL="${IAP_BASE_URL:-http://127.0.0.1:8010}"
IAP_ENV_FILE="${IAP_ENV_FILE:-/etc/fleet-ledger/iap.env}"
IAP_CONNECT_TIMEOUT_SECONDS="${IAP_CONNECT_TIMEOUT_SECONDS:-5}"
IAP_MAX_TIME_SECONDS="${IAP_MAX_TIME_SECONDS:-20}"
TMP_DIR="$(mktemp -d /tmp/fleet-ledger-iap.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

shopt -s extglob

DENYLIST_PATTERN='purchaseToken|signature|transaction_id|transactionId|bearer|secret|JWS|rawPayload|raw_payload|authorization|SERVICE_INTERNAL_TOKEN'
FAILURES=0
SERVICE_INTERNAL_TOKEN_VALUE=""

fail() {
  echo "FAIL $*"
  FAILURES=$((FAILURES + 1))
}

pass() {
  echo "PASS $*"
}

trim_value() {
  local value="$1"
  value="${value##+([[:space:]])}"
  value="${value%%+([[:space:]])}"
  value="${value%$'\r'}"
  if [[ "$value" == \"*\" && "$value" == *\" ]]; then
    value="${value:1:${#value}-2}"
  elif [[ "$value" == \'*\' && "$value" == *\' ]]; then
    value="${value:1:${#value}-2}"
  fi
  printf '%s' "$value"
}

load_service_token() {
  local line value
  if [[ ! -f "$IAP_ENV_FILE" ]]; then
    fail "IAP env file is missing: $IAP_ENV_FILE"
    return
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    if [[ "$line" =~ ^[[:space:]]*(export[[:space:]]+)?SERVICE_INTERNAL_TOKEN[[:space:]]*=(.*)$ ]]; then
      value="$(trim_value "${BASH_REMATCH[2]}")"
      SERVICE_INTERNAL_TOKEN_VALUE="$value"
    fi
  done < "$IAP_ENV_FILE"

  if [[ -z "$SERVICE_INTERNAL_TOKEN_VALUE" ]]; then
    fail "SERVICE_INTERNAL_TOKEN is missing from $IAP_ENV_FILE"
  fi
}

write_auth_config() {
  local file="$1"
  local token="$2"
  umask 077
  printf 'header = "Authorization: Bearer %s"\n' "$token" > "$file"
}

request_status() {
  local label="$1"
  local path="$2"
  local auth_config="${3:-}"
  local body_file="$TMP_DIR/${label}.body"
  local url="${IAP_BASE_URL%/}$path"
  local status
  local curl_args=(
    -sS
    --connect-timeout "$IAP_CONNECT_TIMEOUT_SECONDS"
    --max-time "$IAP_MAX_TIME_SECONDS"
    -o "$body_file"
    -w "%{http_code}"
    -H "Accept: application/json"
  )

  if [[ -n "$auth_config" ]]; then
    curl_args+=(--config "$auth_config")
  fi

  if ! status="$(curl "${curl_args[@]}" "$url")"; then
    status="curl_error"
  fi

  printf '%s|%s' "$status" "$body_file"
}

status_allowed() {
  local status="$1"
  shift
  local allowed
  for allowed in "$@"; do
    [[ "$status" == "$allowed" ]] && return 0
  done
  return 1
}

body_size() {
  local body_file="$1"
  if [[ -f "$body_file" ]]; then
    wc -c < "$body_file" | tr -d '[:space:]'
  else
    printf '0'
  fi
}

scan_denylist() {
  local label="$1"
  local body_file="$2"
  if [[ -s "$body_file" ]] && grep -Eq "$DENYLIST_PATTERN" "$body_file"; then
    fail "$label body matched the sensitive leak denylist"
  fi
}

run_check() {
  local label="$1"
  local path="$2"
  local auth_config="$3"
  shift 3
  local result status body_file bytes

  result="$(request_status "$label" "$path" "$auth_config")"
  status="${result%%|*}"
  body_file="${result#*|}"
  bytes="$(body_size "$body_file")"

  if status_allowed "$status" "$@"; then
    pass "$label status=$status bytes=$bytes"
  else
    fail "$label expected status one of [$*], got $status bytes=$bytes"
  fi

  scan_denylist "$label" "$body_file"
}

main() {
  load_service_token
  if [[ "$FAILURES" -ne 0 ]]; then
    echo "BOL_RUNTIME_SMOKE_FAIL"
    return 1
  fi

  local valid_auth_config="$TMP_DIR/valid-auth.curlrc"
  local wrong_auth_config="$TMP_DIR/wrong-auth.curlrc"
  write_auth_config "$valid_auth_config" "$SERVICE_INTERNAL_TOKEN_VALUE"
  write_auth_config "$wrong_auth_config" "definitely-wrong-token"

  run_check "explain-no-token" "/internal/v3/billing/explain/smoke-user" "" 401
  run_check "explain-wrong-token" "/internal/v3/billing/explain/smoke-user" "$wrong_auth_config" 401
  run_check "explain-valid-token" "/internal/v3/billing/explain/smoke-user" "$valid_auth_config" 200 404

  run_check "graph-no-token" "/internal/v3/billing/graph/smoke-user" "" 401
  run_check "graph-wrong-token" "/internal/v3/billing/graph/smoke-user" "$wrong_auth_config" 401
  run_check "graph-valid-token" "/internal/v3/billing/graph/smoke-user" "$valid_auth_config" 200 404
  run_check "graph-summary-valid-token" "/internal/v3/billing/graph/smoke-user/summary" "$valid_auth_config" 200 404
  run_check "graph-event-valid-token" "/internal/v3/billing/graph/event/1" "$valid_auth_config" 200 404

  if [[ "$FAILURES" -eq 0 ]]; then
    echo "BOL_RUNTIME_SMOKE_PASS"
    return 0
  fi

  echo "BOL_RUNTIME_SMOKE_FAIL"
  return 1
}

main "$@"
