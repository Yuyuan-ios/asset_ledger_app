# S2-2 entry template phase A

## Conclusion

PASS.

This slice adds the first timing entry-template layer and wires the existing
timing entry sheet through it. The implementation stays in template/presentation
code: no database schema, migration, `Device` model, statistics, settlement,
sharing, or sync semantics were changed.

## Scope

- Branch: `codex/auto-s1-s7-20260612`
- Worktree: `/Users/yu/Flutter_Projects/fleet_ledger_codex_s1s7`
- Baseline commit before this slice: `b7a3240`
- Slice: `S2-2 entry template phase A`

## Changed Files

- `lib/features/timing/domain/services/timing_entry_template.dart`
  - Added phase-A templates for `excavator`, `loader`, `roller`, and `crane`.
  - Added unit layout metadata for HOUR and legacy RENT, including mode label,
    quantity label, unit-price label, and meter-layout flag.
  - Added template-level `energyType` handling, including `NONE` hiding rules.
- `lib/patterns/timing/timing_detail_content_pattern.dart`
  - Added optional template resolver injection.
  - Mode labels and quantity labels now come from the selected unit layout.
  - Energy exclusion is written only when the template exposes that control.
- `lib/features/timing/presentation/widgets/timing_detail/timing_detail_form_sections.dart`
  - Connected the mode selector labels to HOUR/RENT unit layouts.
- `lib/patterns/timing/exclude_fuel_switch_card_pattern.dart`
  - Made title/description configurable while keeping backwards-compatible
    defaults for existing callers.
- `test/features/timing/domain/services/timing_entry_template_test.dart`
  - Covers phase-A four-template definitions, HOUR/RENT labels, unit-price
    labels, and `EnergyType.none`.
- `test/patterns/timing_detail_content_pattern_test.dart`
  - Covers fuel label rendering and NONE-energy hiding/submission behavior.

## DoD Evidence

- Template = equipment type -> unit -> entry layout:
  - `TimingEntryTemplates.phaseA` defines the four template keys and unit
    layouts.
- Existing excavator/loader entry paths remain on the current sheet:
  - Existing timing detail widget regression tests still pass.
- HOUR remains meter-backed:
  - Phase-A HOUR layout has `usesMeter = true`; the current field continues to
    open the work-hour calculator.
- Unit labels are template-backed:
  - Mode selector and quantity field labels read from HOUR/RENT layouts.
- `energy_type=NONE` hides the energy marker:
  - Widget test confirms no marker is shown and stale `excludeFromFuelEfficiency`
    is not submitted.

## Validation

- `flutter test test/features/timing/domain/services/timing_entry_template_test.dart`
  - PASS, `All tests passed!`
- `flutter test test/patterns/timing_detail_content_pattern_test.dart`
  - PASS, `All tests passed!`
- `flutter analyze lib test`
  - PASS, `No issues found!`
- `dart run custom_lint`
  - PASS, `No issues found!`
- `git diff --check`
  - PASS
- `flutter test`
  - PASS, `All tests passed!`, final count `+1828 ~3`
- `npx gitnexus detect-changes --scope all -r /Users/yu/Flutter_Projects/fleet_ledger_codex_s1s7`
  - PASS, risk `low`, affected processes `0`

## Invariant Self-Check

- No schema or migration change.
- `project_id` identity and FK behavior unchanged.
- AmountPolicy and integer fen path unchanged.
- No new double/float money calculation path.
- `unit` and `energy_type` remain data; labels are display metadata only.
- External work remains separated from timing records.
- No sharing, settlement, write-off, sync, or cloud behavior changed.
- UI still does not expose `project_id` or `share_id`.

## Risks And Residuals

- `Device` has critical blast radius, so this slice deliberately avoids adding
  new `EquipmentType` enum values or DB fields. The `roller` and `crane`
  template keys are ready but not exposed through the current device picker.
- SHIFT/TON/TRIP/MU/ACRE/HECTARE and `aux_raw` are deferred to S2-3 by design.
- No OpenClaw high-risk approval was required for this low-risk presentation
  and template-layer slice.

## Next

S2-2 allows continuing to S2-3 (`multi unit templates phase B`) after commit if
the branch remains clean and no high-risk item is pending.
