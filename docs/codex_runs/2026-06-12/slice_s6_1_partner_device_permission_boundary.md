# S6-1 partner device permission boundary

## Result

PASS

## Scope

- Branch: `codex/auto-s1-s7-20260612`
- Worktree: `/Users/yu/Flutter_Projects/fleet_ledger_codex_s1s7`
- Baseline before slice: `6022291 S5 stage report`
- Commit target: `S6-1 partner device permission boundary`

## Files

- `lib/features/sync/use_cases/partner_device_sync_boundary.dart`
- `test/features/sync/use_cases/partner_device_sync_boundary_test.dart`

## Implementation

- Added a local, in-memory `PartnerDeviceSyncBoundary` use case.
- Reused existing `ActorContext`, `ActorScope`, `OperationScopePolicy`,
  `OperationPermissionPolicy`, and `OperationVisibilityPolicy`.
- Allowed sync snapshots only for partner or agent-as-partner actors with an
  active device scope.
- Filtered devices and timing records strictly by authorized device id.
- Output only partner-safe device and timing basics:
  - device id, display name, brand/model, active flag;
  - record id, device id, work date, unit, quantity scaled, meter snapshots.
- Kept source-side project/contact/site/income/unit-price fields out of the
  partner sync snapshot.

## DoD Evidence

- 未授权设备不可见: PASS, covered by empty and mismatched device scope tests.
- 授权设备同步不带无关项目数据: PASS, snapshot map omits project id, project
  label, contact, site, income fen, and unit price fen.
- 自动模式只做本地模拟和测试: PASS, no `SyncManager`, real cloud client,
  backend, token, account, or network path was touched.
- 权限边界复用现有策略: PASS, boundary checks actor type, read/export
  permission, visibility, scope expiry, and device scope.

## GitNexus

- `OperationScopePolicy` impact before implementation: HIGH. It was read and
  reused only; it was not edited.
- `TimingOperationReadQueryService` impact before implementation: MEDIUM. It
  was read for context only; it was not edited.
- `npx gitnexus analyze`: PASS,
  `11,482 nodes | 30,609 edges | 682 clusters | 300 flows`.
- `npx gitnexus impact PartnerDeviceSyncBoundary -r /Users/yu/Flutter_Projects/fleet_ledger_codex_s1s7`:
  LOW, 2 impacted, 1 affected test process.
- `npx gitnexus impact PartnerDeviceSyncSnapshot -r /Users/yu/Flutter_Projects/fleet_ledger_codex_s1s7`:
  LOW, 3 impacted, 1 affected test process.

## Verification

- `dart format lib/features/sync/use_cases/partner_device_sync_boundary.dart test/features/sync/use_cases/partner_device_sync_boundary_test.dart` PASS.
- `flutter test test/features/sync/use_cases/partner_device_sync_boundary_test.dart` PASS, 6 tests.
- `flutter test test/features/sync/use_cases/partner_device_sync_boundary_test.dart test/core/operations/operation_actor_scope_test.dart test/core/operations/operation_access_control_test.dart` PASS, 87 tests.
- `flutter analyze lib test` PASS.
- `dart run custom_lint` PASS.
- `git diff --check` PASS.
- `flutter test` PASS, `+1864 ~3`.

## Invariants

1. `project_id` 是项目身份唯一权威: PASS, no project identity logic changed.
2. FK ON DELETE RESTRICT 生效: PASS, no schema or FK changes.
3. 无孤儿 `project_id`: PASS, no persistence path added.
4. `settled/archived/voided` 不自动匹配: PASS, no matching logic changed.
5. 结清后同名新项目创建新 `project_id`: PASS, no project creation logic changed.
6. 金额/单价整数分: PASS, sensitive source fen fields are not exported to partner sync snapshots.
7. 计量定标整数: PASS, partner sync snapshot exposes `quantity_scaled`.
8. `AmountPolicy` 单一整数路径: PASS, no amount calculation added.
9. 核心金额无新增 double/float: PASS, no money double/float path added.
10. `hours_milli` 只是 HOUR 特例: PASS, no `hours_milli` logic changed.
11. unit 枚举是数据，不翻译: PASS, snapshot uses `MeasureUnit.dbValue`.
12. 确认态是快照，不静默改写: PASS, read-only snapshot only.
13. 修改已确认结果走作废/撤销/重建: PASS, no mutation path added.
14. `external_work_records` 与 `timing_records` 分离: PASS, no external work path changed.
15. 外协不污染收入、应收、设备统计: PASS, no aggregation logic changed.
16. source/local/export 三层单价互不覆盖: PASS, no price layer logic changed.
17. 外部记录不可硬删: PASS, no delete path added.
18. `.jztshare` 防御式解析、hash 校验、事务化: PASS, no share parser changes.
19. 分享包不含手机号、通讯录、本机 `device_id`、设备自动编号: PASS, no share payload changes.
20. 填报/同步/AI 写入进入 pending: PASS, this slice is read-only local sync snapshot.
21. UI 不暴露 `project_id/share_id`: PASS, no UI changed; partner snapshot omits project id.
22. UI 不使用会计/债务术语: PASS, no UI copy added.
23. 新文案尽量走 i18n key: PASS, no UI text added.
24. 迁移同步 backup normalize / sync coverage / canary: PASS, no migration or backup path changed.

## Risk Notes

- No high-risk action was taken: no schema migration, destructive operation,
  real cloud integration, real multi-device sync, dependency addition, signing,
  CI, secrets, push, or merge.
- `npx gitnexus analyze` temporarily modified `AGENTS.md` and `CLAUDE.md` with
  generated GitNexus metadata. Those generated changes were reverted and are not
  part of this slice.
- Production integration remains a later approved scope. This slice defines and
  tests the permission boundary only.
