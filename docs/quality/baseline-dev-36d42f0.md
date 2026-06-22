# FleetLedger dev@36d42f0 基线证据

> 记录时间：2026-06-22
> 配套路线图：`docs/quality/execution-roadmap-dev-36d42f0.md`

## 基线

- 代码基线：`dev@36d42f0`
- 计划文档提交：`542e701 docs(quality): add P0 roadmap & codex prompts`
- 起始工作区：干净
- 复核评分：6.5/10
- 结论：适合作为稳定开发基线，不适合宣称完整商业化生产闭环。

## 本地门禁

- `bash tools/agent/check_fast.sh`：通过
- `bash tools/check_architecture.sh`：通过
- `bash tools/agent/check_full.sh`：通过
- Flutter 测试：`+2272 ~3 skipped`

## 后端单测

- `server/cloud_sync_backend`：21 个 unittest 通过
- `server/cloud_backup_backend`：30 个 unittest 通过

## 远端门禁现状

`.github/workflows/flutter.yml` 与本地门禁脱节：

- 仅触发 `main` / `master`，未覆盖 `dev`。
- 仅运行 Flutter analyze 与单个 IAP define 测试。
- `custom_lint`、`tools/check_architecture.sh`、全量 `flutter test` 仍被注释。
- 两套后端 unittest 未接入 CI。

## 阻断生产声明的能力

### Live Sync

- 当前存在 hard-gate：`real-cloud-transport-not-configured`。
- delete-meta 与 terminal-failed 收口仍处于 deferred 状态。
- 结论：不能宣称实时云同步生产可用。

### Driver Entry

- 当前为领域骨架。
- 尚无 concrete 实现、无数据库表、无 deep link 闭环。
- 结论：不能宣称司机填报入口已形成生产闭环。

### Native Update

- 当前 `inAppUpdateLauncher: null`。
- 实际能力仍为 URL fallback。
- 结论：不能宣称 native 应用内更新能力已经上线。

### IAP 服务端校验

- 当前为配置门控。
- 未完成 sandbox smoke。
- 已 fail-closed。
- 结论：不能宣称订阅/IAP 生产闭环已完成。

## 使用边界

本文件是 Phase 0 后续 CI 恢复 PR 的共同基线证据。后续报告可引用本文件说明当前质量状态，
但不得把本地门禁全绿、测试全绿或 fail-closed 配置门控表述为完整商业化生产能力。
