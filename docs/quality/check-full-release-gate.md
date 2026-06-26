# `check_full.sh` — Full Release Gate (complete reference)

This document fully specifies `tools/agent/check_full.sh`: its purpose, prerequisites,
every step it runs, the helper scripts it depends on, the architecture boundary
rules it indirectly enforces, and the exact exit / pass-fail semantics. It is the
canonical reference for anyone (human or agent) running the release gate.

> TL;DR — `bash tools/agent/check_full.sh` is the **green-before-release** gate. It
> runs, in order: `flutter analyze` → isolated `custom_lint` → the full test suite
> (split into two passes) → `git diff --check`. It is **fail-fast**: the first failing
> step aborts the whole run with a non-zero exit. A clean run ends with the last step
> succeeding and exit code `0`.

---

## 1. Purpose & when to run

- **What it is:** the comprehensive local/CI quality gate that must be green before
  merging to `main` / cutting a release build.
- **Relation to `check_fast.sh`:** `check_fast.sh` is the quick subset
  (`flutter analyze` + `custom_lint` + `git diff --check`, **no tests**). `check_full.sh`
  adds the **entire test suite** on top. Use fast for inner-loop, full for release.
- **Run from anywhere in the repo:** the script `cd`s to the git top level itself.

## 2. Prerequisites (must be on `PATH`)

| Tool | Used by | Notes |
|---|---|---|
| `git` | check_full (root resolve, `git diff --check`) | Hard-required; script exits if missing. |
| `flutter` | `flutter analyze`, `flutter test` | Hard-required; script exits if missing. |
| `dart` | `dart run custom_lint` (via isolated helper) | Comes with Flutter SDK. |
| `rsync` | `run_custom_lint_isolated.sh` | Copies repo into a temp workspace. |
| `bash` | the `arch-script` test → `check_architecture.sh` | POSIX shell. |
| `rg` (ripgrep) | `check_architecture.sh` | Boundary pattern checks (PCRE2 `-P`). |
| `python3` | `check_architecture.sh` (CJK + SyncEnqueuer rules) | Rules fail-closed if absent. |

Also: pub dependencies must already be fetched, because the test steps use
`--no-pub` (no implicit `flutter pub get`). If deps are stale, run `flutter pub get`
first.

## 3. Step-by-step walkthrough of `check_full.sh`

The script sets `set -euo pipefail` (unset vars, pipe failures, and any non-zero
command all abort). Two helpers shape its behavior:

- `require_command <name>` — exits `1` with `error: required command not found: <name>`
  if the command is not on `PATH`.
- `run_step "<label>" <cmd...>` — prints `==> <label>`, runs the command, and on a
  non-zero result prints `error: <label> failed` to stderr and **exits `1`**. This is
  what makes the gate **fail-fast**.

Preamble (before any step):
1. `ROOT="$(git rev-parse --show-toplevel)"`; if empty → `error: not inside a git repository`, exit `1`.
2. `cd "$ROOT"`.
3. `require_command git`, `require_command flutter`.
4. Verify `tools/run_custom_lint_isolated.sh` exists; else `error: missing ...`, exit `1`.

Then the five gate steps, in this exact order (fail-fast — a failure stops the rest):

### Step 1 — `flutter analyze`
- `run_step "flutter analyze" flutter analyze`
- Runs the Dart analyzer over the whole project using `analysis_options.yaml`:
  `include: package:flutter_lints/flutter.yaml`, analyzer `plugins: [custom_lint]`,
  and `exclude: [.claude/**, patrol_test/**, integration_test/**, test_driver/**]`.
- **Pass:** "No issues found!" (exit 0). **Fail:** any error/warning → non-zero → gate aborts.

### Step 2 — `custom lint` (isolated)
- `run_step "custom lint" bash tools/run_custom_lint_isolated.sh`
- Runs `dart run custom_lint` against an **isolated rsync copy** of the repo (see §4),
  so it never mutates the working tree and avoids `.dart_tool`/plugin interference.
- **Pass:** "No issues found!". **Fail:** any custom lint → non-zero → gate aborts.

### Step 3 — full test suite, pass A (everything except `arch-script`)
- `run_step "flutter test --no-pub (excl arch-script)" flutter test --no-pub --exclude-tags arch-script`
- Runs the entire test suite **except** the single test tagged `arch-script`.
- **Pass:** "All tests passed!". **Fail:** any failing test → non-zero → gate aborts.

### Step 4 — `arch-script` test, serial
- `run_step "flutter test --no-pub (arch-script, serial)" flutter test --no-pub --tags arch-script --concurrency=1`
- Runs **only** `test/tools/check_architecture_failure_behavior_test.dart`
  (declared `@Tags(['arch-script'])`), with `--concurrency=1`.
- **Why split (Steps 3 & 4):** the `arch-script` test invokes `tools/check_architecture.sh`
  end-to-end, which **writes and deletes temporary `__arch_probe_*.dart` files under
  `lib/`**. Many other invariant tests scan `lib/` and would race against those writes,
  flaking with `PathNotFoundException`. Isolating the tag (exclude it in pass A, run it
  alone in pass B) honors the test's own "不要并行运行" (do not run in parallel) note.

### Step 5 — `git diff --check`
- `run_step "git diff --check" git diff --check`
- Flags whitespace errors (trailing whitespace, space-before-tab) and leftover merge
  conflict markers in tracked changes.
- **Pass:** no output, exit 0. **Fail:** any flagged line → non-zero → gate aborts.

If all five steps pass, the script falls off the end with exit code `0` = **gate green**.

## 4. `tools/run_custom_lint_isolated.sh` (Step 2 internals)

1. `mktemp -d` a temp parent; target `<tmp>/asset_ledger_app`.
2. `trap cleanup EXIT` removes the temp dir on exit — **unless**
   `ASSET_LEDGER_KEEP_LINT_WORKSPACE=1`, in which case it prints the kept path
   (useful for debugging a lint failure).
3. `rsync -a --delete` the repo into the temp copy, excluding `.git/`, `.claude/`,
   `build/`, `ios/Pods/`, `macos/Pods/`.
4. Idempotently ensure `analysis_options.yaml` lists `- custom_lint` under the analyzer
   plugins (awk-injects it if absent).
5. `cd` into the copy and run `dart run custom_lint "$@"`.
- **Rationale:** runs custom_lint in a throwaway workspace so the gate never dirties the
  working tree and the plugin run is hermetic.

## 5. `tools/check_architecture.sh` (enforced via the Step-4 test)

Not called directly by `check_full.sh` — it is exercised end-to-end by the `arch-script`
test, so a boundary regression fails **Step 4**. It uses ripgrep (PCRE2, `-P`) and
`python3`, accumulates a `failures` counter, prints
`Architecture boundary checks passed.` only when **zero violations and zero rg errors**,
otherwise prints the violation count and exits `1`. ripgrep exit code `≥2` (a real rg
error) is treated as failure and **not swallowed**.

Rules enforced (each forbidden match = a violation):
- **data/state layering:** `lib/data` and `*/state` must not import `components/`,
  `patterns/`, or `features/*/view/`.
- **reusable UI store access:** `lib/components`, `lib/patterns` must not use
  `context.read` / `context.watch`.
- **UI fontFamily:** `lib/features|components|patterns` must not set `fontFamily:`.
- **migrated-module TextStyle:** no direct `TextStyle(` in migrated account/fuel/
  maintenance/timing + selected components/patterns (allowlist:
  `account_overview_card_pattern.dart`).
- **migrated CJK (python3):** files listed in
  `test/i18n/migrated_files_no_hardcoded_cjk_test.dart`'s `migratedFiles` must contain no
  hardcoded CJK in code (comments stripped).
- **patterns/timing + patterns/device boundary:** no `data/services` import, no direct
  `TimingService` / `DeviceLabel` / `Provider.of` / `Provider<...>` usage.
- **patterns infrastructure ban:** `lib/patterns` must not import `infrastructure/`,
  `repositories/`, `db/`, or `use_cases/`. (patterns → `data/models` is **deliberately
  allowed** per `docs/architecture/layers.md`.)
- **features → DB ban:** `lib/features` must not import `data/db/`, `package:sqflite`, or
  use `AppDatabase` directly.
- **SyncEnqueuer DI (python3):** no no-arg `*SyncEnqueuer()` construction in `lib/app` /
  `lib/main.dart` or anywhere in `lib/` outside a DI default-parameter seam.

## 6. Exit & pass/fail rules (summary)

- **Fail-fast:** steps run in order; the first non-zero step prints
  `error: <label> failed` and the script exits `1` immediately. Later steps do not run.
- **Green = exit 0:** only when all of analyze, custom_lint, both test passes, and
  `git diff --check` succeed.
- **Preconditions** (missing git/flutter/helper, or not in a repo) exit `1` before any
  step, with a specific `error:` message.
- **Architecture regressions** surface as a **Step 4** test failure (the test asserts the
  script exits 0 on a clean tree, non-zero on an injected violation, and 0 again once
  removed).

## 7. How to run + expected output

```bash
flutter pub get            # only if dependencies are stale (steps use --no-pub)
bash tools/agent/check_full.sh
```

Expected on success — each step echoes its `==>` banner and passes:
```
==> flutter analyze
No issues found!
==> custom lint
No issues found!
==> flutter test --no-pub (excl arch-script)
All tests passed!
==> flutter test --no-pub (arch-script, serial)
All tests passed!
==> git diff --check
```
Exit code `0`. Any `error: <label> failed` line means that step is the failure point.

## 8. Troubleshooting

- **`PathNotFoundException` / `__arch_probe_*` flakes:** indicates the two-pass split was
  bypassed (e.g. running the whole suite without `--exclude-tags arch-script`). Always go
  through `check_full.sh`, which isolates the `arch-script` tag.
- **`python3`/`rg`/`rsync` not found:** install them; the CJK and SyncEnqueuer arch rules
  fail-closed without `python3`, and the isolated lint needs `rsync`.
- **Inspect a custom_lint failure workspace:** rerun with
  `ASSET_LEDGER_KEEP_LINT_WORKSPACE=1 bash tools/agent/check_full.sh` (or call the helper
  directly) to keep the temp copy for inspection.
- **`--no-pub` surprises:** if a dependency was just added, run `flutter pub get` before
  the gate.
