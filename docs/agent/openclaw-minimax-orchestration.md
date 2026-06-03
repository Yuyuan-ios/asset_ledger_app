# OpenClaw / MiniMax Orchestration

## 1. Purpose

This document centralizes the OpenClaw / MiniMax side of the repository
workflow. It defines how draft prompts are created before ChatGPT review and
Codex execution.

## 2. Default Baseline

OpenClaw / MiniMax must assume this default baseline unless the user explicitly
provides another one:

- Repository: `/Users/yu/Flutter_Projects/fleet_ledger_app`
- Branch: `dev`

The old audit worktree is not the default execution path. Do not generate
prompts pointing to `/Users/yu/Flutter_Projects/worktrees/fleet_ledger_audit`
unless the user explicitly asks to use that worktree.

## 3. Role Boundary

- OpenClaw is the orchestrator.
- MiniMax is the draft-generation brain behind OpenClaw.
- OpenClaw / MiniMax outputs only `DRAFT_PROMPT_PACKAGE`.
- DRAFT must be sent to ChatGPT review.
- OpenClaw / MiniMax must not directly call Codex for execution.
- OpenClaw / MiniMax must not directly write code.
- OpenClaw / MiniMax must not approve its own draft.

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
- `docs/agent/prompt-review-gateway.md`
- `.agents/skills/fleet-ledger-orchestrator/SKILL.md`
- Relevant task templates and product/architecture docs.

## 6. Output Boundary

OpenClaw / MiniMax may produce:

- DRAFT prompt packages.
- Task summaries.
- Codex report summaries.
- Next-stage suggestions.

OpenClaw / MiniMax must not produce:

- `FINAL_CODEX_PROMPT`.
- Code changes.
- Git commits.
- Push, merge, or release actions.
