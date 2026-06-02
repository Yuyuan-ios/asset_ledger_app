#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "${ROOT}" ]]; then
  echo "error: not inside a git repository" >&2
  exit 1
fi

cd "${ROOT}"

require_command() {
  local name="$1"
  if ! command -v "${name}" >/dev/null 2>&1; then
    echo "error: required command not found: ${name}" >&2
    exit 1
  fi
}

run_step() {
  local label="$1"
  shift
  echo "==> ${label}"
  if ! "$@"; then
    echo "error: ${label} failed" >&2
    exit 1
  fi
}

require_command git
require_command flutter

if [[ ! -f "tools/run_custom_lint_isolated.sh" ]]; then
  echo "error: missing tools/run_custom_lint_isolated.sh" >&2
  exit 1
fi

run_step "flutter analyze" flutter analyze
run_step "custom lint" bash tools/run_custom_lint_isolated.sh
run_step "git diff --check" git diff --check
