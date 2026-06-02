# 只读审计任务模板

你现在在机账通 / fleet_ledger_app 项目中执行只读审计。

## 目标

审计：`<填写审计对象，例如分支、commit、文件、功能链路>`。

## 范围

- 只检查：`<填写范围>`。
- 对照文档：`AGENTS.md` 以及相关 `docs/product/`、`docs/architecture/` 文档。

## 限制

- 只读，不修改文件。
- 不格式化、不新增测试、不提交。
- 不扩大到范围外功能。

## 验证

按任务风险运行：

```bash
tools/agent/project_status.sh
tools/agent/summarize_diff.sh
tools/agent/check_fast.sh
```

必要时运行：

```bash
tools/agent/check_full.sh
```

## 最终报告

- P1/P2/P3 问题，按严重程度排序。
- 每个问题给出文件、类或函数证据。
- 待确认项。
- 验证命令和结果。
- 是否建议继续合并或进入实现。
