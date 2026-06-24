#!/usr/bin/env bash
# Architecture boundary checks.
#
# Behaviors:
# - Missing paths fail the script (unless explicitly marked optional below).
# - Pattern matches are violations and fail the script.
# - rg invocation errors (exit code >= 2) fail the script and are not swallowed.
# - The script only prints "Architecture boundary checks passed." when there
#   are zero violations and zero rg errors.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

failures=0

# require_paths <label> <path...>
# Returns 0 if all paths exist; otherwise logs and increments failures.
require_paths() {
  local label="$1"
  shift
  local missing=0
  for path in "$@"; do
    if [[ ! -e "$path" ]]; then
      echo "[$label] required path does not exist: $path"
      missing=1
    fi
  done
  if [[ "$missing" -ne 0 ]]; then
    failures=$((failures + 1))
    return 1
  fi
  return 0
}

# run_forbidden_pattern_check <label> <pattern> <path...>
# Uses PCRE2 (-P) so we can express boundary-sensitive patterns precisely.
# rg exit codes (PCRE2 mode):
#   0 -> matches found     => violation, fail
#   1 -> no matches found  => clean, OK
#   2+ -> rg error         => fail (do not swallow)
run_forbidden_pattern_check() {
  local label="$1"
  local pattern="$2"
  shift 2

  require_paths "$label" "$@" || return 0

  echo "$label..."
  local output
  set +e
  output="$(rg -nP --glob '*.dart' "$pattern" "$@" 2>&1)"
  local rg_status=$?
  set -e

  case "$rg_status" in
    0)
      echo "$output"
      echo "  -> [$label] forbidden pattern matched."
      failures=$((failures + 1))
      ;;
    1)
      : # No matches, clean.
      ;;
    *)
      echo "$output"
      echo "  -> [$label] ripgrep failed with exit code $rg_status."
      failures=$((failures + 1))
      ;;
  esac
}

run_forbidden_pattern_check "Checking data/state imports" \
  '^import .*components/|^import .*patterns/|^import .*features/.*/view/' \
  lib/data \
  lib/features/account/state \
  lib/features/fuel/state \
  lib/features/maintenance/state \
  lib/features/timing/state

run_forbidden_pattern_check "Checking reusable UI store access" \
  'context\.(watch|read)' \
  lib/components \
  lib/patterns

run_forbidden_pattern_check "Checking UI-layer fontFamily usage" \
  'fontFamily\s*:' \
  lib/features \
  lib/components \
  lib/patterns

# Direct TextStyle usage: (?<![A-Za-z]) so DefaultTextStyle / SomeTextStyle
# don't false-positive. Allowlist account_overview_card_pattern.dart kept
# as before via --glob '!...'.
run_forbidden_pattern_check_with_glob() {
  local label="$1"
  local pattern="$2"
  local exclude_glob="$3"
  shift 3

  require_paths "$label" "$@" || return 0

  echo "$label..."
  local output
  set +e
  output="$(rg -nP --glob '*.dart' --glob "$exclude_glob" "$pattern" "$@" 2>&1)"
  local rg_status=$?
  set -e

  case "$rg_status" in
    0)
      echo "$output"
      echo "  -> [$label] forbidden pattern matched."
      failures=$((failures + 1))
      ;;
    1)
      :
      ;;
    *)
      echo "$output"
      echo "  -> [$label] ripgrep failed with exit code $rg_status."
      failures=$((failures + 1))
      ;;
  esac
}

run_forbidden_pattern_check_with_glob \
  "Checking migrated modules for direct TextStyle usage" \
  '(?<![A-Za-z])TextStyle\s*\(' \
  '!lib/patterns/account/account_overview_card_pattern.dart' \
  lib/features/account \
  lib/features/fuel \
  lib/features/maintenance \
  lib/features/timing \
  lib/components/feedback \
  lib/components/buttons \
  lib/components/fields \
  lib/components/avatars \
  lib/components/pickers \
  lib/patterns/account \
  lib/patterns/fuel \
  lib/patterns/maintenance \
  lib/patterns/timing \
  lib/patterns/device

run_migrated_files_no_hardcoded_cjk_check() {
  local label="$1"
  local manifest="$2"

  require_paths "$label" "$manifest" || return 0

  if ! command -v python3 >/dev/null 2>&1; then
    echo "  -> [$label] python3 is required for this rule but was not found on PATH."
    echo "     Install python3 (e.g. 'brew install python') or ensure it is on PATH."
    failures=$((failures + 1))
    return 0
  fi

  echo "$label..."
  local output
  set +e
  output="$(python3 - "$manifest" <<'PY' 2>&1
import os
import re
import sys

RULE = "migrated_files_no_hardcoded_cjk"
CJK_RE = re.compile(r"[\u4e00-\u9fff\u3400-\u4dbf]")
MIGRATED_LIST_RE = re.compile(
    r"const\s+List<String>\s+migratedFiles\s*=\s*<String>\s*\[(.*?)\]\s*;",
    re.DOTALL,
)
PATH_RE = re.compile(r"'([^']+)'")


def strip_comments(source):
    without_block = re.sub(r"/\*.*?\*/", "", source, flags=re.DOTALL)
    lines = []
    for line in without_block.split("\n"):
        idx = line.find("//")
        lines.append(line[:idx] if idx >= 0 else line)
    return "\n".join(lines)


manifest_path = sys.argv[1]
repo_root = os.getcwd()

with open(manifest_path, "r", encoding="utf-8") as handle:
    manifest_source = handle.read()

match = MIGRATED_LIST_RE.search(manifest_source)
if match is None:
    print(f"[{RULE}] could not find const List<String> migratedFiles in {manifest_path}.")
    sys.exit(2)

migrated_files = PATH_RE.findall(match.group(1))
if not migrated_files:
    print(f"[{RULE}] migratedFiles list is empty in {manifest_path}.")
    sys.exit(2)

violations = []
for relative_path in migrated_files:
    path = os.path.join(repo_root, relative_path)
    if not os.path.exists(path):
        violations.append((relative_path, 0, "listed migrated file does not exist"))
        continue

    with open(path, "r", encoding="utf-8") as handle:
        source = handle.read()
    code = strip_comments(source)
    cjk_match = CJK_RE.search(code)
    if cjk_match is None:
        continue

    line_number = code.count("\n", 0, cjk_match.start()) + 1
    lines = code.splitlines()
    snippet = lines[line_number - 1].strip() if line_number - 1 < len(lines) else ""
    violations.append((relative_path, line_number, snippet))

if violations:
    print(f"[{RULE}] migrated files must not contain hardcoded CJK in code.")
    for relative_path, line_number, detail in violations:
        if line_number:
            print(f"{relative_path}:{line_number}: {detail}")
        else:
            print(f"{relative_path}: {detail}")
    sys.exit(1)
PY
)"
  local check_status=$?
  set -e

  case "$check_status" in
    0)
      :
      ;;
    1)
      echo "$output"
      echo "  -> [$label] forbidden pattern matched."
      failures=$((failures + 1))
      ;;
    *)
      echo "$output"
      echo "  -> [$label] migrated CJK check failed with exit code $check_status."
      failures=$((failures + 1))
      ;;
  esac
}

run_migrated_files_no_hardcoded_cjk_check \
  "Checking migrated files for hardcoded CJK in code" \
  "${FLEET_ARCH_MIGRATED_CJK_MANIFEST:-test/i18n/migrated_files_no_hardcoded_cjk_test.dart}"

# ============================================================================
# 阶段 C Step 3 / Step 4：守住 timing + device pattern 边界 +
# patterns 全局基础设施依赖禁用。
#
# Step 4 把原先只覆盖 lib/patterns/timing 的 service 边界规则扩大到也覆盖
# lib/patterns/device（C4 已把 device pattern 的 DeviceLabel / TimingService
# 调用上移到 feature 层），让 device pattern 边界一并被工具守住。
#
# 每条 forbidden pattern：
# - 任意匹配视为违规。
# - 注释行（以 // 或 /// 开头）通过 `^(?!\s*//)` 排除，避免文档注释里
#   提及 service 名字被误判。
# - 标识符匹配两侧用 `(?<![A-Za-z0-9_])` / `(?![A-Za-z0-9_])` 守住单词边界，
#   不会把 selectedDeviceLabel / TickerProvider / ChangeNotifierProvider /
#   MyTimingService / TimingServiceFoo / SingleTickerProviderStateMixin 当成违规。
#
# 2026-06-24 决策（formalize-allow，原 P1-S6/S7 歧义收口）：
#   patterns → lib/data/models **刻意允许**。patterns（跨功能复用展示模式）可
#   只读依赖 data/models 的 domain 值对象（Device / TimingRecord 等）用于展示与
#   类型签名；但**不得**依赖 repositories / db / infrastructure / data/services /
#   use_cases（由下方规则强制）。故本脚本不为 patterns→data/models 设禁令。
#   依据：docs/architecture/layers.md「patterns」节。
# ============================================================================

# Rule: patterns_ui_no_data_services
# lib/patterns/timing 与 lib/patterns/device 不允许 import lib/data/services。
run_forbidden_pattern_check "Checking patterns/timing+device for data/services imports" \
  '^import\s+.*data/services' \
  lib/patterns/timing \
  lib/patterns/device

# Rule: patterns_ui_no_timing_service
# 任何非注释行直接引用 TimingService 标识符即违规（含 TimingService.xxx /
# TimingService(...) / as TimingService 等）。
run_forbidden_pattern_check "Checking patterns/timing+device for direct TimingService usage" \
  '^(?!\s*//).*(?<![A-Za-z0-9_])TimingService(?![A-Za-z0-9_])' \
  lib/patterns/timing \
  lib/patterns/device

# Rule: patterns_ui_no_device_label
# 任何非注释行直接引用 DeviceLabel 标识符即违规。
# selectedDeviceLabel 这种普通变量名因为 `d`/`D` 之间没有非字符边界而不会被匹配。
run_forbidden_pattern_check "Checking patterns/timing+device for direct DeviceLabel usage" \
  '^(?!\s*//).*(?<![A-Za-z0-9_])DeviceLabel(?![A-Za-z0-9_])' \
  lib/patterns/timing \
  lib/patterns/device

# Rule: patterns_ui_no_provider_context
# 禁止 Provider.of(...) 和 Provider<X>(...) 直接使用。
# 因为已有 "Checking reusable UI store access" 全局禁了 context.read / context.watch，
# 这条专门覆盖 Provider.of 与 bare Provider<X>。
# TickerProvider / ChangeNotifierProvider / MultiProvider 等不会误判
# （前面的字符都是字母，lookbehind 失败）。
run_forbidden_pattern_check "Checking patterns/timing+device for Provider.of / Provider<...> usage" \
  '^(?!\s*//).*((?<![A-Za-z0-9_])Provider\s*\.\s*of\b|(?<![A-Za-z0-9_])Provider\s*<)' \
  lib/patterns/timing \
  lib/patterns/device

# Rule: patterns_no_infrastructure_imports
run_forbidden_pattern_check "Checking patterns for infrastructure imports" \
  '^import\s+.*/infrastructure/' \
  lib/patterns

# Rule: patterns_no_repository_imports
run_forbidden_pattern_check "Checking patterns for repository imports" \
  '^import\s+.*/repositories/' \
  lib/patterns

# Rule: patterns_no_db_imports
run_forbidden_pattern_check "Checking patterns for db/ imports" \
  '^import\s+.*/db/' \
  lib/patterns

# Rule: patterns_no_use_case_imports
run_forbidden_pattern_check "Checking patterns for use_cases imports" \
  '^import\s+.*/use_cases/' \
  lib/patterns

# Rule: features_no_direct_db_dependencies
#
# Feature-layer code may depend on domain-facing repository APIs, but it must
# not reach into the database handle, db directory, or sqflite package directly.
# This keeps transaction/DB wiring behind data/infrastructure boundaries while
# preserving existing legal imports such as lib/data/repositories.
run_forbidden_pattern_check "Checking features for data/db imports" \
  '^import\s+.*data/db/' \
  lib/features

run_forbidden_pattern_check "Checking features for package:sqflite imports" \
  '^import\s+.*package:sqflite' \
  lib/features

run_forbidden_pattern_check "Checking features for direct AppDatabase usage" \
  '^(?!\s*//).*(?<![A-Za-z0-9_])AppDatabase(?![A-Za-z0-9_])' \
  lib/features

# ============================================================================
# R5.24: composition_no_default_const_sync_enqueuer
#
# The composition root (lib/app/** and lib/main.dart) must NOT construct a
# *SyncEnqueuer with no arguments (bare `XSyncEnqueuer()` or `const
# XSyncEnqueuer()`). A no-arg enqueuer silently falls back to the default
# `const LocalSyncOutboxRepository()` / `const LocalEntitySyncMetaRepository()`,
# which bypasses dependency injection and makes the transaction boundary / test
# doubles impossible to confirm at the wiring layer.
#
# Allowed (NOT matched):
# - Enqueuer construction WITH explicit dependencies, e.g.
#   `AccountPaymentSyncEnqueuer(syncOutboxRepository: repo)` — non-empty parens.
# - The legitimate DI seams in lib/data/** and lib/infrastructure/** where
#   `= const XSyncEnqueuer()` is a constructor *default parameter value*. Those
#   files are intentionally out of scope: they are the injection points, not the
#   composition root, and rewriting them would require an enqueuer base class /
#   factory refactor that is explicitly out of scope for R5.24.
# - Enqueuer class declarations (they live under lib/infrastructure, not here).
#
# Pattern notes:
# - `^(?!\s*//)` skips comment lines so doc comments mentioning an enqueuer name
#   are not flagged.
# - `(?<![A-Za-z0-9_])` guards the left word boundary so `_AccountPaymentSyncEnqueuer`
#   or similar are not partial-matched.
# - `\(\s*\)` requires EMPTY parens, i.e. the no-arg default construction only.
run_forbidden_pattern_check "Checking composition root for default-const SyncEnqueuer construction" \
  '^(?!\s*//).*(?<![A-Za-z0-9_])[A-Za-z0-9_]*SyncEnqueuer\s*\(\s*\)' \
  lib/app \
  lib/main.dart

# Rule: no_default_sync_enqueuer_construction
#
# R5.24 hardening: production code under lib/** must not construct a
# *SyncEnqueuer with no arguments from executable code. The only permitted
# no-arg construction shape is an existing DI seam/default parameter, e.g.
# `Foo({BarSyncEnqueuer enqueuer = const BarSyncEnqueuer()})` or
# `Foo({this.enqueuer = const BarSyncEnqueuer()})`.
#
# This intentionally scans beyond the composition root rule above. It catches
# future method/function/getter/provider-body fallbacks in lib/data and
# lib/infrastructure while keeping current constructor default-parameter seams
# legal until a larger enqueuer DI abstraction is deliberately introduced.
run_no_default_sync_enqueuer_construction_check() {
  local label="$1"
  shift

  require_paths "$label" "$@" || return 0

  # This rule is implemented in Python (comment/string masking + default-param
  # detection are not reliably expressible in a single grep). Fail closed with
  # an actionable message if python3 is unavailable, instead of surfacing a raw
  # "exit code 127". The composition-root grep rule above still guards the
  # highest-risk path (lib/app) without any external interpreter.
  if ! command -v python3 >/dev/null 2>&1; then
    echo "  -> [$label] python3 is required for this rule but was not found on PATH."
    echo "     Install python3 (e.g. 'brew install python') or ensure it is on PATH."
    failures=$((failures + 1))
    return 0
  fi

  echo "$label..."
  local output
  set +e
  output="$(python3 - "$@" <<'PY' 2>&1
import os
import re
import sys

RULE = "no_default_sync_enqueuer_construction"
ENQUEUER_RE = re.compile(
    r"(?<![A-Za-z0-9_])(?:const\s+)?"
    r"[A-Za-z_][A-Za-z0-9_]*SyncEnqueuer\s*\(\s*\)",
    re.MULTILINE,
)
DECL_PREFIX_RE = re.compile(
    r"^(?:external\s+|static\s+|const\s+|factory\s+)*"
    r"(?:(?:[A-Za-z_][A-Za-z0-9_]*|[A-Za-z_][A-Za-z0-9_]*<[^;\n{}=]*>)\s+)?"
    r"[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)?$"
)
DEFAULT_ASSIGNMENT_RE = re.compile(r"(?<![=!<>])=(?!>)")


def mask_comments_and_strings(text):
    chars = list(text)
    i = 0
    n = len(text)
    while i < n:
        if text.startswith("//", i):
            j = text.find("\n", i)
            if j == -1:
                j = n
            _blank(chars, i, j)
            i = j
            continue
        if text.startswith("/*", i):
            j = text.find("*/", i + 2)
            end = n if j == -1 else j + 2
            _blank(chars, i, end)
            i = end
            continue

        raw = text[i] == "r" and i + 1 < n and text[i + 1] in ("'", '"')
        quote_index = i + 1 if raw else i
        if quote_index < n and text[quote_index] in ("'", '"'):
            quote = text[quote_index]
            triple = text.startswith(quote * 3, quote_index)
            start = i
            j = quote_index + (3 if triple else 1)
            while j < n:
                if not raw and text[j] == "\\":
                    j += 2
                    continue
                if triple and text.startswith(quote * 3, j):
                    j += 3
                    break
                if not triple and text[j] == quote:
                    j += 1
                    break
                j += 1
            _blank(chars, start, min(j, n))
            i = min(j, n)
            continue
        i += 1
    return "".join(chars)


def _blank(chars, start, end):
    for idx in range(start, end):
        if chars[idx] != "\n":
            chars[idx] = " "


def is_default_parameter_context(clean, start):
    open_paren = _find_enclosing_paren_before(clean, start)
    if open_paren < 0:
        return False

    segment = clean[open_paren + 1 : start]
    current_param_start = max(segment.rfind(","), segment.rfind("{"), segment.rfind("["))
    current_param = segment[current_param_start + 1 :]
    if DEFAULT_ASSIGNMENT_RE.search(current_param) is None:
        return False

    prefix_start = max(
        clean.rfind("\n", 0, open_paren),
        clean.rfind(";", 0, open_paren),
        clean.rfind("{", 0, open_paren),
        clean.rfind("}", 0, open_paren),
    ) + 1
    prefix = clean[prefix_start:open_paren].strip()
    if not prefix:
        return False
    return DECL_PREFIX_RE.match(prefix) is not None


def _find_enclosing_paren_before(clean, start):
    depth = 0
    idx = start - 1
    while idx >= 0:
        ch = clean[idx]
        if ch == ")":
            depth += 1
        elif ch == "(":
            if depth == 0:
                return idx
            depth -= 1
        elif ch == ";" and depth == 0:
            return -1
        idx -= 1
    return -1


def line_number_at(line_starts, offset):
    lo = 0
    hi = len(line_starts)
    while lo + 1 < hi:
        mid = (lo + hi) // 2
        if line_starts[mid] <= offset:
            lo = mid
        else:
            hi = mid
    return lo + 1


def iter_dart_files(paths):
    for path in paths:
        if os.path.isfile(path):
            if path.endswith(".dart"):
                yield path
            continue
        for root, _, files in os.walk(path):
            for name in files:
                if name.endswith(".dart"):
                    yield os.path.join(root, name)


violations = []
for path in iter_dart_files(sys.argv[1:]):
    with open(path, "r", encoding="utf-8") as handle:
        text = handle.read()
    clean = mask_comments_and_strings(text)
    line_starts = [0]
    line_starts.extend(match.end() for match in re.finditer(r"\n", text))
    lines = text.splitlines()
    for match in ENQUEUER_RE.finditer(clean):
        if is_default_parameter_context(clean, match.start()):
            continue
        line_no = line_number_at(line_starts, match.start())
        snippet = lines[line_no - 1].strip() if line_no - 1 < len(lines) else ""
        violations.append((path, line_no, snippet))

if violations:
    print(f"[{RULE}] no-arg *SyncEnqueuer() construction is only allowed in DI default parameters.")
    for path, line_no, snippet in violations:
        print(f"{path}:{line_no}: {snippet}")
    sys.exit(1)
PY
)"
  local check_status=$?
  set -e

  case "$check_status" in
    0)
      :
      ;;
    1)
      echo "$output"
      echo "  -> [$label] forbidden pattern matched."
      failures=$((failures + 1))
      ;;
    *)
      echo "$output"
      echo "  -> [$label] sync enqueuer construction check failed with exit code $check_status."
      failures=$((failures + 1))
      ;;
  esac
}

run_no_default_sync_enqueuer_construction_check \
  "Checking lib for no-arg SyncEnqueuer construction outside DI defaults" \
  lib

if [[ "$failures" -ne 0 ]]; then
  echo "Architecture boundary checks failed: $failures violation(s) / error(s)."
  exit 1
fi

echo "Architecture boundary checks passed."
