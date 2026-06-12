# S2-1 unit/quantity authority

## Conclusion

PASS.

This slice upgrades the new timing-record save path so non-rent records must
carry the unified measurement authority before persistence or sync outbox write.
No schema rebuild, migration, AmountPolicy semantic change, or external service
access was performed.

## Scope

- Branch: `codex/auto-s1-s7-20260612`
- Worktree: `/Users/yu/Flutter_Projects/fleet_ledger_codex_s1s7`
- Baseline HEAD before this slice: `da65881`
- Slice: `S2-1 unit quantity authority`

## Changed Files

- `lib/infrastructure/local/timing/local_save_timing_record_with_impact_use_case.dart`
  - Added application-layer validation in both `prepareForSave` and
    `executeWithExecutor`.
  - New records with non-rent units now fail fast when `quantity_scaled` is
    absent.
  - Existing edit paths and rent rows remain compatible because rent quantity
    semantics are still deferred.
- `test/infrastructure/local/timing/save_timing_record_with_impact_test.dart`
  - Added a save-path assertion that new hour records persist `unit` and
    `quantity_scaled` and include both fields in sync payload.
  - Added rollback assertion for missing `quantity_scaled`: no timing row,
    outbox row, or sync meta row is left behind.

## DoD Evidence

- New records must carry unit/quantity:
  - Added test: `新建工时记录落库和同步 payload 必带 unit 与 quantity_scaled`.
- Missing quantity is rejected before persistence:
  - Added test: `新建非租期记录缺少 quantity_scaled 时拒绝保存`.
- Old data remains lossless:
  - Existing migration/model tests remain covered by full `flutter test`.
- Precision examples are covered by existing integer-path tests:
  - `test/core/money/amount_policy_test.dart`
  - `test/data/services/quantity_read_path_equivalence_test.dart`

## Validation

- `flutter test test/infrastructure/local/timing/save_timing_record_with_impact_test.dart`
  - PASS, `All tests passed!`
- `flutter test test/core/money/amount_policy_test.dart test/data/models/timing_record_test.dart test/data/services/quantity_read_path_equivalence_test.dart`
  - PASS, `All tests passed!`
- `flutter analyze lib test`
  - PASS, `No issues found!`
- `dart run custom_lint`
  - PASS, `No issues found!`
- `git diff --check`
  - PASS
- `flutter test`
  - PASS, `All tests passed!`, final count `+1823 ~3`
- `npx gitnexus detect-changes -r /Users/yu/Flutter_Projects/fleet_ledger_codex_s1s7`
  - PASS, risk `medium`, affected processes `2`

## Invariant Self-Check

- `project_id` identity: unchanged.
- FK behavior and orphan handling: unchanged.
- settled/archived/voided matching: unchanged.
- AmountPolicy integer path: unchanged; no new double/float money path.
- Unit enum remains stored data, not UI copy.
- `hours_milli` remains the HOUR special case of `quantity_scaled`.
- Rent rows remain compatible; rent quantity semantics are not invented here.
- External work and timing records remain separated.
- Sync/outbox writes stay transactional with the existing save flow.

## Risks And Residuals

- `quantity_scaled` remains nullable at schema level by design; the stricter
  NOT NULL flip is deferred until the next timing table rebuild.
- Rent row quantity semantics remain deferred.
- No OpenClaw high-risk approval was required inside this slice after the
  baseline fast-forward approval.

## Next

S2-1 allows continuing to S2-2 (`entry template phase A`) after commit if the
branch remains clean and no high-risk item is pending.
