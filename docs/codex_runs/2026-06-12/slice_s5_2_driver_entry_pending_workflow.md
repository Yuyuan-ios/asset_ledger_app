# S5-2 Driver Entry Pending Workflow

## Scope

- Worktree: `/Users/yu/Flutter_Projects/fleet_ledger_codex_s1s7`
- Branch: `codex/auto-s1-s7-20260612`
- Baseline: `5bcc636 S5-1 fake cloud sync loop`
- Slice: S5-2 DriverEntryLink / Submission / Approved pending workflow

## Changes

- Added a local application-layer driver submission workflow:
  - `DriverEntryLink` validates driver scope, allowed devices, expiry, revoke state, and submission limit.
  - `DriverEntrySubmissionWorkflow.submit` allows only driver preview actors and creates `pending` submissions only.
  - `DriverEntrySubmissionWorkflow.approve` allows only owner execute actors and delegates the actual `TimingRecord` creation to an approval gateway.
  - `DriverEntrySubmissionDriverView` exposes only driver-safe fields and omits project, contact, site, and financial data.
- Added focused in-memory tests for:
  - pending-only driver submission with no direct `TimingRecord` write;
  - link expiry, revoke, and one-use limit;
  - driver and device scope enforcement;
  - owner approval changing pending to approved after a persisted timing record id exists;
  - driver cannot approve, owner cannot submit through driver link;
  - driver view hides经营数据.

## Files

- `lib/features/timing/use_cases/driver_entry_submission_workflow.dart`
- `test/features/timing/use_cases/driver_entry_submission_workflow_test.dart`

## DoD

- 链接过期/撤销/限次: PASS, covered by `link expiry, revoke, and submission limit block submit`.
- pending -> confirm -> 入账: PASS, driver submit creates pending only; owner approve writes through `DriverEntryApprovalGateway` and marks submission approved.
- 权限测试: PASS, reused `OperationPermissionPolicy`; driver direct execute is denied, owner submit is denied, driver approve is denied.
- 司机看不到经营数据: PASS, driver view omits project/contact/site/income fields and `OperationVisibilityPolicy` denies financial amount and project label.
- fake/mock/test-only only: PASS, uses in-memory test repositories and a fake approval gateway; no real cloud, token, account, backend, or production data.

## Impact Analysis

- `npx gitnexus status`: stale at commit `adc4d41`, current `5bcc636`; refreshed with `npx gitnexus analyze`.
- `npx gitnexus analyze`: PASS, `11,390 nodes | 30,432 edges | 679 clusters | 300 flows`.
- `npx gitnexus impact DriverEntrySubmissionWorkflow -r /Users/yu/Flutter_Projects/fleet_ledger_codex_s1s7`: LOW, 3 impacted, 1 affected test process.
- `npx gitnexus impact DriverEntryLink -r /Users/yu/Flutter_Projects/fleet_ledger_codex_s1s7`: LOW, 6 impacted, 0 affected processes.
- `npx gitnexus detect-changes --scope all -r /Users/yu/Flutter_Projects/fleet_ledger_codex_s1s7`: did not include untracked files; staged detection will be run before commit.

## Verification

- `dart format lib/features/timing/use_cases/driver_entry_submission_workflow.dart test/features/timing/use_cases/driver_entry_submission_workflow_test.dart`: PASS.
- `flutter test test/features/timing/use_cases/driver_entry_submission_workflow_test.dart`: PASS, 6 tests.
- `flutter test test/features/timing/use_cases/driver_entry_submission_workflow_test.dart test/core/operations/operation_access_control_test.dart test/data/repositories/operation_token_repository_test.dart test/data/repositories/operation_audit_log_repository_test.dart`: PASS, 85 tests.
- `flutter test`: PASS, `+1858 ~3`.
- `flutter analyze lib test`: PASS.
- `dart run custom_lint`: PASS.
- `git diff --check`: PASS.

## Invariants

1. `project_id` 是项目身份唯一权威: PASS, no project identity logic changed.
2. FK ON DELETE RESTRICT 生效: PASS, no schema or FK changes.
3. 无孤儿 `project_id`: PASS, no persistence path added.
4. `settled/archived/voided` 不自动匹配: PASS, no matching logic changed.
5. 结清后同名新项目创建新 `project_id`: PASS, no project creation logic changed.
6. 金额/单价整数分: PASS, no amount or price calculation added.
7. 计量定标整数: PASS, submission draft uses `quantityScaled` integer.
8. `AmountPolicy` 单一整数路径: PASS, no `AmountPolicy` changes.
9. 核心金额无新增 double/float: PASS, production workflow adds no amount double path; tests only mirror existing `TimingRecord` meter/hour compatibility fields.
10. `hours_milli` 只是 HOUR 特例: PASS, no `hours_milli` logic changed.
11. unit 枚举是数据，不翻译: PASS, driver view returns `unit.dbValue`.
12. 确认态是快照，不静默改写: PASS, approve only changes pending submission to approved with persisted record id.
13. 修改已确认结果走作废/撤销/重建: PASS, no edit-approved path added.
14. `external_work_records` 与 `timing_records` 分离: PASS, no external work path changed.
15. 外协不污染收入、应收、设备统计: PASS, no external work aggregation changed.
16. source/local/export 三层单价互不覆盖: PASS, no price layer logic changed.
17. 外部记录不可硬删: PASS, no delete path changed.
18. `.jztshare` 防御式解析、hash 校验、事务化: PASS, no share parser changes.
19. 分享包不含手机号、通讯录、本机 `device_id`、设备自动编号: PASS, no share payload changes.
20. 填报/同步/AI 写入进入 pending: PASS, driver submission enters pending and owner approval is required before `TimingRecord`.
21. UI 不暴露 `project_id/share_id`: PASS, no UI changed; driver view omits project id.
22. UI 不使用会计/债务术语: PASS, no UI copy added.
23. 新文案尽量走 i18n key: PASS, no UI text added.
24. 迁移同步 backup normalize / sync coverage / canary: PASS, no migration or sync schema changed.

## Risk

- No high-risk action was taken: no migration, no destructive data operation, no real cloud, no real AI/MCP write, no dependency addition, no signing/CI/secrets changes.
- The workflow is intentionally repository/gateway based and not wired into UI or DB persistence in this slice; production integration remains a later approved scope.
