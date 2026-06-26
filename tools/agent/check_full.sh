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

resolve_executable() {
  local path="$1"
  while [[ -L "${path}" ]]; do
    local target
    target="$(readlink "${path}")"
    if [[ "${target}" == /* ]]; then
      path="${target}"
    else
      path="$(cd "$(dirname "${path}")" && pwd -P)/${target}"
    fi
  done
  echo "$(cd "$(dirname "${path}")" && pwd -P)/$(basename "${path}")"
}

check_flutter_sdk_cache_writable() {
  local flutter_bin
  flutter_bin="$(resolve_executable "$(command -v flutter)")"
  local sdk_root
  sdk_root="$(cd "$(dirname "${flutter_bin}")/.." && pwd -P)"
  local cache_dir="${sdk_root}/bin/cache"
  local engine_stamp="${cache_dir}/engine.stamp"

  if [[ -d "${cache_dir}" && ! -w "${cache_dir}" ]]; then
    echo "error: Flutter SDK cache is not writable." >&2
    echo "  Cache: ${cache_dir}" >&2
    echo "  Rerun with proper permissions or use a writable Flutter SDK/cache." >&2
    echo "  This is an environment permission issue, not necessarily a project test failure." >&2
    exit 1
  fi

  if [[ -e "${engine_stamp}" && ! -w "${engine_stamp}" ]]; then
    echo "error: Flutter SDK cache is not writable." >&2
    echo "  File: ${engine_stamp}" >&2
    echo "  Rerun with proper permissions or use a writable Flutter SDK/cache." >&2
    echo "  This is an environment permission issue, not necessarily a project test failure." >&2
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
check_flutter_sdk_cache_writable

if [[ ! -f "tools/run_custom_lint_isolated.sh" ]]; then
  echo "error: missing tools/run_custom_lint_isolated.sh" >&2
  exit 1
fi

run_step "flutter analyze" flutter analyze
run_step "custom lint" bash tools/run_custom_lint_isolated.sh
# Run the suite in two passes so the `arch-script` tests never execute
# concurrently with the rest. check_architecture_failure_behavior_test.dart
# (the only `arch-script` test) writes/deletes temporary `__arch_probe_*` files
# under lib/ to exercise tools/check_architecture.sh; the many invariant tests
# that scan lib/ would otherwise race against those writes and flake with
# PathNotFoundException. Isolating the tag honors that test's own
# "不要并行运行" note.
run_step "flutter test --no-pub (excl arch-script)" \
  flutter test --no-pub --exclude-tags arch-script
run_step "flutter test --no-pub (arch-script, serial)" \
  flutter test --no-pub --tags arch-script --concurrency=1
run_step "git diff --check" git diff --check
