# Active Operations

本目录记录当前活跃阶段的任务背景、目标、验收标准和待确认项。

## 当前入口

- 当前阶段事实源：`docs/operations/active/current-stage.md`
- Long-goal automation 协议：`docs/agent/long-goal-automation-protocol.md`
- 日期选择 dry run 样例计划：`docs/operations/active/date-picker-dry-run-plan.md`
- Stage D operation token / audit 入口：`docs/operations/active/stage-d-operation-token-audit.md`
- OpenClaw / MiniMax 生成 DRAFT 前必须先读取 active docs，再读取相关 agent/product/architecture docs。
- Active status must label sources as `repo-verified`, `user-provided`, `needs verification`, or `unknown`.

## 默认读取顺序

1. `docs/operations/active/current-stage.md`
2. `docs/agent/telegram-review-contract.md`
3. `docs/agent/codex-execution-contract.md`
4. `docs/agent/mobile-gui-automation-workflow.md`
5. 如果任务是多阶段长目标，读取 `docs/agent/long-goal-automation-protocol.md`
6. 如果任务是日期选择 dry run，读取 `docs/operations/active/date-picker-dry-run-plan.md`
7. `.agents/skills/fleet-ledger-orchestrator/SKILL.md`
8. 任务相关 `docs/product/`、`docs/architecture/`、`docs/agent/templates/`
9. 只有当任务明确涉及 Stage D / operation token / audit 时，才读取 `docs/operations/active/stage-d-operation-token-audit.md`

执行多阶段任务前必须读取 long-goal docs；不要把长目标直接转成一次性 implementation prompt。

## 维护方式

- 每个活跃阶段使用独立文档。
- 文档应包含目标、范围、限制、验证命令和当前状态。
- 状态变化时更新对应阶段文档，不在多个位置重复维护。
- 阶段完成后移动或复制摘要到 `docs/operations/completed/`。

## 建议字段

- 阶段名称。
- 当前目标。
- 允许修改范围。
- 禁止修改范围。
- 验证要求。
- 待确认项。
- 最近一次结论。
