#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

has_failures=0

echo "Checking data/state imports..."
if rg -n \
  --glob '*.dart' \
  "^import .*components/|^import .*patterns/|^import .*features/.*/view/" \
  lib/data \
  lib/features/*/state
then
  echo "Found forbidden UI imports in data/state layers."
  has_failures=1
fi

echo "Checking reusable UI store access..."
if rg -n \
  --glob '*.dart' \
  "context\\.(watch|read)" \
  lib/components \
  lib/patterns
then
  echo "Found direct store reads inside components/patterns."
  has_failures=1
fi

echo "Checking UI-layer fontFamily usage..."
if rg -n \
  --glob '*.dart' \
  "fontFamily\\s*:" \
  lib/features \
  lib/components \
  lib/patterns
then
  echo "Found direct fontFamily usage in UI layers."
  has_failures=1
fi

echo "Checking migrated modules for direct TextStyle usage..."
if rg -n \
  --glob '*.dart' \
  --glob '!lib/patterns/account/account_overview_card_pattern.dart' \
  "TextStyle\\s*\\(" \
  lib/features/account \
  lib/features/fuel \
  lib/features/maintenance \
  lib/features/timing \
  lib/components/feedback \
  lib/components/buttons \
  lib/components/fields \
  lib/components/list \
  lib/components/avatars \
  lib/components/pickers \
  lib/patterns/account \
  lib/patterns/fuel \
  lib/patterns/maintenance \
  lib/patterns/timing \
  lib/patterns/device
then
  echo "Found direct TextStyle usage in migrated modules."
  has_failures=1
fi

if [[ "$has_failures" -ne 0 ]]; then
  exit 1
fi

echo "Architecture boundary checks passed."
