# Current Active Stage

## 1. Purpose

This document is the current active-stage entry point for repository agents. It
should be read:

- Before OpenClaw / MiniMax generates a `DRAFT_PROMPT_PACKAGE`.
- When ChatGPT reviews a DRAFT prompt against current stage facts.
- Before Codex executes a `FINAL_CODEX_PROMPT`.
- To prevent agents from acting only from chat history, fuzzy memory, or stale
  assumptions.

## 2. Status Source Labels

Use these labels whenever active-stage status is recorded or referenced:

- `repo-verified`: Confirmed by current repository files or git commands.
- `user-provided`: Provided by the user as latest stage notes, but not directly
  verified from the current repository in this task.
- `needs verification`: Must be checked before generating an implementation
  prompt.
- `unknown`: Not known from current docs, git state, or user-provided notes.

Do not present `user-provided` status as `repo-verified`.

## 3. Current Repository Status

- Repository: `/Users/yu/Flutter_Projects/fleet_ledger_app` (`repo-verified`)
- Active branch: `dev` (`repo-verified`)
- Current HEAD verified while updating this document:
  `e2ead0e docs(agent): add active stage context` (`repo-verified`)
- Latest known Harness commits:
  - `2a0d34c chore(agent): add repository harness for coding agents` (`repo-verified`)
  - `6cead73 chore(agent): add prompt review gateway skill` (`repo-verified`)
  - `65714c4 docs(agent): add prompt gateway dry run` (`repo-verified`)
  - `e2ead0e docs(agent): add active stage context` (`repo-verified`)
- Push status: not verified in this task. Re-check git remote/upstream state
  before reporting current push status. (`needs verification`)
- Business code status: Harness stages did not modify `lib/`, `test/`,
  `pubspec.yaml`, DB schema/migration files, or `$HOME/.agents`.
  (`repo-verified` for Harness commits and current task scope)

If current git state differs from the values above, use actual command output
and write `verified current state differs` in the task report.

## 4. Active Stage Summary

- Stage 1: Repository Harness completed. (`repo-verified`)
- Stage 2: Prompt Review Gateway + Skill completed. (`repo-verified`)
- Stage 3: Prompt Gateway Dry Run completed. (`repo-verified`)
- Stage 3.5: Active Stage Context completed. (`repo-verified`)
- Stage 3.6: Supplement Stage D current state in progress. (`repo-verified`)

## 5. Current Active Product / Engineering Stream

The current real engineering stream is not the Harness itself. The active stream
is Stage D: operation token / operation audit / confirmation token /
preview-confirm workflow. (`user-provided`)

Latest user-provided Stage D milestone:

- D60 design audit completed and recommended D61 PreviewService token issuing.
  (`user-provided`)
- Recommended next is D61: generate a `DRAFT_PROMPT_PACKAGE` for ChatGPT review
  before any implementation. (`user-provided`)

Repository/worktree state verified during this update:

- Main Harness docs live in `/Users/yu/Flutter_Projects/fleet_ledger_app` on
  `dev` at `e2ead0e`. (`repo-verified`)
- Stage D worktree path exists at
  `/Users/yu/Flutter_Projects/worktrees/fleet_ledger_audit`. (`repo-verified`)
- That worktree is on `feature/audit`, HEAD `a8a731c`, with clean
  `git status --short`. (`repo-verified`)
- This differs from the user-provided latest known Stage D commit
  `cbf2fdb feat(operations): audit token failure paths`; therefore detailed
  Stage D status must be verified before implementation prompts.
  (`needs verification`)
- Because `a8a731c` is titled `feat(timing): issue confirmation tokens from
  preview service`, it may already contain D61-related implementation. The next
  step should be a readonly status-alignment audit, not a new implementation
  prompt. (`needs verification`)

Detailed Stage D implementation status must be updated from latest
user-provided report or repository evidence before generating implementation
prompts. Do not treat commit titles or user-provided milestones as complete
proof of implementation state.

## 6. Required Docs Before Drafting Prompts

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

## 7. Default Workflow

1. OpenClaw / MiniMax generates `DRAFT_PROMPT_PACKAGE`.
2. ChatGPT reviews the DRAFT and outputs `FINAL_CODEX_PROMPT`.
3. User approves through Telegram.
4. Codex executes FINAL only.
5. OpenClaw / MiniMax summarizes the Codex report.
6. ChatGPT or the user reviews the next step.

## 8. Global Active-Stage Guardrails

- OpenClaw / MiniMax cannot bypass ChatGPT review.
- Codex cannot execute DRAFT prompts.
- Telegram `/approve` does not mean push or merge.
- High-risk implementation tasks should start with readonly audit or
  prompt-planning when active context is incomplete.
- Do not touch UI, external work, statistics, DB schema/migration, Excel/export,
  or product rules unless the task explicitly targets them.
- Do not rely on chat memory alone.

## 9. Worktree Caution

- Harness docs live in `/Users/yu/Flutter_Projects/fleet_ledger_app`.
- Stage D implementation may live in
  `/Users/yu/Flutter_Projects/worktrees/fleet_ledger_audit`.
- Agents must not assume both paths share the same HEAD or working tree state.
- Before implementation, verify the execution path, branch, HEAD, and dirty
  state in the target worktree.

## 10. Next Immediate Recommendation

- Generate a D61/D63 status-alignment `DRAFT_PROMPT_PACKAGE` through Prompt
  Review Gateway.
- Do not bypass ChatGPT review.
- Do not run implementation before confirming the correct worktree and current
  git state.
- Do not generate a new D61 implementation prompt until `a8a731c` is reviewed
  against the user-provided D60 -> D61 plan.

## 11. Next Recommended Work

- Keep active stage context updated.
- Generate Stage D prompts through Prompt Review Gateway.
- Telegram command contract can come after active context is stable.
