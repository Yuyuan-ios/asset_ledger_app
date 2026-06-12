# S7-1 mcp read query mock

## Result

PASS

## Scope

- Branch: `codex/auto-s1-s7-20260612`
- Worktree: `/Users/yu/Flutter_Projects/fleet_ledger_codex_s1s7`
- Baseline before slice: `c70f05d S6 stage report`
- Commit target: `S7-1 mcp read query mock`

## Files

- `lib/features/mcp/use_cases/mcp_read_query_mock.dart`
- `test/features/mcp/use_cases/mcp_read_query_mock_test.dart`

## Implementation

- Added a local, in-memory `McpReadQueryMock` use case.
- Supported mock read query types:
  - devices;
  - projects;
  - receivables;
  - payment status.
- Reused existing operation actor/scope/access-control policies:
  - `ActorContext`;
  - `ActorScope`;
  - `OperationScopePolicy`;
  - `OperationPermissionPolicy`;
  - `OperationVisibilityPolicy`.
- Denied expired scopes, unknown/system actors, and undelegated AI/agent
  actors.
- Restricted partner actors to authorized device-scope device queries only.
- Kept read output privacy-safe by omitting:
  - `project_id`;
  - `share_id`;
  - `device_id`;
  - `local_device_id`;
  - `device_auto_number`;
  - `contact`;
  - `site`;
  - `phone`.
- Kept receivable and payment amounts in integer fen fields only.
- Did not connect a real MCP server, real AI path, external tool call, network
  client, database repository, production data, or cloud account.

## DoD Evidence

- 查询设备: PASS, owner sees device labels and partner sees authorized devices
  only.
- 查询项目: PASS, owner sees project labels without project ids or contact/site
  details.
- 查询应收: PASS, owner sees integer fen receivable fields only.
- 查询收款状态: PASS, owner sees payment status and remaining fen only.
- 权限与隐私测试: PASS, partner project/financial queries are denied, expired
  scopes are denied, undelegated agent actors are denied, and output maps are
  checked for private keys.
- 自动模式只允许 mock MCP / test-only: PASS, implementation is pure in-memory
  test mock with no real MCP or AI write path.

## GitNexus

- `npx gitnexus status`: stale before analysis, indexed commit `821017a`,
  current commit `c70f05d`.
- `npx gitnexus analyze`: PASS,
  `11,641 nodes | 31,154 edges | 686 clusters | 300 flows`.
- `npx gitnexus impact -r /Users/yu/Flutter_Projects/fleet_ledger_codex_s1s7 McpReadQueryMock`:
  LOW, 2 impacted, 1 affected test process.
- `npx gitnexus impact -r /Users/yu/Flutter_Projects/fleet_ledger_codex_s1s7 McpReadLedgerFacts`:
  LOW, 3 impacted, 1 affected test process.
- `npx gitnexus impact -r /Users/yu/Flutter_Projects/fleet_ledger_codex_s1s7 McpReadQueryResult`:
  CRITICAL at default depth 3, with direct hits limited to `_result`,
  `_empty`, and the S7-1 test import. This was treated as a broad transitive
  GitNexus signal rather than a product-rule risk because this slice only adds
  isolated new files and full tests passed.
- `npx gitnexus impact -r /Users/yu/Flutter_Projects/fleet_ledger_codex_s1s7 --depth 1 McpReadQueryResult`:
  LOW, 3 direct impacted.
- `npx gitnexus detect-changes --scope staged -r /Users/yu/Flutter_Projects/fleet_ledger_codex_s1s7`:
  high, 3 files, 69 symbols, 10 affected flows. The affected flow list
  included unrelated existing flows such as `DeleteWriteOff` via common new
  symbols like `McpReadQueryResult`, `_normalize`, and `_queryDevices`. This was
  recorded as a broad GitNexus staged-diff signal; no existing business symbol
  was edited in this slice.

## Verification

- `flutter test test/features/mcp/use_cases/mcp_read_query_mock_test.dart` PASS,
  6 tests.
- `flutter analyze lib test` PASS.
- `dart run custom_lint` PASS.
- `git diff --check` PASS.
- `flutter test` PASS, `+1875 ~3`.

## Invariants

1. `project_id` 是项目身份唯一权威: PASS, no project identity logic changed.
2. FK ON DELETE RESTRICT 生效: PASS, no schema or FK changes.
3. 无孤儿 `project_id`: PASS, no persistence path added.
4. `settled/archived/voided` 不自动匹配: PASS, no matching logic changed.
5. 结清后同名新项目创建新 `project_id`: PASS, no project creation logic changed.
6. 金额/单价整数分: PASS, receivable and payment fields use integer fen.
7. 计量定标整数: PASS, no quantity calculation changed.
8. `AmountPolicy` 单一整数路径: PASS, no amount calculation or policy change.
9. 核心金额无新增 double/float: PASS, no money double/float path added.
10. `hours_milli` 只是 HOUR 特例: PASS, no `hours_milli` logic changed.
11. unit 枚举是数据，不翻译: PASS, no unit presentation logic changed.
12. 确认态是快照，不静默改写: PASS, read-only mock query only.
13. 修改已确认结果走作废/撤销/重建: PASS, no mutation path added.
14. `external_work_records` 与 `timing_records` 分离: PASS, no external work or timing persistence path changed.
15. 外协不污染收入、应收、设备统计: PASS, no aggregation logic changed.
16. source/local/export 三层单价互不覆盖: PASS, no price layer logic changed.
17. 外部记录不可硬删: PASS, no delete path added.
18. `.jztshare` 防御式解析、hash 校验、事务化: PASS, no share parser changes.
19. 分享包不含手机号、通讯录、本机 `device_id`、设备自动编号: PASS, mock output omits private local/device identifiers.
20. 填报/同步/AI 写入进入 pending: PASS, this slice is read-only and adds no write path.
21. UI 不暴露 `project_id/share_id`: PASS, no UI changed; mock output omits project/share ids.
22. UI 不使用会计/债务术语: PASS, no UI copy added.
23. 新文案尽量走 i18n key: PASS, no UI text added.
24. 迁移同步 backup normalize / sync coverage / canary: PASS, no migration or backup path changed.

## Risk Notes

- No high-risk action was taken: no schema migration, destructive operation,
  real MCP service, real AI write, real external tool call, real cloud account,
  dependency addition, signing, CI, secrets, push, or merge.
- `npx gitnexus analyze` temporarily modified `AGENTS.md` and `CLAUDE.md` with
  generated GitNexus metadata. Those generated changes were reverted and are not
  part of this slice.
- Production MCP integration and AI write execution remain explicitly out of
  scope and require separate approval.
- GitNexus staged detection reported `high` because the new isolated mock file
  introduced many new symbols and generic helper names. Direct depth-limited
  impact remained LOW, and validation passed.
