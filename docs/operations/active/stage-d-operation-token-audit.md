# Stage D Operation Token / Audit Context

## 1. Purpose

This is the active context entry point for Stage D operation token, operation
audit, and preview-confirm workflow tasks. It is not a full historical report.
It is the current fact entry used when agents generate, review, or execute
prompts.

## 2. Current Known Status

Safe confirmed status:

- Stage D exists as the active engineering stream. (`user-provided`)
- It involves operation preview, confirmation token, operation audit log, token
  persistence, token-aware confirm paths, and save timing record preview/confirm
  flow. (`user-provided`)
- Stage D worktree path
  `/Users/yu/Flutter_Projects/worktrees/fleet_ledger_audit` exists and is on
  `feature/audit`, HEAD `a8a731c`, clean status. (`repo-verified`)
- User-provided latest known Stage D commit was
  `cbf2fdb feat(operations): audit token failure paths`. (`user-provided`)
- Because the repo-verified worktree HEAD is now `a8a731c`, current Stage D
  implementation state must be re-verified before any implementation prompt.
  (`needs verification`)

Detailed implementation state must be verified from repository commits, reports,
or user-provided latest stage notes before any implementation prompt. Do not
infer completion status from commit titles alone.

## 3. Current Stage D Status Snapshot

| Stage | Status | Source |
| --- | --- | --- |
| D1 | OperationPreview / OperationExecutionResult pure models completed | user-provided |
| D2 | SaveTimingRecordOperationCommand / preview adapter completed | user-provided |
| D3 | `operation_audit_logs` table, OperationAuditLog model, append-only repository, v22 migration completed | user-provided |
| D4 | command can write success / failure / cancel audit | user-provided |
| D6 | OperationTransactionRunner / LocalOperationTransactionRunner completed; save timing command and audit in same SQLite transaction | user-provided |
| D8 | manual save timing production path connected to command + same-transaction audit; UI does not show preview | user-provided |
| D10 | ProjectResolver transaction-aware work completed | user-provided |
| D12 | DB-backed SaveTimingRecordOperationAnalyzer completed | user-provided |
| D14 | freshness verdict / validateFreshness completed | user-provided |
| D16 | freshness-aware confirm adapter completed | user-provided |
| D18 | stale preview rejection writes failure audit | user-provided |
| D20 | SaveTimingRecord preview-only adapter completed | user-provided |
| D26.5 | redacted preview riskLevel side-channel fix completed | user-provided |
| D29 | ActorScope / VisibilityScope pure model foundation completed | user-provided |
| D38 | TimingOperationReadQueryService first pass completed and committed | user-provided |
| D41 | SaveTimingRecord preview pre-disambiguation service completed and submitted to dev, commit `39c2da9` | user-provided |
| D44 | OperationConfirmationToken pure model slice completed | user-provided |
| D47 | `operation_tokens` persistence first pass completed | user-provided |
| D53 | `operation_audit_logs.token_id` first pass completed | user-provided |
| D55 | success / stale audit writes `tokenId` minimal implementation completed and committed | user-provided |
| D58 | `token_not_found` / `token_invalid` / `token_claim_failed` token-aware confirm failure paths write failure audit, committed as `cbf2fdb` | user-provided |
| D60 | PreviewService token issuing read-only design audit completed and passed | user-provided |

## 4. Latest Known Checkpoint

- D58 token failure audit committed as
  `cbf2fdb feat(operations): audit token failure paths`. (`user-provided`)
- D60 design audit completed and recommended D61. (`user-provided`)
- The currently verified `fleet_ledger_audit` worktree is already at
  `a8a731c feat(timing): issue confirmation tokens from preview service`.
  (`repo-verified`)
- The difference between `cbf2fdb` and `a8a731c` must be reviewed before using
  either as the basis for a new D61 prompt. (`needs verification`)
- Because `a8a731c` appears to describe preview-service token issuing, it may
  already contain D61-related implementation. The next step is status alignment,
  not direct implementation. (`needs verification`)

## 5. Recommended D61 Direction

The user-provided D60 recommendation for D61:

- Add `SaveTimingRecordPreviewTokenIssuer`.
- PreviewService token-aware path calls the token issuer.
- PreviewAdapter remains preview-only.
- Response returns redacted preview plus `tokenId` handle, `expiresAt`, and
  `canProceedToConfirm`.
- Response must not return full analysis, full preview, or full token.
- Token binds operationId, operationType, actor, delegated, session,
  actorScopeHash, inputHash, fullAnalysisHash, redactedPreviewHash, createdAt,
  expiresAt, and source.
- Reuse ConfirmAdapter input/full hash semantics and consider extracting a
  shared helper.
- owner + fullOwner may sign.
- driver / partner / bare agent / scope denied must not sign.
- Default TTL recommendation: 5 minutes.
- `expiresAt = min(now + ttl, scope.expiresAt)`.
- D61 does not connect MCP, UI, or outbox.
- D61 does not add schema.
- D61 does not change ConfirmAdapter semantics.

Source for all bullets in this section: `user-provided`.

## 6. Known Risk Areas

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

## 7. Default Task Routing

- If the user asks for the next Stage D implementation, first generate a DRAFT
  prompt and send it to ChatGPT review.
- If detailed current state is missing, the next task should be readonly audit
  or prompt-planning, not implementation.
- If a task mentions DB schema/migration, use the migration-change template.
- If a task only asks to review a Codex report, use `report-checklist.md`.
- If a task asks to implement token/audit behavior, require scoped files,
  forbidden changes, and targeted tests.

## 8. Required Docs / Files Before Stage D Prompt Generation

- `docs/operations/active/current-stage.md`
- `docs/operations/active/stage-d-operation-token-audit.md`
- `.agents/skills/fleet-ledger-orchestrator/references/chatgpt-review-gateway.md`
- `docs/agent/templates/readonly-audit.md`
- `docs/agent/templates/implementation-task.md`
- `docs/architecture/testing-rules.md`
- Relevant repository files discovered by search, but do not hardcode files
  unless verified for the current task.

## 9. Required Verification Before D61 Implementation Prompt

Before generating an implementation prompt for D61:

- Verify the actual execution worktree path.
- Verify branch.
- Verify HEAD.
- Verify git status clean/dirty state.
- Inspect current PreviewService, TokenRepository, ConfirmationToken,
  fingerprint helper, and ConfirmAdapter files before writing the prompt.
- Confirm whether D58 and D60 changes are present in the execution worktree.
- If `fleet_ledger_app` dev and `fleet_ledger_audit` feature/audit differ,
  state the execution path and risk explicitly.

## 10. Forbidden Assumptions

- Do not assume the latest Stage D step from chat memory.
- Do not assume `fleet_ledger_app` dev and `fleet_ledger_audit` feature/audit
  are synchronized.
- Do not assume D61 can be executed directly on `dev`.
- Do not assume a worktree path unless the user provides it or git confirms it.
- Do not assume a commit is present unless git confirms it.
- Do not assume schema version or migration state without reading the repository.
- Do not assume token failure audit, preview token issuing, or confirm adapter
  integration is already complete unless verified.
- Do not assume token schema needs to change.
- Do not assume UI, MCP, outbox, external work, statistics, Excel/export, or
  product rules can be modified.
- Do not assume push is allowed.

## 11. Recommended Next Prompt Type

The current default next prompt type is:

```text
prompt-review / implementation-draft:
Generate D61/D63 status-alignment readonly audit DRAFT_PROMPT_PACKAGE for ChatGPT review
```

OpenClaw / MiniMax should not generate FINAL prompts directly. Do not default to
direct implementation until current Stage D status, execution worktree, and
scope are confirmed, especially because `a8a731c` may already cover part of the
user-provided D61 direction.
