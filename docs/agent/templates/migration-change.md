# DB Migration 修改模板

你现在在机账通 / fleet_ledger_app 项目中执行数据库 migration 修改。

## 目标

修改 migration：`<填写 schema、表、字段或版本目标>`。

## 必读文档

- `docs/architecture/database-migration-rules.md`
- `docs/architecture/testing-rules.md`
- 相关产品规则文档。

## 限制

- migration 必须事务安全、外键安全、备份恢复兼容。
- 必须同步 schema version。
- 必须补充或更新 migration 测试。
- 不改 UI，除非任务明确要求。
- 不执行 `git add .`，不 push，未明确要求时不 commit。

## 验证

```bash
tools/agent/project_status.sh
tools/agent/summarize_diff.sh
tools/agent/check_full.sh
```

## 最终报告

- 修改文件列表。
- schema version 变化。
- migration 安全性说明。
- 备份恢复兼容性说明。
- 测试和验证结果。
- 遗留问题或待确认项。
