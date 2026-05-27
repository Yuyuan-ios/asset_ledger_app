# Cleanup 9.5 Plan（9.5 分达标整理计划）

> 版本：v1 — 阶段 0 产物
> 适用项目：`asset_ledger_app`
> 配套规则：[business_rules_v1.md](./business_rules_v1.md)（一切实现以该规则为准）
> 文档地位：本文件是后续每个阶段的执行标准与验收口径。后续阶段对范围、测试、命令的解释以此为准。

---

## 1. 当前目标

**先达到 9.5 分以上工程基线，再继续上新功能。**

本轮整理不是新需求开发，而是把已经存在的发布级风险、数据一致性风险、架构边界混乱、同步与权限地基缺失统一收口；让项目具备：

- 可发布
- 可恢复
- 可同步
- 可审核
- 可解释

最终再回到新功能（驾驶员、合伙人、MCP、Excel）。

---

## 2. 阶段划分

| 阶段 | 主题 |
|------|------|
| 阶段 0 | 规则冻结与基线验收 |
| 阶段 A | P1 发布级风险修复 |
| 阶段 B | 数据一致性与事务化 |
| 阶段 C | 架构边界收敛 |
| 阶段 D | 同步、权限、审计、MCP 地基 |
| 阶段 E | 简单设备工时 Excel 导出 |

每阶段必须独立可验收。下一阶段开始前，前一阶段的"必须新增或强化测试"必须为绿。

---

## 3. 每阶段范围

### 阶段 0：规则冻结与基线验收

范围：

- 固化业务规则（见 [business_rules_v1.md](./business_rules_v1.md)）。
- 固化验收口径（见第 4 章）。
- 不改业务代码。
- 跑基础命令获取当前基线。
- 输出当前风险清单（在审计报告中给出）。

退出条件：

- `business_rules_v1.md` 已落盘。
- `cleanup_9_5_plan.md` 已落盘。
- 基线验证命令已跑过一次并被记录（即使存在历史问题也允许进入阶段 A，但必须明确登记为待修项）。

---

### 阶段 A：P1 发布级风险修复

范围：

1. 备份 / 恢复加入 `external_import_batches` 和 `external_work_records`。
2. 恢复外协缺失 `linked_project_id` 时，**保留外协但解除关联并记录 warning**（对齐规则 §2）。
3. 修复 `legacy_project_key` 全局唯一冲突。
4. 保证同 `legacy_project_key` 下只允许一个 active 项目，但允许多个 settled 历史项目（对齐规则 §1）。
5. 修复 `tools/check_architecture.sh` 假阴性（脚本检测到问题但 exit code 仍为 0）。
6. 补真实 DB 回归测试。

必须新增或强化测试：

- `backup_restore_external_work_test`
- `project_resolver_sqflite_test`
- architecture script failure behavior（脚本检测到问题必须以非 0 退出码退出）

退出条件：

- 上述测试全部为绿。
- `tools/check_architecture.sh` 在人为制造违规时能以非 0 退出。
- 备份恢复对 `external_*` 表完整覆盖。

---

### 阶段 B：数据一致性与事务化

范围：

1. 金额汇总统一 `SUM(amount_fen)`，不再使用 `SUM(amount)` REAL 作为权威口径（对齐规则 §3）。
2. `SaveTimingRecord` 与解除合并同事务（对齐规则 §6）。
3. 修改计时导致项目变化时自动解除合并。
4. 合并解除后必要时自动撤销结清（对齐规则 §7）。
5. 复用或抽取 settlement impact 逻辑（删除计时影响结清 与 合并解除影响结清 共用一套）。

必须新增或强化测试：

- `settlement_money_fen_repository_test`
- `save_timing_record_with_impact_test`
- `project_settlement_impact_service_test`

退出条件：

- 所有"是否结清 / 是否核销 / 未收"判断不再读 REAL `amount`。
- 修改计时不会留下"已保存但未解除合并"的中间态。
- 撤销结清流程有显式 UI 提示通道（实现可放阶段 C，但事务逻辑本阶段必须就位）。

---

### 阶段 C：架构边界收敛

范围：

1. `patterns` 层**不得**直接依赖 `data` / `infrastructure` / `repository` / `service`。
2. `patterns` 只接收 ViewModel 和 callback。
3. 抽 `ProjectIdentityService`（封装规则 §1 的"同 key 仅一个 active"判断）。
4. 抽 `ExternalWorkPackageService`（封装外协批次 / 关联策略）。
5. 大 Widget 只按风险拆，不做无意义行数重构（不为了拆而拆）。

必须新增或强化测试：

- `project_identity_service_test`
- `external_work_package_service_test`
- patterns dependency lint（自定义 lint 或 `check_architecture.sh` 中加入规则）

退出条件：

- `tools/check_architecture.sh` 能识别 patterns → data/infrastructure 的违规并以非 0 退出。
- 两个新服务有独立测试覆盖关键分支。

---

### 阶段 D：同步、权限、审计、MCP 地基

范围：

1. 核心业务表逐步补齐同步元数据：`created_at` / `updated_at` / `deleted_at` / `owner_id` / `actor_id` / `version`（对齐规则 §12）。
2. 核心写操作进入 command/coordinator 层（统一写入入口，便于 audit 与 outbox 注入）。
3. outbox 状态机具备：`pending` / `processing` / `synced` / `failed`。
4. 驾驶员审核状态机：`draft` / `submitted` / `approved` / `rejected`（对齐规则 §8）。
5. 合伙人分享设备只读权限（对齐规则 §9）。
6. MCP / AI 写操作必须 `preview + confirm + audit`（对齐规则 §11）。

必须新增或强化测试：

- `sync_outbox_state_machine_test`
- `driver_review_permission_test`
- `partner_device_visibility_policy_test`
- `operation_preview_confirm_test`

退出条件：

- outbox 状态机有覆盖正常流与失败流的测试。
- 驾驶员 / 合伙人权限策略有显式策略对象（而非散落于 UI 判断）。
- MCP 写操作没有不经 `preview` 的捷径。

---

### 阶段 E：简单设备工时 Excel 导出

范围：

1. 只导出设备工时表（列见规则 §10）。
2. 不导出财务。
3. 不导出利润。
4. 不导出复杂项目总账。
5. 数据与计时列表同源（同一个 ViewModel / 同一个查询，避免双口径）。

必须新增或强化测试：

- `device_work_hours_export_test`

退出条件：

- 导出文件列与规则 §10 完全一致。
- 复杂 `ProjectFinanceReportViewModel` 不在导出路径上被引用。

---

## 4. 每阶段固定验收命令

每个阶段（包括阶段 0）完成后必须依次运行：

```bash
flutter analyze
bash tools/run_custom_lint_isolated.sh
bash tools/check_architecture.sh
flutter test --no-pub
```

如果当阶段涉及数据库迁移，额外必须运行：

- 空库创建测试（migrate from scratch）
- 旧库升级测试（migrate upgrade path）
- 备份恢复测试（含 external_work_records）
- 真实 sqflite repository 测试（非 in-memory）

约束：

1. 不要为了让测试通过去改业务代码以外的内容。
2. 不要静默跳过失败测试。
3. 如果 `check_architecture.sh` 打印风险但 exit code 仍为 0（假阴性），登记为阶段 A 待修项，不在当前阶段强行修。
4. 即使 `flutter test` 时间较长，仍要执行完整套件。

---

## 5. 9.5 分达标标准

只有满足下列**全部**条件，才视为达到 9.5 分基线，可继续上新功能：

1. P1 全部清零。
2. 备份恢复覆盖所有业务表（包括 `external_import_batches` / `external_work_records`）。
3. 外协恢复符合"保留外协、解除缺失关联"的规则（规则 §2）。
4. 项目身份规则有真实 DB 测试（规则 §1）。
5. 金额汇总全部走 fen（规则 §3）。
6. 修改计时 + 解除合并 + 撤销结清同事务（规则 §6、§7）。
7. 架构 lint 不再假阴性。
8. `patterns` 不直接依赖 `data` / `infrastructure`。
9. 核心写操作逐步进入 command/coordinator。
10. 核心表具备同步需要的 `updated_at` / `deleted_at` / `version` 地基（规则 §12）。
11. outbox 有状态机。
12. 驾驶员审核状态机有测试（规则 §8）。
13. 合伙人共享权限有测试（规则 §9）。
14. MCP 写操作必须 `preview + confirm`（规则 §11）。
15. Excel 只导出设备工时表，不混入财务（规则 §10）。

---

## 变更记录

| 版本 | 日期 | 变更 |
|------|------|------|
| v1 | 2026-05-26 | 阶段 0 初始版：阶段划分、范围、验收命令、9.5 标准首次成文。 |
