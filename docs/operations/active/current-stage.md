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
- Active branch: `develop`
- Default execution baseline: `develop`
- Current actual HEAD must be verified by git before every task.
- Latest known audited HEAD:
  `a2a7899 docs(agent): define dev-only orchestration contracts`.

If execution-time git state differs from this document, use actual command
output and write `verified current state differs` in the report. Do not reset,
checkout, or repair state unless the user explicitly asks.

## 4. Current Orchestration Goal

- OpenClaw backend brain: MiniMax.
- MiniMax / OpenClaw only drafts and orchestrates.
- OpenClaw uses GUI automation to connect ChatGPT and Codex on the home
  MacBook.
- ChatGPT reviews, corrects, narrows, and finalizes prompts.
- Codex performs programming execution.
- The user reviews from Telegram while away from the computer and chooses
  review / approve / stop / next.
- The current active goal is the mobile GUI automation orchestration loop:
  OpenClaw / MiniMax -> ChatGPT -> Telegram approval -> Codex -> Telegram
  report review.
- The current long-goal target is to run a mobile office long-goal automation
  dry run after the protocol docs are complete.
- Recommended first long-goal sample: date picker functionality.

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

The immediate next workflow is a first real `/draft` mobile office long-goal
dry run on the `develop` baseline.

For the recommended date picker sample, the first stage must be a read-only
audit and must not modify code.

The next default task is not D61/D63 audit-worktree status alignment. Stage D
documents are task-specific references only when the user explicitly asks about
Stage D / operation token / operation audit work.

These contracts define the current workflow:

- `docs/agent/telegram-review-contract.md`
- `docs/agent/codex-execution-contract.md`
- `docs/agent/openclaw-minimax-orchestration.md`
- `docs/agent/mobile-gui-automation-workflow.md`
- `docs/agent/long-goal-automation-protocol.md`
- `docs/operations/active/date-picker-dry-run-plan.md`

Terminal copy/paste may be used only as an early debugging fallback. It is not
the long-term target workflow.

Stage 5 mobile GUI workflow docs and Stage 5.1 long-goal protocol docs remain
uncommitted documentation closure work until the user explicitly requests a
commit.

## 7. Required Docs Before Drafting Prompts

OpenClaw / MiniMax must read these before generating a DRAFT:

- `AGENTS.md`
- `docs/operations/active/current-stage.md`
- `docs/agent/telegram-review-contract.md`
- `docs/agent/codex-execution-contract.md`
- `docs/agent/openclaw-minimax-orchestration.md`
- `docs/agent/mobile-gui-automation-workflow.md`
- `docs/agent/long-goal-automation-protocol.md`
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
2. OpenClaw sends DRAFT to ChatGPT through GUI automation.
3. ChatGPT reviews the DRAFT and outputs `FINAL_CODEX_PROMPT`.
4. OpenClaw sends the FINAL review card to Telegram.
5. User approves, revises, or stops through Telegram.
6. Codex executes FINAL only after approval.
7. OpenClaw summarizes the Codex report to Telegram.
8. User chooses next, revise, or stop.

For long goals, OpenClaw / MiniMax must generate a `DRAFT_STAGE_PLAN` first,
ChatGPT must produce `FINAL_STAGE_PLAN`, and the user must approve the plan
before Stage 1 execution begins.

## 9. Guardrails

- Do not generate implementation prompts from chat memory alone.
- Do not bypass ChatGPT review.
- Do not treat OpenClaw / MiniMax DRAFT as FINAL.
- Do not treat Telegram `/approve` as push, merge, release, or publishing.
- Do not modify business code outside scope.
- Do not leak MiniMax, Telegram, OpenClaw, Codex, or other private credentials.
- Do not point work to old audit worktrees unless the user explicitly asks.
- Do not let GUI automation bypass Telegram approval gates.
- Do not treat `/next` as permission to execute the next stage.
- Do not implement long goals before a stage plan is approved.
- Do not execute more than one long-goal stage per Codex run.

## 10. Next Recommended Work

- Run a first real `/draft` mobile office long-goal dry run on the `dev`
  baseline.
- Prefer the date picker sample in
  `docs/operations/active/date-picker-dry-run-plan.md`.
- Ensure Stage 0 is a read-only audit with no code changes.
