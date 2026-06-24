# Stage D Operation Token / Audit Context

## 1. Purpose

This document is historical and task-specific context for Stage D operation
token, operation audit, and preview-confirm workflow tasks.

It is not the current default execution baseline. The current default execution
baseline is `/Users/yu/Flutter_Projects/fleet_ledger_app` on branch `develop`.

OpenClaw / MiniMax should not read this document as the default next step unless
the user explicitly asks for Stage D, operation token, operation audit, or
preview-confirm work.

## 2. Baseline Policy

- Default repository: `/Users/yu/Flutter_Projects/fleet_ledger_app`
- Default branch: `develop`
- Old audit worktree path:
  `/Users/yu/Flutter_Projects/worktrees/fleet_ledger_audit`
- The old audit worktree path is historical reference only.
- Do not use the old audit worktree as a default execution path.
- If future work reopens Stage D, first use current `develop` git state and
  confirm relevant code has been merged to `develop`.
- If the user explicitly requires the audit worktree, verify path, branch, HEAD,
  and git status before drafting.

## 3. Status Source Labels

- `repo-verified`: Confirmed by current repository files or git commands.
- `user-provided`: Provided by the user as latest stage notes, not directly
  verified in this document.
- `needs verification`: Must be checked before implementation.
- `unknown`: Not known.

## 4. Historical Stage D Status Snapshot

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

## 5. Latest Known Checkpoints

- D58 token failure audit committed as
  `cbf2fdb feat(operations): audit token failure paths`. (`user-provided`)
- D60 design audit completed and recommended D61. (`user-provided`)
- Later develop history includes operation token audit infrastructure and preview
  token confirmation test commits. (`repo-verified` from recent git log)
- Future Stage D work must use current `develop` state unless the user explicitly
  provides another execution target. (`repo-verified` baseline policy)

## 6. Recommended D61 Direction

The historical user-provided D60 recommendation for D61:

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

## 7. Known Risk Areas

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

## 8. Required Verification Before Future Stage D Prompts

Before generating a Stage D implementation prompt:

- Verify the execution repository path.
- Verify branch.
- Verify HEAD.
- Verify git status clean/dirty state.
- Confirm relevant code is present in current `develop`.
- Inspect current task-relevant files before writing the prompt.
- Confirm whether historical D58/D60/D61 assumptions are already superseded by
  current `develop` commits.

## 9. Forbidden Assumptions

- Do not assume the latest Stage D step from chat memory.
- Do not assume old audit worktree state is current.
- Do not assume `fleet_ledger_app` dev and any audit worktree are synchronized.
- Do not assume D61 can be executed on an old branch or old worktree.
- Do not assume a commit is present unless git confirms it.
- Do not assume schema version or migration state without reading the
  repository.
- Do not assume token schema needs to change.
- Do not assume UI, MCP, outbox, external work, statistics, Excel/export, or
  product rules can be modified.
- Do not assume push is allowed.

## 10. Recommended Next Prompt Type

Only when the user explicitly asks for Stage D work, default to:

```text
prompt-review / readonly-audit:
Generate a develop-baseline Stage D status audit DRAFT_PROMPT_PACKAGE for ChatGPT review
```

Do not default to direct implementation until current `develop` status and task
scope are confirmed.
