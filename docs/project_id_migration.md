# ProjectId Migration

## 背景

旧模型把 `ProjectKey = contact + site` 当作项目身份。这个设计在发布前还能承受，但会在项目改名、外协记录、聚合分享、跨设备导入、同名项目并存时放大风险。本轮迁移把项目身份切到稳定 `project_id`，`contact` 和 `site` 降级为项目属性。

## 新模型

- `projects.id` 是项目唯一身份。
- `timing_records.project_id`、`account_payments.project_id`、`project_device_rates.project_id`、`account_project_merge_members.project_id` 是核心关联字段。
- `projects.contact`、`projects.site` 只负责展示和编辑。
- `projects.legacy_project_key` 用于旧数据和旧备份映射。
- `ProjectKey` 保留为 legacy compatibility helper，不再作为新逻辑身份。

## ID 策略

- 新建 ID 使用 `ProjectId.create()` 生成 `project:<128-bit secure random base64url>`，不依赖联系人、地址或本机时间戳作为身份。
- 旧数据迁移使用 deterministic legacy id：`legacy:<base64url(ProjectKey)>`。
- 同一个 legacy key 在迁移、备份恢复、模型 fallback 中会得到同一个 `project_id`。

## 数据迁移

数据库版本升级到 v13。迁移流程：

1. 创建 `projects` 表。
2. 从旧 `timing_records.contact/site`、`account_payments.project_key`、`project_device_rates.project_key`、`account_project_merge_members.project_key` 收集 legacy 项目。
3. 为每个 legacy 项目创建一行 `projects`。
4. 给依赖表补 `project_id`。
5. 重建 `project_device_rates` 主键为 `(project_id, device_id, is_breaking)`。
6. 重建合并成员唯一索引为 `project_id` 口径。

迁移不删除旧 `project_key/contact/site` 字段，因为它们仍用于旧备份、展示兜底和可读快照。

## 行为语义

- 修改项目资料：`projectId` 不变，不解除合并。
- 移动计时记录到另一个项目：`projectId` 改变，才触发自动解除合并。
- `SaveTimingRecordUseCase` 已改为比较 old/new `projectId`。
- 当前 UI 仍以联系人/地址表单为入口，未引入完整项目选择器；无 `project_id` 的输入会通过 legacy fallback 生成稳定 ID。

## 旧备份兼容

旧备份没有 `projects/project_id` 时，restore 会在 normalize 阶段：

- 从 timing/payment/rate/merge member 推导 projects；
- 给 child rows 补 `project_id`；
- 再统一校验和插入。

新备份导出 `projects`，并导出依赖表中的 `project_id`。若新备份出现 orphan `project_id`，restore 会在清空数据库前失败。

## 测试覆盖

- `test/data/models/project_test.dart`
- `test/data/models/project_key_test.dart`
- `test/data/db/db_migrations_test.dart`
- `test/data/services/local_backup_calculation_history_test.dart`
- `test/data/services/account_service_edge_test.dart`
- `test/features/timing/use_cases/save_timing_record_use_case_test.dart`
- `test/features/timing/view/timing_page_calculation_history_test.dart`

## Remaining Debt

- 完整项目选择/改名 UI 尚未建立；当前仍通过计时表单字段输入项目属性。
- `AccountPage` 合并收款流程仍可继续 coordinator 化。
- `TimingPage` 的收入预估和表单 validation 仍有进一步瘦身空间。
- `custom_lint` 与 `integration_test/test_driver/patrol_test` 仍处于技术债状态。
- `ProjectKey` 仍存在于旧备份、旧数据映射、display fallback 中；不得再作为新功能身份来源。
