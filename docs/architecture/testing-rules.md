# Testing Rules

本文件记录 agent 常用验证命令和 fast/full 选择规则。

## 常用命令

```bash
tools/agent/project_status.sh
tools/agent/summarize_diff.sh
tools/agent/check_fast.sh
tools/agent/check_full.sh
```

## Fast 检查

运行：

```bash
tools/agent/check_fast.sh
```

包含：

- `flutter analyze`
- `tools/run_custom_lint_isolated.sh`
- `git diff --check`

适用：

- 文档改动。
- 脚本改动。
- 小范围 UI 文案或展示改动。
- 不涉及数据库、共享业务逻辑、导入导出和统计口径的改动。

## Full 检查

运行：

```bash
tools/agent/check_full.sh
```

包含：

- `flutter analyze`
- `tools/run_custom_lint_isolated.sh`
- `flutter test --no-pub`
- `git diff --check`

适用：

- 数据库 migration。
- repository、service、store、provider 等共享逻辑。
- 导入导出。
- 结清/核销。
- 统计口径。
- 跨模块行为变化。

## 失败处理

- 记录失败命令、退出点和关键错误。
- 判断失败是否由本次改动引入。
- 不掩盖已有失败；报告中标明“疑似既有问题”或“本次引入”。
