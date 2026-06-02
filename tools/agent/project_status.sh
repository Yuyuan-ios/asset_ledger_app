#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "${ROOT}" ]]; then
  echo "error: not inside a git repository" >&2
  exit 1
fi

cd "${ROOT}"

echo "pwd: $(pwd)"
echo
echo "branch:"
git branch --show-current
echo
echo "HEAD:"
git rev-parse --short HEAD
echo
echo "status:"
git status --short
echo
echo "recent commits:"
git log --oneline --decorate -5
