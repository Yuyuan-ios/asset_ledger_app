# S4-3 price layers lineage audit

## Result

PASS

## Scope

- Branch: `codex/auto-s1-s7-20260612`
- Worktree: `/Users/yu/Flutter_Projects/fleet_ledger_codex_s1s7`
- Baseline before slice: `aaa9711 S4-2 share privacy whitelist`
- Commit target: `S4-3 price layers lineage audit`

## Files

- `lib/data/share/jztshare/project_external_work_import_preview.dart`
- `test/data/share/jztshare/project_external_work_rich_import_test.dart`
- `test/features/timing/view_models/external_work_records_view_model_test.dart`
- `test/features/device/domain/services/device_business_ledger_test.dart`

## Implementation

- Rich import preview now maps `source_unit_price_fen` only to
  `sourceUnitPriceFen`.
- Rich import preview leaves `localUnitPriceFen` null on first import because it
  belongs to the receiver's local review / payable layer.
- Existing legacy `export_lines[]` import behavior remains unchanged: legacy
  lines still seed local price from the legacy source price.
- Timing external-work detail tests now prove `localUnitPriceFen` is never used
  as a fallback for source unit price display.
- Device business ledger tests now prove merged account project names are used
  for device history rows and lower-level member worker names do not pass
  through the aggregation.

## DoD Evidence

- Source price is preserved end-to-end for rich records.
- Local override is not silently created from source price during rich import.
- Source price display stays source-only when source and local differ.
- Source price display stays `未知` when source is null, even if local is set.
- Device business ledger displays `业主甲 · 合并2项目` for merged project history
  and does not expose `外协工人...` member names.

## Impact Analysis

- `ExternalWorkRecord`: LOW / partial impact result; GitNexus reported a
  read-only pool write issue while analyzing, but no production edit was made
  to this model.
- `ExternalWorkImportPreviewLine`: MEDIUM, 23 impacted symbols, 0 affected
  processes.
- `ExternalWorkRecordsViewModelBuilder`: MEDIUM, 19 impacted symbols, 2
  affected processes (`timing_home_pattern`, `external_work_records_pattern`).
- `DeviceBusinessLedgerUseCase` / `DeviceBusinessLedger`: target was not found
  in the current GitNexus index, likely because the S3 code is newer than the
  index; this slice adds tests only for that production path.
- `npx gitnexus detect-changes --scope all -r /Users/yu/Flutter_Projects/fleet_ledger_codex_s1s7` after implementation reported:
  - 4 files, 2 symbols
  - 0 affected processes
  - risk level: low
- `npx gitnexus detect-changes --scope staged -r /Users/yu/Flutter_Projects/fleet_ledger_codex_s1s7` before commit reported:
  - 5 files, 2 symbols
  - 0 affected processes
  - risk level: low

## Verification

- `flutter test test/data/share/jztshare/project_external_work_rich_import_test.dart test/features/timing/view_models/external_work_records_view_model_test.dart test/features/device/domain/services/device_business_ledger_test.dart` PASS (`+38`)
- `flutter test test/data/share/jztshare test/patterns/timing/external_work_unit_price_text_test.dart test/features/timing/view/timing_page_calculation_history_test.dart test/features/account/domain/services/external_work_detail_rows_test.dart test/features/device/domain/services/device_business_ledger_test.dart` PASS (`+148`)
- `flutter analyze lib test` PASS
- `dart run custom_lint` PASS
- `git diff --check` PASS
- `flutter test` PASS (`+1851 ~3`)

## Risk Notes

- No database schema, migration, backup format, sync protocol, cloud/secrets,
  release, push, or merge action was performed.
- No settlement/write-off production code was changed.
- No share export privacy whitelist, fingerprint version, or file format field
  was changed in this slice.
- GitNexus change detection reported LOW, not HIGH/CRITICAL. No OpenClaw
  high-risk approval was triggered for this slice.
