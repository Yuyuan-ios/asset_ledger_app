#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "${ROOT}" ]]; then
  echo "error: not inside a git repository" >&2
  exit 1
fi

cd "${ROOT}"

BRANCH="$(git branch --show-current)"
if [[ -z "${BRANCH}" ]]; then
  BRANCH="(detached HEAD)"
fi

echo "repository: $(pwd)"
echo "branch: ${BRANCH}"
echo "HEAD: $(git rev-parse --short HEAD)"
echo

echo "staged diff stat:"
STAGED_DIFF_STAT="$(git diff --cached --stat)"
if [[ -z "${STAGED_DIFF_STAT}" ]]; then
  echo "No staged diff."
else
  printf '%s\n' "${STAGED_DIFF_STAT}"
fi
echo

echo "tracked diff stat:"
TRACKED_DIFF_STAT="$(git diff --stat)"
if [[ -z "${TRACKED_DIFF_STAT}" ]]; then
  echo "No tracked diff."
else
  printf '%s\n' "${TRACKED_DIFF_STAT}"
fi
echo

echo "tracked changed files:"
TRACKED_CHANGED_FILES="$(git diff --name-only)"
if [[ -z "${TRACKED_CHANGED_FILES}" ]]; then
  echo "No tracked changed files."
else
  printf '%s\n' "${TRACKED_CHANGED_FILES}"
fi
echo

echo "untracked files:"
UNTRACKED_FILES="$(git ls-files --others --exclude-standard)"
if [[ -z "${UNTRACKED_FILES}" ]]; then
  echo "No untracked files."
else
  printf '%s\n' "${UNTRACKED_FILES}"
fi
