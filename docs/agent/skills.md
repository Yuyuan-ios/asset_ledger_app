# Agent Skills

本项目使用仓库内 skill 和文档模板来约束多 agent 工作流。

## Project Skill

`.agents/skills/fleet-ledger-orchestrator/SKILL.md` 是本仓库的 prompt 编排
skill。它用于 OpenClaw、MiniMax、ChatGPT、Codex 或其他 agent 读取任务上下文、
生成草稿、审核 prompt、整理报告和规划下一阶段。

在当前用户工作流中：

- OpenClaw / MiniMax 推荐只生成 DRAFT prompt。
- ChatGPT 负责把 DRAFT prompt 审核成 FINAL prompt。
- Codex 负责执行 FINAL prompt。

## Prompt Architect Template

`docs/agent/templates/prompt-architect-skill.md` 是用户级 Prompt Architect skill
模板。它可以在未来复制到：

```text
$HOME/.agents/skills/prompt-architect/SKILL.md
```

本仓库不会自动安装该模板，也不会直接修改 `$HOME/.agents`。

## Telegram Review Commands

- `/status`：查看当前任务和仓库状态。
- `/draft <task>`：让 OpenClaw / MiniMax 生成 draft package。
- `/review`：进入 ChatGPT prompt review。
- `/approve`：允许 Codex 执行审核后的 FINAL prompt。
- `/stop`：停止当前任务。
- `/next`：生成下一阶段建议草稿。

`/approve` 只是用户确认进入 Codex 执行，不代表自动合并、push 或发布。

## Related Docs

- Prompt Review Gateway：`docs/agent/prompt-review-gateway.md`
- Prompt 规范：`docs/agent/prompt-style.md`
- 标准工作流：`docs/agent/workflow.md`
- 任务模板：`docs/agent/templates/`
