# 实现任务模板

你现在在机账通 / fleet_ledger_app 项目中执行实现任务。

## 目标

实现：`<填写具体目标>`。

## 范围

- 允许修改：`<填写文件、目录或模块>`。
- 需要参考：`AGENTS.md` 以及相关产品、架构、测试文档。

## 限制

- 不修改范围外业务逻辑。
- 不修改 UI、数据库 schema、测试断言，除非目标明确要求。
- 不引入新依赖。
- 不执行 `git add .`，不 push。
- 未明确要求时不 commit。

## 验证

至少运行：

```bash
tools/agent/project_status.sh
tools/agent/summarize_diff.sh
tools/agent/check_fast.sh
```

涉及共享逻辑、数据库、导入导出或统计口径时运行：

```bash
tools/agent/check_full.sh
```

## 最终报告

- 新增/修改文件列表。
- 核心实现说明。
- 实际运行的验证命令和结果。
- 是否修改业务代码。
- 遗留问题。
- 是否已 commit。
