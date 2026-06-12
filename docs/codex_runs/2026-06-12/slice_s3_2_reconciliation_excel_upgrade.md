# S3-2 Reconciliation Excel Upgrade

## Result

- Status: PASS
- Branch: `codex/auto-s1-s7-20260612`
- Worktree: `/Users/yu/Flutter_Projects/fleet_ledger_codex_s1s7`
- Baseline before slice: `3d2c914 S3-1 device business ledger`

## Scope

- Upgraded the timing worklog export into a project reconciliation detail report.
- Added multi-unit row fields: quantity, unit, unit price, and amount.
- Added report-scope filters for project, device, and date range.
- Added signature, invoice fields, and an explicit calculation-basis footer.
- Removed the hard-coded "excavator" title from report title, workbook metadata, share subject, and generated file names.
- Kept external work out of owned receivable reports by default; external rows require explicit opt-in.

## Files

- `lib/features/account/view/account_page.dart`
- `lib/features/reports/models/timing_worklog_report.dart`
- `lib/features/reports/use_cases/build_timing_worklog_report_use_case.dart`
- `lib/features/reports/use_cases/export_timing_worklog_excel_use_case.dart`
- `lib/features/reports/infrastructure/timing_worklog_excel_writer.dart`
- `test/features/reports/timing_worklog_excel_export_test.dart`

## DoD Evidence

- Multi-unit rows now carry `quantityScaled`, `MeasureUnit`, `unitPriceFen`, and `amountFen`.
- Local row amount uses `AmountPolicy.calculateAmountForQuantity(quantity_scaled, unit_price_fen)`.
- Unit prices come from `AccountService.buildEffectiveRateFenMap`, preserving project/device override and breaking-rate behavior.
- Excel columns now separate quantity, unit, unit price, and amount.
- Totals summarize quantities by unit instead of forcing all units into hours.
- `TimingWorklogExportScope.filtered` supports project/device/date range filters.
- Signature, invoice fields, and the S3-2 calculation-basis footer are printed on every page.
- External work is excluded by default and only included when `includeExternalWork: true`.

## Validation

- `flutter test test/features/reports/timing_worklog_excel_export_test.dart`: PASS (`+13`)
- `flutter test test/patterns/account_project_list_pattern_test.dart test/features/account/view/account_page_external_work_tabs_test.dart`: PASS
- `flutter analyze lib test`: PASS (`No issues found!`)
- `dart run custom_lint`: PASS (`No issues found!`)
- `git diff --check`: PASS
- `flutter test`: PASS (`+1840 ~3`)
- `npx gitnexus detect-changes --scope all -r /Users/yu/Flutter_Projects/fleet_ledger_codex_s1s7`: PASS (`6 files`, `45 symbols`, `2` affected processes, `medium` risk)

## Invariants

- No schema or migration changes.
- No timing save/import/share protocol changes.
- No `external_work` to `timing_records` write-path changes.
- No `AmountPolicy` changes.
- No `AccountService` changes.
- No cloud, secret, push, merge, release, or production-data operation.

## OpenClaw

- No new high-risk approval was required for this slice.
- Rationale: change detection reported medium risk, affected flows are limited to report/export paths and tests, and full gates passed.

## Residual Risk

- Device/date filtering is available at the export use-case scope level; this slice does not add new UI controls for those filters.
- Explicit external-work opt-in remains available for export tests and future workflows, but account-page owned receivable export uses the default exclusion behavior.
