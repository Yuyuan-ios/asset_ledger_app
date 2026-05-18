#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_parent="$(mktemp -d "${TMPDIR:-/tmp}/asset_ledger_custom_lint.XXXXXX")"
lint_root="$tmp_parent/asset_ledger_app"

cleanup() {
  if [[ "${ASSET_LEDGER_KEEP_LINT_WORKSPACE:-0}" != "1" ]]; then
    rm -rf "$tmp_parent"
  else
    echo "Kept isolated custom_lint workspace at: $lint_root"
  fi
}
trap cleanup EXIT

mkdir -p "$lint_root"

rsync -a \
  --delete \
  --exclude='.git/' \
  --exclude='.claude/' \
  --exclude='build/' \
  --exclude='ios/Pods/' \
  --exclude='macos/Pods/' \
  "$repo_root/" \
  "$lint_root/"

cd "$lint_root"
dart run custom_lint "$@"
