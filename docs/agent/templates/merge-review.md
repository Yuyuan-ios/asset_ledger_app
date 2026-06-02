# 分支合并审计模板

你现在在机账通 / fleet_ledger_app 项目中执行分支合并前只读审计。

## 目标

审计待合并分支：`<branch>`。

## 范围

- 对比目标分支：`<target branch>`。
- 检查待合并分支的 commit、diff、测试和产品规则符合性。

## 限制

- 只读，不修改、不格式化、不提交、不合并。
- 不删除分支或 worktree。
- 不把范围外历史问题计入本次阻断，除非会被本次合并放大。

## 建议前置检查

```bash
tools/agent/project_status.sh
git log --oneline --decorate --max-count=20
git diff --stat <target branch>...<branch>
git diff --name-only <target branch>...<branch>
```

## 验证

```bash
tools/agent/check_fast.sh
```

必要时：

```bash
tools/agent/check_full.sh
```

## 最终报告

- 必须修复项。
- 可后续处理项。
- 文件、类或函数证据。
- 验证命令和结果。
- 明确给出 go/no-go 或 keep/merge 建议。
