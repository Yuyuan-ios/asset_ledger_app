# Stage D Operation Token / Audit Context

## 1. Purpose

This is the active context entry point for Stage D operation token, operation
audit, and preview-confirm workflow tasks. It is not a full historical report.
It is the current fact entry used when agents generate, review, or execute
prompts.

## 2. Current Known Status

Safe confirmed status:

- Stage D exists as the active engineering stream.
- It involves operation preview, confirmation token, operation audit log, token
  persistence, token-aware confirm paths, and save timing record preview/confirm
  flow.
- Recent `dev` history includes operation/token/audit-related commit titles:
  - `6a2f08c merge: operation command audit and token infrastructure`
  - `5a5462c feat(operations): consume confirmation token inside confirm transaction`
  - `9350926 feat(operations): persist operation tokens with state machine repository`
  - `701bede feat(operations): add confirmation token contract models`
- Recent branch list includes `feature/audit` at `cbf2fdb feat(operations): audit token failure paths`; verify the worktree, branch, and HEAD before using that branch as current evidence.

Detailed implementation state must be verified from repository commits, reports,
or user-provided latest stage notes before any implementation prompt. Do not
infer completion status from commit titles alone.

## 3. Known Risk Areas

- Operation token state machine.
- Operation audit append-only semantics.
- `token_id` linkage in audit logs.
- Stale/freshness validation.
- Token claim/consume failure paths.
- Save timing record confirm adapter.
- Preview-only vs execute paths.
- Actor/scope/redaction boundaries.
- DB migration risk if schema changes are requested.
- Audit log must not become mutable.
- Token repository must not support delete/replace style mutation unless
  explicitly designed.

## 4. Default Task Routing

- If the user asks for the next Stage D implementation, first generate a DRAFT
  prompt and send it to ChatGPT review.
- If detailed current state is missing, the next task should be readonly audit
  or prompt-planning, not implementation.
- If a task mentions DB schema/migration, use the migration-change template.
- If a task only asks to review a Codex report, use `report-checklist.md`.
- If a task asks to implement token/audit behavior, require scoped files,
  forbidden changes, and targeted tests.

## 5. Required Docs / Files Before Stage D Prompt Generation

- `docs/operations/active/current-stage.md`
- `docs/operations/active/stage-d-operation-token-audit.md`
- `.agents/skills/fleet-ledger-orchestrator/references/chatgpt-review-gateway.md`
- `docs/agent/templates/readonly-audit.md`
- `docs/agent/templates/implementation-task.md`
- `docs/architecture/testing-rules.md`
- Relevant repository files discovered by search, but do not hardcode files
  unless verified for the current task.

## 6. Forbidden Assumptions

- Do not assume the latest Stage D step from chat memory.
- Do not assume a worktree path unless the user provides it or git confirms it.
- Do not assume a commit is present unless git confirms it.
- Do not assume schema version or migration state without reading the repository.
- Do not assume token failure audit, preview token issuing, or confirm adapter
  integration is already complete unless verified.

## 7. Recommended Next Prompt Type

The current default next prompt type is:

```text
readonly audit / prompt-planning for the next Stage D operation token/audit task
```

Do not default to direct implementation until current Stage D status and scope
are confirmed.
