# S6-2 partner sync conflict simulation

## Result

PASS

## Scope

- Branch: `codex/auto-s1-s7-20260612`
- Worktree: `/Users/yu/Flutter_Projects/fleet_ledger_codex_s1s7`
- Baseline before slice: `821017a S6-1 partner device permission boundary`
- Commit target: `S6-2 partner sync conflict simulation`

## Files

- `lib/features/sync/use_cases/partner_sync_conflict_simulation.dart`
- `test/features/sync/use_cases/partner_sync_conflict_simulation_test.dart`

## Implementation

- Added a local, in-memory `PartnerSyncConflictSimulation`.
- Modeled partner sync ledger entries with:
  - stable entry id and device id;
  - `MeasureUnit` and integer `quantityScaled`;
  - exact integer `amountFen`;
  - revision / update timestamp / origin actor;
  - optional settled snapshot object.
- Added merge simulation rules:
  - unauthorized device writes are skipped with warnings;
  - one-sided authorized updates are accepted as-is;
  - same-entry multi-party edits become conflicts requiring owner review;
  - conflicts preserve both sides' exact fen amounts and settled snapshots;
  - no amount recomputation and no snapshot auto-merge is performed.

## DoD Evidence

- 多方写入模拟测试: PASS, local owner and remote partner writes to the same
  entry produce an owner-review conflict.
- 冲突解决测试: PASS, conflict results preserve both local and remote values
  and do not auto-apply either side.
- 冲突不破坏金额精度: PASS, tests use `33334` and `33335` fen values that must
  stay exact and are not recomputed from quantity.
- 冲突不破坏确认快照: PASS, conflicting settled snapshots remain object-identical
  on both sides; the simulation does not merge or overwrite snapshots.
- 自动模式只做本地模拟和测试: PASS, no `SyncManager`, real cloud client,
  backend, account, token, production data, or network path was touched.

## GitNexus

- `npx gitnexus analyze`: PASS,
  `11,542 nodes | 30,727 edges | 684 clusters | 300 flows`.
- `npx gitnexus impact PartnerSyncConflictSimulation -r /Users/yu/Flutter_Projects/fleet_ledger_codex_s1s7`:
  LOW, 2 impacted, 0 affected processes.
- `npx gitnexus impact PartnerSyncLedgerEntry -r /Users/yu/Flutter_Projects/fleet_ledger_codex_s1s7`:
  LOW, 3 impacted, 0 affected processes.
- `npx gitnexus detect-changes --scope all -r /Users/yu/Flutter_Projects/fleet_ledger_codex_s1s7`:
  untracked files were not detected; staged detection is required before commit.

## Verification

- `dart format lib/features/sync/use_cases/partner_sync_conflict_simulation.dart test/features/sync/use_cases/partner_sync_conflict_simulation_test.dart` PASS.
- `flutter test test/features/sync/use_cases/partner_sync_conflict_simulation_test.dart` PASS, 5 tests.
- `flutter test test/features/sync/use_cases/partner_device_sync_boundary_test.dart test/features/sync/use_cases/partner_sync_conflict_simulation_test.dart` PASS, 11 tests.
- `flutter analyze lib test` PASS.
- `dart run custom_lint` PASS.
- `git diff --check` PASS.
- `flutter test` PASS, `+1869 ~3`.

## Invariants

1. `project_id` 是项目身份唯一权威: PASS, no project identity logic changed.
2. FK ON DELETE RESTRICT 生效: PASS, no schema or FK changes.
3. 无孤儿 `project_id`: PASS, no persistence path added.
4. `settled/archived/voided` 不自动匹配: PASS, no matching logic changed.
5. 结清后同名新项目创建新 `project_id`: PASS, no project creation logic changed.
6. 金额/单价整数分: PASS, amount conflict fields are exact integer fen.
7. 计量定标整数: PASS, conflict entries carry integer `quantityScaled`.
8. `AmountPolicy` 单一整数路径: PASS, no amount calculation or `AmountPolicy` change.
9. 核心金额无新增 double/float: PASS, no money double/float path added.
10. `hours_milli` 只是 HOUR 特例: PASS, no `hours_milli` logic changed.
11. unit 枚举是数据，不翻译: PASS, entry maps use `MeasureUnit.dbValue`.
12. 确认态是快照，不静默改写: PASS, settled snapshots are preserved and conflicts require owner review.
13. 修改已确认结果走作废/撤销/重建: PASS, no mutation path added.
14. `external_work_records` 与 `timing_records` 分离: PASS, no external work path changed.
15. 外协不污染收入、应收、设备统计: PASS, no aggregation logic changed.
16. source/local/export 三层单价互不覆盖: PASS, no price layer logic changed.
17. 外部记录不可硬删: PASS, no delete path added.
18. `.jztshare` 防御式解析、hash 校验、事务化: PASS, no share parser changes.
19. 分享包不含手机号、通讯录、本机 `device_id`、设备自动编号: PASS, no share payload changes.
20. 填报/同步/AI 写入进入 pending: PASS, conflicting sync writes are not auto-applied.
21. UI 不暴露 `project_id/share_id`: PASS, no UI changed.
22. UI 不使用会计/债务术语: PASS, no UI copy added.
23. 新文案尽量走 i18n key: PASS, no UI text added.
24. 迁移同步 backup normalize / sync coverage / canary: PASS, no migration or backup path changed.

## Risk Notes

- No high-risk action was taken: no schema migration, destructive operation,
  real cloud integration, real partner sync, dependency addition, signing, CI,
  secrets, push, or merge.
- This slice is intentionally a local conflict contract. Production conflict
  application, persistence, UI review, and real multi-device sync remain later
  approved scopes.
- `npx gitnexus analyze` again generated `AGENTS.md` / `CLAUDE.md` metadata
  updates; those generated changes were reverted and are not part of this slice.
