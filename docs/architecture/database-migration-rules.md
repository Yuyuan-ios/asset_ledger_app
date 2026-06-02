# Database Migration Rules

数据库 migration 修改必须同时满足安全性、兼容性和可验证性。

## 事务安全

- migration 应在可控事务中执行。
- 多步骤 schema 或数据修复不能留下半完成状态。
- 失败路径应清晰，不应静默跳过关键步骤。

## 外键安全

- 修改表、字段、索引或关联数据时必须考虑外键约束。
- 重建表时要保留关联关系、索引、默认值和必要约束。
- 删除或回填数据前必须明确影响范围。

## 备份恢复兼容

- schema 变化需要考虑备份导出、恢复、旧数据读取和兼容字段。
- 新字段、重命名、删除字段都要检查备份表清单和恢复路径。

## Schema Version

- 每次 schema/migration 行为变化必须同步更新 schema version。
- migration runner、schema 定义和测试中的版本预期应保持一致。
- 拆分 migration 文件时还要遵守 `docs/architecture/db_migrations_split_plan.md`。

## 测试覆盖

- migration 修改必须有针对性测试。
- 测试应覆盖旧版本升级、新版本幂等、关键数据保留和约束安全。
- 涉及备份恢复时补充对应恢复兼容测试。

## 待确认

- migration 回滚策略待确认。
