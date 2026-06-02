# UI 小修任务模板

你现在在机账通 / fleet_ledger_app 项目中执行 UI 小修。

## 目标

调整：`<填写具体界面、组件、文案或交互>`。

## 范围

- 允许修改：`<填写 UI 文件或文案文件>`。
- 参考文档：`docs/product/ui-copywriting.md`。

## 限制

- 不改业务逻辑。
- 不改数据库 schema。
- 不改非目标界面的交互。
- 不引入新依赖。
- 不改测试断言，除非只是同步明确要求的可见文案。

## 验证

```bash
tools/agent/project_status.sh
tools/agent/summarize_diff.sh
tools/agent/check_fast.sh
```

如需视觉确认，补充截图或手动检查结果。

## 最终报告

- 修改文件列表。
- UI 改动点。
- 是否影响业务逻辑。
- 验证命令和结果。
- 遗留问题。
