#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

export PATH="$PATH:$HOME/.pub-cache/bin"

run_patrol=1
patrol_device="${PATROL_DEVICE:-macos}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-patrol)
      run_patrol=1
      shift
      ;;
    --skip-patrol)
      run_patrol=0
      shift
      ;;
    --device)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --device" >&2
        exit 2
      fi
      patrol_device="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: bash tools/agent_preflight.sh [--skip-patrol] [--device <deviceId>]" >&2
      exit 2
      ;;
  esac
done

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
}

print_section() {
  printf '\n== %s ==\n' "$1"
}

print_section "Command Checks"
for cmd in rg flutter dart sg; do
  require_cmd "$cmd"
  echo "Found: $cmd"
done

if command -v patrol >/dev/null 2>&1; then
  echo "Found: patrol"
else
  if [[ "$run_patrol" -eq 1 ]]; then
    echo "Missing required command for default preflight: patrol" >&2
    exit 1
  fi
  echo "Optional command missing: patrol"
fi

print_section "GitNexus"
if [[ -f .gitnexus/meta.json ]]; then
  repo_path="$(sed -n 's/.*"repoPath": "\(.*\)".*/\1/p' .gitnexus/meta.json | head -n 1)"
  indexed_at="$(sed -n 's/.*"indexedAt": "\(.*\)".*/\1/p' .gitnexus/meta.json | head -n 1)"
  last_commit="$(sed -n 's/.*"lastCommit": "\(.*\)".*/\1/p' .gitnexus/meta.json | head -n 1)"
  echo "Index present: yes"
  echo "Indexed repo: ${repo_path:-unknown}"
  echo "Indexed at: ${indexed_at:-unknown}"
  echo "Indexed commit: ${last_commit:-unknown}"
else
  echo "Index present: no (.gitnexus/meta.json missing)"
fi

print_section "Architecture Boundary Check"
bash tools/check_architecture.sh

print_section "Flutter Analyze"
flutter analyze

print_section "Custom Lint"
dart run custom_lint

if [[ "$run_patrol" -eq 1 ]]; then
  print_section "Patrol Smoke Test"
  require_cmd patrol
  echo "Using device: $patrol_device"
  CI=true PATROL_ANALYTICS_ENABLED=false \
    patrol test -t integration_test/device_flow_test.dart -d "$patrol_device"
fi

print_section "Preflight Complete"
echo "Project checks are ready. Safe to start deeper development work."
