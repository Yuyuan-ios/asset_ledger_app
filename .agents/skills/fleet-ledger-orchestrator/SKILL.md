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

The current workflow goal is mobile GUI automation: OpenClaw uses GUI
automation on the home MacBook to connect ChatGPT, Telegram review, and Codex
without bypassing approval gates.

## Required Context

Always start with:

- `AGENTS.md`
- `docs/agent/index.md`
- `docs/operations/active/current-stage.md`
- `docs/agent/prompt-review-gateway.md`
- `docs/agent/telegram-review-contract.md`
- `docs/agent/codex-execution-contract.md`
- `docs/agent/openclaw-minimax-orchestration.md`
- `docs/agent/mobile-gui-automation-workflow.md`
- `docs/agent/long-goal-automation-protocol.md`
- The relevant product or architecture docs listed in `AGENTS.md`

Do not rely on chat memory alone when drafting or executing a task.

## Default Baseline

- Default repository: `/Users/yu/Flutter_Projects/fleet_ledger_app`
- Default branch: `dev`
- Do not generate prompts pointing to the old audit worktree unless the user
  explicitly asks for that worktree.
- If a non-default path is explicitly requested, verify path, branch, HEAD, and
  git status before drafting or execution.

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
- Generates `DRAFT_STAGE_PLAN` first when the user asks for a broad feature or
  long goal.
- Organizes Codex execution reports.
- Suggests next-stage draft plans.
- Uses GUI automation to send DRAFT to ChatGPT, return FINAL to Telegram, and
  hand FINAL to Codex only after user approval.
- Outputs must be concise enough for Telegram review.
- Must not directly write business code.
- Must not pass an unreviewed prompt directly to Codex.
- Must only emit `DRAFT_PROMPT_PACKAGE`, never `FINAL_CODEX_PROMPT`.
- Must never emit `FINAL_STAGE_PLAN`; ChatGPT owns that final plan.
- Must clearly distinguish DRAFT from FINAL.

### ChatGPT Prompt Reviewer

- Reviews the draft prompt.
- Narrows task scope.
- Corrects product-rule and architecture-boundary mistakes.
- Strengthens validation commands and final report requirements.
- Outputs `FINAL_CODEX_PROMPT` only when the prompt is safe enough to execute.
- Outputs `FINAL_STAGE_PLAN` for long goals before any implementation stage.

### Codex Executor

- Executes the ChatGPT-reviewed `FINAL_CODEX_PROMPT`.
- Executes one approved stage at a time.
- Modifies code or docs within the approved scope.
- Runs verification commands.
- Produces an execution report.
- Does not automatically push.
- Follows `docs/agent/codex-execution-contract.md`.

## Standard Flow

1. The user starts a Telegram task, for example `/draft D58`.
2. OpenClaw / MiniMax reads `AGENTS.md` and relevant docs.
3. OpenClaw / MiniMax generates a `DRAFT_PROMPT_PACKAGE`.
4. OpenClaw sends the package to ChatGPT through GUI automation.
5. ChatGPT outputs a `FINAL_CODEX_PROMPT`.
6. OpenClaw returns the FINAL to Telegram for user review.
7. The user approves execution in Telegram.
8. OpenClaw gives the approved FINAL to Codex.
9. Codex executes the final prompt.
10. OpenClaw / MiniMax organizes the Codex report for Telegram.
11. ChatGPT or the user reviews whether to continue to the next stage.

## Long-Goal Routing

If the user asks to "make a feature", "build a flow", or gives another broad
long goal, do not generate an implementation prompt first.

1. OpenClaw / MiniMax generates `DRAFT_STAGE_PLAN`.
2. ChatGPT reviews and outputs `FINAL_STAGE_PLAN`.
3. Telegram reviewer approves the plan.
4. Each stage separately follows DRAFT -> ChatGPT FINAL -> Telegram approve ->
   Codex execute.
5. Passing tests does not automatically execute the next stage.

## References

- Prompt review gateway: `references/chatgpt-review-gateway.md`
- Prompt writing rules: `references/prompt-rules.md`
- Codex report checklist: `references/report-checklist.md`
- Task types and templates: `references/task-types.md`
- Telegram review semantics: `docs/agent/telegram-review-contract.md`
- Codex execution boundary: `docs/agent/codex-execution-contract.md`
- Mobile GUI automation workflow: `docs/agent/mobile-gui-automation-workflow.md`
- Long-goal automation protocol: `docs/agent/long-goal-automation-protocol.md`

## Prohibited

- Do not directly write business code from this skill.
- Do not skip `AGENTS.md`.
- Do not invent product rules.
- Do not automatically approve a task.
- Do not send a large, multi-stage task to Codex as one prompt.
- Do not inject branch rules unless the user task explicitly requires them.
- Do not let OpenClaw / MiniMax bypass ChatGPT and call Codex directly.
- Do not interpret Telegram `/approve` as permission to push or merge.
- Do not treat Telegram `/approve` as release or publish permission.
- Do not let GUI automation bypass Telegram approval gates.
- Do not treat `/next` as permission to execute the next stage.
- Do not turn a long goal directly into an implementation prompt.
- Do not execute more than one long-goal stage in one Codex run.
