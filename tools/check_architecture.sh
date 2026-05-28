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

if [[ "$failures" -ne 0 ]]; then
  echo "Architecture boundary checks failed: $failures violation(s) / error(s)."
  exit 1
fi

echo "Architecture boundary checks passed."
