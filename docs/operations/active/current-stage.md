# Current Active Stage

## 1. Purpose

This document is the current active-stage entry point for repository agents. It
should be read:

- Before OpenClaw / MiniMax generates a `DRAFT_PROMPT_PACKAGE`.
- When ChatGPT reviews a DRAFT prompt against current stage facts.
- Before Codex executes a `FINAL_CODEX_PROMPT`.
- To prevent agents from acting only from chat history, fuzzy memory, or stale
  assumptions.

## 2. Current Repository Status

- Repository: `/Users/yu/Flutter_Projects/fleet_ledger_app`
- Active branch: `dev`
- Current HEAD verified while creating this document: `65714c4 docs(agent): add prompt gateway dry run`
- Latest known Harness commits:
  - `2a0d34c chore(agent): add repository harness for coding agents`
  - `6cead73 chore(agent): add prompt review gateway skill`
  - `65714c4 docs(agent): add prompt gateway dry run`
- Push status: not pushed / no upstream was shown for `dev` by `git branch -vv`
  at verification time. Re-check git state before reporting current push status.
- Business code status: Harness stages did not modify `lib/`, `test/`,
  `pubspec.yaml`, DB schema/migration files, or `$HOME/.agents`.

If current git state differs from the values above, use actual command output
and write `verified current state differs` in the task report.

## 3. Active Stage Summary

- Stage 1: Repository Harness completed.
- Stage 2: Prompt Review Gateway + Skill completed.
- Stage 3: Prompt Gateway Dry Run completed.
- Stage 3.5: Active Stage Context in progress.

## 4. Current Active Product / Engineering Stream

The current real engineering stream is not the Harness itself. The active stream
is Stage D: operation token / operation audit / confirmation token /
preview-confirm workflow.

Known repository evidence:

- Recent `dev` history includes operation/token commits:
  - `6a2f08c merge: operation command audit and token infrastructure`
  - `5a5462c feat(operations): consume confirmation token inside confirm transaction`
  - `9350926 feat(operations): persist operation tokens with state machine repository`
  - `701bede feat(operations): add confirmation token contract models`
- Recent branch list includes `feature/audit` at `cbf2fdb feat(operations): audit token failure paths`, but worktree and branch state must be verified before using it.

Detailed Stage D implementation status must be updated from latest
user-provided report or repository evidence before generating implementation
prompts. Do not treat the commit titles above as a complete Stage D status.

## 5. Required Docs Before Drafting Prompts

OpenClaw / MiniMax must read these before generating a DRAFT:

- `AGENTS.md`
- `docs/operations/active/current-stage.md`
- `docs/operations/active/stage-d-operation-token-audit.md`
- `.agents/skills/fleet-ledger-orchestrator/SKILL.md`
- `.agents/skills/fleet-ledger-orchestrator/references/chatgpt-review-gateway.md`
- `.agents/skills/fleet-ledger-orchestrator/references/prompt-rules.md`
- `.agents/skills/fleet-ledger-orchestrator/references/task-types.md`
- `.agents/skills/fleet-ledger-orchestrator/references/report-checklist.md`
- `docs/agent/prompt-review-gateway.md`
- `docs/architecture/testing-rules.md`

## 6. Default Workflow

1. OpenClaw / MiniMax generates `DRAFT_PROMPT_PACKAGE`.
2. ChatGPT reviews the DRAFT and outputs `FINAL_CODEX_PROMPT`.
3. User approves through Telegram.
4. Codex executes FINAL only.
5. OpenClaw / MiniMax summarizes the Codex report.
6. ChatGPT or the user reviews the next step.

## 7. Global Active-Stage Guardrails

- OpenClaw / MiniMax cannot bypass ChatGPT review.
- Codex cannot execute DRAFT prompts.
- Telegram `/approve` does not mean push or merge.
- High-risk implementation tasks should start with readonly audit or
  prompt-planning when active context is incomplete.
- Do not touch UI, external work, statistics, DB schema/migration, Excel/export,
  or product rules unless the task explicitly targets them.
- Do not rely on chat memory alone.

## 8. Next Recommended Work

- First keep active stage context updated.
- Then generate Stage D prompts through Prompt Review Gateway.
- Telegram command contract can come after active context is stable.
