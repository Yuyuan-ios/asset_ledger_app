#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "[1/4] 结构重复检查"
echo "- _buildDevicePickerItems 定义数量:"
rg -n "List<DevicePickerItemVm> _buildDevicePickerItems\\(" lib || true
echo "- 空态文案分散点:"
rg -n "暂无记录|点击右上角 \\+ 新建" lib || true

echo "[2/4] 代码格式化"
changed_dart_files="$(git diff --name-only --diff-filter=ACMRT -- '*.dart')"
if [[ -n "$changed_dart_files" ]]; then
  # 只格式化当前变更文件，避免一次性改动全仓库。
  echo "$changed_dart_files" | xargs dart format >/dev/null
else
  echo "无待格式化的 Dart 变更文件"
fi

echo "[3/4] 静态检查"
flutter analyze

echo "[4/4] 变更摘要"
git status --short
