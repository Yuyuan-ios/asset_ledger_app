---
name: fleet-ledger-orchestrator
description: Prompt orchestration skill for fleet_ledger_app. Use when OpenClaw, MiniMax, ChatGPT, Codex, or another agent drafts, reviews, routes, or summarizes Fleet Ledger coding-agent tasks, especially tasks that must pass through ChatGPT prompt review before Codex execution.
---

# Fleet Ledger Orchestrator

This is the prompt orchestration skill for the Fleet Ledger / 机账通
`fleet_ledger_app` repository. It can be read by OpenClaw, MiniMax, ChatGPT,
Codex, or another agent, but the current user workflow has a strict gateway:
OpenClaw / MiniMax may only generate DRAFT prompts. A FINAL prompt must be
reviewed and revised by ChatGPT before it is handed to Codex.

## Required Context

Always start with:

- `AGENTS.md`
- `docs/agent/index.md`
- `docs/agent/prompt-review-gateway.md`
- The relevant product or architecture docs listed in `AGENTS.md`

Do not rely on chat memory alone when drafting or executing a task.

## Roles

### Human / Telegram Reviewer

- Judges direction and risk.
- Uses commands such as `approve`, `stop`, `revise`, or `next`.
- Does not need to hand-write every detailed prompt.
- A Telegram `/approve` means the user allows the next Codex execution step; it
  does not mean push, merge, or release.

### OpenClaw / MiniMax Orchestrator

- Reads context and relevant docs.
- Generates prompt drafts and task summaries.
- Organizes Codex execution reports.
- Suggests next-stage draft plans.
- Must not directly write business code.
- Must not pass an unreviewed prompt directly to Codex.
- Must only emit `DRAFT_PROMPT_PACKAGE`, never `FINAL_CODEX_PROMPT`.

### ChatGPT Prompt Reviewer

- Reviews the draft prompt.
- Narrows task scope.
- Corrects product-rule and architecture-boundary mistakes.
- Strengthens validation commands and final report requirements.
- Outputs `FINAL_CODEX_PROMPT` only when the prompt is safe enough to execute.

### Codex Executor

- Executes the ChatGPT-reviewed `FINAL_CODEX_PROMPT`.
- Modifies code or docs within the approved scope.
- Runs verification commands.
- Produces an execution report.
- Does not automatically push.

## Standard Flow

1. The user starts a Telegram task, for example `/draft D58`.
2. OpenClaw / MiniMax reads `AGENTS.md` and relevant docs.
3. OpenClaw / MiniMax generates a `DRAFT_PROMPT_PACKAGE`.
4. The user or automation sends the package to ChatGPT.
5. ChatGPT outputs a `FINAL_CODEX_PROMPT`.
6. The user approves execution in Telegram.
7. Codex executes the final prompt.
8. OpenClaw / MiniMax organizes the Codex report.
9. ChatGPT or the user reviews whether to continue to the next stage.

## References

- Prompt review gateway: `references/chatgpt-review-gateway.md`
- Prompt writing rules: `references/prompt-rules.md`
- Codex report checklist: `references/report-checklist.md`
- Task types and templates: `references/task-types.md`

## Prohibited

- Do not directly write business code from this skill.
- Do not skip `AGENTS.md`.
- Do not invent product rules.
- Do not automatically approve a task.
- Do not send a large, multi-stage task to Codex as one prompt.
- Do not inject branch rules unless the user task explicitly requires them.
- Do not let OpenClaw / MiniMax bypass ChatGPT and call Codex directly.
- Do not interpret Telegram `/approve` as permission to push or merge.
