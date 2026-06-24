# OpenClaw / MiniMax Orchestration

## 1. Purpose

This document centralizes the OpenClaw / MiniMax side of the repository
workflow. It defines how draft prompts are created before ChatGPT review and
Codex execution.

The current bridge between systems is GUI automation: OpenClaw moves DRAFT
content to ChatGPT, returns ChatGPT FINAL output to Telegram, and gives FINAL
to Codex only after the user approves it.

## 2. Default Baseline

OpenClaw / MiniMax must assume this default baseline unless the user explicitly
provides another one:

- Repository: `/Users/yu/Flutter_Projects/fleet_ledger_app`
- Branch: `develop`

The old audit worktree is not the default execution path. Do not generate
prompts pointing to `/Users/yu/Flutter_Projects/worktrees/fleet_ledger_audit`
unless the user explicitly asks to use that worktree.

## 3. Role Boundary

- OpenClaw is the orchestrator.
- OpenClaw maintains long-goal state when a user asks for a multi-stage goal.
- MiniMax is the draft-generation brain behind OpenClaw.
- OpenClaw / MiniMax outputs only `DRAFT_PROMPT_PACKAGE`.
- MiniMax may output `DRAFT_STAGE_PLAN`.
- MiniMax must not output `FINAL_STAGE_PLAN`.
- ChatGPT outputs `FINAL_STAGE_PLAN`.
- DRAFT must be sent to ChatGPT review.
- OpenClaw sends MiniMax DRAFT output to ChatGPT through GUI automation.
- OpenClaw sends ChatGPT FINAL output back to Telegram for review.
- OpenClaw may hand FINAL to Codex only after the user approves it.
- OpenClaw / MiniMax must not directly call Codex for execution.
- OpenClaw / MiniMax must not directly write code.
- OpenClaw / MiniMax must not approve its own draft.
- OpenClaw must not call Codex before Telegram approval.
- OpenClaw must not treat ChatGPT intermediate discussion as FINAL.
- OpenClaw must identify `FINAL_CODEX_PROMPT` or an equivalent explicit final
  marker before presenting execution approval.
- Every stage must pass through DRAFT -> ChatGPT FINAL -> Telegram approve ->
  Codex execute.
- OpenClaw must not execute the next stage just because the previous stage
  passed validation.

## 4. Required DRAFT Fields

Every DRAFT must include:

- Source request.
- Relevant docs read.
- Assumptions.
- Risks.
- Draft Codex prompt.
- Questions for ChatGPT reviewer.
- Current baseline:
  - Repository.
  - Branch.
  - HEAD.
  - Git status.

## 5. Required Reads

Before drafting, read:

- `AGENTS.md`
- `docs/operations/active/current-stage.md`
- `docs/agent/telegram-review-contract.md`
- `docs/agent/codex-execution-contract.md`
- `docs/agent/mobile-gui-automation-workflow.md`
- `docs/agent/long-goal-automation-protocol.md`
- `docs/agent/prompt-review-gateway.md`
- `.agents/skills/fleet-ledger-orchestrator/SKILL.md`
- Relevant task templates and product/architecture docs.

## 6. Output Boundary

OpenClaw / MiniMax may produce:

- DRAFT prompt packages.
- DRAFT stage plans.
- Task summaries.
- Codex report summaries.
- Next-stage suggestions.
- Telegram review card summaries.

OpenClaw / MiniMax must not produce:

- `FINAL_CODEX_PROMPT`.
- Code changes.
- Git commits.
- Push, merge, or release actions.
- GUI actions that bypass Telegram approval gates.
