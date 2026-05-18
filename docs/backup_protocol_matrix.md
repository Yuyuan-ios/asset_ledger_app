# Backup Export / Restore Protocol Matrix

本文件描述当前备份协议。`database schemaVersion` 是本地数据库结构版本，`export_format_version` 是备份协议版本，`app_version` 是应用版本信息，三者不能混用。

当前新导出协议版本：`export_format_version = 2`。

| 数据对象 / 表名 | export 是否写出 | restore 是否读取 | 是否依赖 project_id | 旧备份缺失默认值 | 非法值处理 | 是否允许旧备份缺表 | 已有测试文件 | 风险等级 | 后续动作 |
|---|---:|---:|---:|---|---|---:|---|---|---|
| `projects` | 是 | 是 | 身份来源 | 旧备份缺表时从 child rows 推导 | `id/contact/site/created_at/updated_at` 类型错误失败 | 是 | `test/data/db/db_migrations_test.dart`, `test/data/services/local_backup_calculation_history_test.dart` | 中 | 后续项目选择 UI 建立后继续补端到端测试 |
| `devices` | 是 | 是 | 否 | `equipment_type = excavator` | `is_active` 仅允许 `0/1` | 否 | `test/data/services/local_backup_calculation_history_test.dart` | 低 | 保持 |
| `timing_records` | 是 | 是 | 是 | 旧备份补 `contact/site = ''`，补 `project_id` | `type` 非法失败；`is_breaking` 仅允许 `0/1`；orphan `project_id` 失败 | 否 | `test/data/services/local_backup_calculation_history_test.dart`, `test/features/timing/use_cases/save_timing_record_use_case_test.dart` | 高 | 项目选择 UI 后补移动项目 widget 测试 |
| `fuel_logs` | 是 | 是 | 否 | 无 | 类型错误失败 | 否 | 既有 backup round-trip 覆盖 | 低 | 保持 |
| `maintenance_records` | 是 | 是 | 否 | 无 | 类型错误失败 | 否 | 既有 backup round-trip 覆盖 | 低 | 保持 |
| `account_payments` | 是 | 是 | 是 | 旧备份补 merge batch 字段和 `source_type = manual`，补 `project_id` | `source_type` 仅允许 `manual/merge_allocation`；orphan `project_id` 失败 | 否 | `test/data/services/local_backup_calculation_history_test.dart`, `test/features/account/use_cases/*` | 高 | 合并收款 coordinator 化后补更细 repository 测试 |
| `project_device_rates` | 是 | 是 | 是 | `is_breaking = 0`，补 `project_id` | `is_breaking` 仅允许 `0/1`；orphan `project_id` 失败 | 否 | `test/data/db/db_migrations_test.dart`, `test/data/services/local_backup_calculation_history_test.dart` | 高 | 项目改名 UI 后补费率不丢失测试 |
| `timing_calculation_history` | 是 | 是 | 间接依赖 timing record | 旧备份允许缺表，按空表处理 | orphan `timing_record_id` 由事务回滚 | 是 | `test/features/timing/calculator/repository/timing_calculation_history_repository_test.dart` | 中 | 保持 |
| `account_project_merge_groups` | 是 | 是 | 否 | 旧备份允许缺表，按空表处理 | `source_type` 仅允许 `local`；`is_active` 仅允许 `0/1` | 是 | `test/data/services/local_backup_calculation_history_test.dart`, `test/data/services/account_project_merge_service_test.dart` | 中 | 若未来有远端/分享来源，再扩展 source_type 矩阵 |
| `account_project_merge_members` | 是 | 是 | 是 | 旧备份允许缺表；存在时补 `project_id` | `is_active` 仅允许 `0/1`；orphan `project_id` 失败 | 是 | `test/data/db/db_migrations_test.dart`, `test/data/services/local_backup_calculation_history_test.dart` | 高 | 未来项目移动/合并 UI 后补端到端测试 |

## Restore 安全边界

- restore 会先 validate/normalize，再自动备份，再在事务中清空和插入。
- validate 阶段失败不会清空现有数据库。
- 事务插入失败会回滚，现有数据库保持恢复前状态。
- 新备份以 `projects` 为项目身份来源。
- 旧备份没有 `projects` 时，用 `ProjectKey` 兼容解析创建 legacy projects。
- `ProjectKey` 只是 legacy compatibility，不是新身份。
