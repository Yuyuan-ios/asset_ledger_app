# S4-1 project offset snapshot

## Result

PASS

## Scope

- Branch: `codex/auto-s1-s7-20260612`
- Worktree: `/Users/yu/Flutter_Projects/fleet_ledger_codex_s1s7`
- Baseline before slice: `595b6c8 S3 stage report`
- Commit target: `S4-1 project offset snapshot`

## Files

- `lib/features/account/use_cases/project_offset_snapshot_use_case.dart`
- `test/features/account/use_cases/project_offset_snapshot_use_case_test.dart`

## Implementation

- Added `ProjectOffsetSnapshotUseCase` as a narrow account-layer use case.
- Added `ProjectSettlementOffsetSnapshotGateway` to route confirmation through the existing settlement write-off channel without editing `ProjectSettlementUseCase`.
- Encoded the product formula as a snapshot:
  - `netReceivableFen = ownedReceivableFen - externalWorkFen`
  - persisted write-off amount is capped at owned receivable so the existing settlement invariant is preserved
- Persisted offset confirmation as `ProjectWriteOffReason.offset` with `paymentAmount: 0`.
- Added a snapshot note line with owned receivable, external work, and net receivable fen values:
  - `offset_snapshot_v1 owned_receivable_fen=... external_work_fen=... net_receivable_fen=...`
- Rebuild flow requires an existing offset write-off and deletes it before creating the replacement snapshot.

## DoD Evidence

- Net amount is based on `我方应收 - 项目外协金额`.
- Offset is modeled as a write-off snapshot, not cash receipt.
- The returned snapshot object keeps the original owned/external/net fen values, so later source amount changes do not silently rewrite it.
- Rebuild requires voiding the old offset snapshot first; non-offset write-offs are rejected.
- No database migration was added.
- No export/import, cloud, backup, release, push, or merge action was performed.

## Verification

- `flutter test test/features/account/use_cases/project_offset_snapshot_use_case_test.dart test/features/account/use_cases/project_settlement_use_case_test.dart` PASS (`+48`)
- `flutter analyze lib test` PASS
- `dart run custom_lint` PASS
- `flutter test` PASS (`+1845 ~3`)
- `git diff --check` PASS
- `npx gitnexus detect-changes --scope all -r /Users/yu/Flutter_Projects/fleet_ledger_codex_s1s7` returned `No changes detected.` before staging because this slice only had untracked files at that moment; staged change detection is required before commit.
- `npx gitnexus detect-changes --scope staged -r /Users/yu/Flutter_Projects/fleet_ledger_codex_s1s7` returned `No changes detected.` after staging; no HIGH or CRITICAL risk was reported.

## Risk Notes

- Impact analysis was checked before implementation:
  - `ProjectSettlementUseCase`: HIGH blast radius if edited
  - `ProjectWriteOff`: CRITICAL blast radius if edited
- This slice did not edit those existing symbols or their files. It adds a new use case and a unit test, then wraps existing settlement behavior through an explicit gateway.
- OpenClaw high-risk approval was not required for this implementation path unless staged change detection reports HIGH or CRITICAL before commit.
