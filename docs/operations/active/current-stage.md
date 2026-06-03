# Current Active Stage

## 1. Purpose

This document is the current active-stage entry point for repository agents. It
should be read before OpenClaw / MiniMax drafts work, before ChatGPT reviews a
draft, and before Codex executes a final prompt.

It prevents agents from relying on chat history, fuzzy memory, or stale
worktree assumptions.

## 2. Status Source Labels

- `repo-verified`: Confirmed by current repository files or git commands.
- `user-provided`: Provided by the user as latest stage notes, but not directly
  verified from the current repository in this task.
- `needs verification`: Must be checked before generating an implementation
  prompt.
- `unknown`: Not known from current docs, git state, or user-provided notes.

Do not present `user-provided` status as `repo-verified`.

## 3. Current Default Baseline

- Active repository: `/Users/yu/Flutter_Projects/fleet_ledger_app`
- Active branch: `dev`
- Default execution baseline: `dev`
- Current actual HEAD must be verified by git before every task.
- Latest known audited HEAD:
  `90f186a feat(account): calculate account summaries with fen precision`.

If execution-time git state differs from this document, use actual command
output and write `verified current state differs` in the report. Do not reset,
checkout, or repair state unless the user explicitly asks.

## 4. Current Orchestration Goal

- OpenClaw backend brain: MiniMax.
- MiniMax / OpenClaw only drafts and orchestrates.
- ChatGPT reviews, corrects, narrows, and finalizes prompts.
- Codex performs programming execution.
- The user reviews in Telegram and chooses review / approve / stop / next.

## 5. Audit Worktree Policy

- `/Users/yu/Flutter_Projects/worktrees/fleet_ledger_audit` is no longer the
  default execution baseline.
- The old audit worktree is historical reference or an explicitly requested
  target only.
- OpenClaw / MiniMax must not default to generating prompts that point to the
  audit worktree.
- Codex must not default to switching to the audit worktree.
- If the user explicitly reintroduces the audit worktree, first verify path,
  branch, HEAD, and git status.

## 6. Current Active Workflow

The immediate next workflow is dev-only orchestration contract hardening and a
real `/draft` end-to-end dry run.

The next default task is not D61/D63 audit-worktree status alignment. Stage D
documents are task-specific references only when the user explicitly asks about
Stage D / operation token / operation audit work.

Before the real `/draft` dry run, these contracts must be clear:

- `docs/agent/telegram-review-contract.md`
- `docs/agent/codex-execution-contract.md`
- `docs/agent/openclaw-minimax-orchestration.md`

## 7. Required Docs Before Drafting Prompts

OpenClaw / MiniMax must read these before generating a DRAFT:

- `AGENTS.md`
- `docs/operations/active/current-stage.md`
- `docs/agent/telegram-review-contract.md`
- `docs/agent/codex-execution-contract.md`
- `docs/agent/openclaw-minimax-orchestration.md`
- `.agents/skills/fleet-ledger-orchestrator/SKILL.md`
- `.agents/skills/fleet-ledger-orchestrator/references/chatgpt-review-gateway.md`
- `.agents/skills/fleet-ledger-orchestrator/references/prompt-rules.md`
- `.agents/skills/fleet-ledger-orchestrator/references/task-types.md`
- `.agents/skills/fleet-ledger-orchestrator/references/report-checklist.md`
- Task-specific product, architecture, operation, or template docs.

Read `docs/operations/active/stage-d-operation-token-audit.md` only when the
task explicitly targets Stage D, operation token, operation audit, or the
preview-confirm workflow.

## 8. Default Workflow

1. OpenClaw / MiniMax generates `DRAFT_PROMPT_PACKAGE`.
2. ChatGPT reviews the DRAFT and outputs `FINAL_CODEX_PROMPT`.
3. User approves through Telegram.
4. Codex executes FINAL only.
5. OpenClaw / MiniMax summarizes the Codex report.
6. ChatGPT or the user reviews the next step.

## 9. Guardrails

- Do not generate implementation prompts from chat memory alone.
- Do not bypass ChatGPT review.
- Do not treat OpenClaw / MiniMax DRAFT as FINAL.
- Do not treat Telegram `/approve` as push, merge, release, or publishing.
- Do not modify business code outside scope.
- Do not leak MiniMax, Telegram, OpenClaw, Codex, or other private credentials.
- Do not point work to old audit worktrees unless the user explicitly asks.

## 10. Next Recommended Work

- Complete dev-only orchestration contract docs.
- Then run a real `/draft` end-to-end dry run on the `dev` baseline.
