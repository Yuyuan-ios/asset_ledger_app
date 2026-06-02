# Prompt Review Gateway

Prompt Review Gateway 是本项目的 prompt 安全边界。OpenClaw / MiniMax 负责
编排和草拟，ChatGPT 负责最终 prompt 审核，Codex 只执行审核后的最终 prompt。

## 真实工作流

```text
Telegram 用户请求
-> OpenClaw / MiniMax 生成 DRAFT_PROMPT_PACKAGE
-> ChatGPT 审核优化
-> 用户 approve
-> Codex 执行 FINAL_CODEX_PROMPT
-> OpenClaw / MiniMax 整理执行报告
-> ChatGPT / 用户复审
-> 进入下一阶段或停止
```

## 角色边界

### OpenClaw / MiniMax

- 读取 `AGENTS.md` 和相关 docs。
- 生成 `DRAFT_PROMPT_PACKAGE`。
- 整理 Codex 执行报告。
- 生成下一阶段建议草稿。
- 不直接写代码。
- 不把未经过 ChatGPT 审核的 prompt 交给 Codex。

### ChatGPT

- 是最终 prompt reviewer。
- 审核并修正 OpenClaw / MiniMax 的草稿。
- 收敛范围、补足验证、纠正产品规则误读。
- 输出 `FINAL_CODEX_PROMPT` 或退回重写。

### Codex

- 是 executor。
- 只执行 ChatGPT 审核后的 `FINAL_CODEX_PROMPT`。
- 修改代码或文档、运行验证、输出报告。
- 不自动 push。

### Telegram Reviewer

- 通过 `/approve`、`/stop`、`/revise`、`/next` 判断方向。
- `/approve` 只代表允许 Codex 执行，不代表允许 push、merge 或发布。

## 高风险任务

以下任务必须先 draft，再 review，不能直接执行：

- 数据库 schema / migration。
- 统计口径。
- 外协的项目导入导出。
- 结清 / 核销。
- 项目身份与项目归属。
- 大范围 UI 文案或业务流程变更。
- 分支合并审计。

## Draft Package

OpenClaw / MiniMax 应输出 `DRAFT_PROMPT_PACKAGE`，格式见
`.agents/skills/fleet-ledger-orchestrator/references/chatgpt-review-gateway.md`。

## Final Prompt

ChatGPT 审核通过后输出 `FINAL_CODEX_PROMPT`。Codex 执行前应能直接复制该 prompt，
不需要再猜上下文、范围、禁止修改项或验证命令。
