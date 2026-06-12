# S2-3 multi unit templates phase B

## Conclusion

PASS.

This slice adds phase-B timing entry-template definitions for crane, transport,
concrete pump, and plant-protection drone units. It also adds a domain draft for
normalizing direct, parcel-sum, and sortie-area inputs into `quantity_scaled`
plus `aux_raw` metadata. The slice does not connect these templates to the
production timing entry UI and does not change database schema or migrations.

## Scope

- Branch: `codex/auto-s1-s7-20260612`
- Worktree: `/Users/yu/Flutter_Projects/fleet_ledger_codex_s1s7`
- Baseline commit before this slice: `adc4d41`
- Slice: `S2-3 multi unit templates phase B`

## Changed Files

- `lib/features/timing/domain/services/timing_entry_template.dart`
  - Added SHIFT, TON, TRIP, CUBIC_METER, MU, ACRE, and HECTARE entry layouts.
  - Added phase-B template declarations:
    - crane: SHIFT / TON / TRIP
    - transport: TRIP / CUBIC_METER / HOUR
    - concrete pump: TRIP / CUBIC_METER / HOUR
    - plant-protection drone: MU / ACRE / HECTARE
  - Added `TimingEntryQuantityDraft` for direct quantity, parcel-sum area, and
    sortie-area product inputs.
  - Kept amount calculation on `AmountPolicy.calculateAmountForQuantity`.
- `test/features/timing/domain/services/timing_entry_template_test.dart`
  - Covers phase-B unit layout definitions and labels.
  - Covers `aux_raw` source metadata for direct, parcel-sum, and
    sortie-area-product inputs.
  - Covers stats using `quantity_scaled` and sample amount calculations for MU,
    TRIP, and SHIFT.

## DoD Evidence

- Crane supports SHIFT / TON / TRIP:
  - `craneMultiUnit` defines those three layouts, all without meter input.
- Transport and concrete pump support TRIP / CUBIC_METER / HOUR:
  - `transport` and `concretePump` share the transport phase-B unit set.
  - HOUR remains meter-backed; TRIP and CUBIC_METER are direct quantity units.
- Plant-protection drone supports MU / ACRE / HECTARE:
  - `plantProtectionDrone` defines the three area units and electric energy
    marker copy.
- Plant-protection quantity sources are normalized:
  - `TimingEntryQuantityDraft.direct` stores direct input.
  - `TimingEntryQuantityDraft.parcelAreaSum` stores parcel scaled values.
  - `TimingEntryQuantityDraft.sortieAreaProduct` stores sortie count and
    per-sortie area.
- Statistics use `quantity_scaled`:
  - Tests assert two different `aux_raw` shapes with the same quantity expose
    the same `statQuantityScaled`.
- Money uses the canonical integer path:
  - Tests cover 12.5 MU x 8000 fen, 3 TRIP x 35000 fen, and 1.5 SHIFT x
    120000 fen via `AmountPolicy.calculateAmountForQuantity`.

## Validation

- `flutter test test/features/timing/domain/services/timing_entry_template_test.dart`
  - PASS, `All tests passed!`
- `flutter test test/patterns/timing_detail_content_pattern_test.dart test/core/money/amount_policy_test.dart`
  - PASS, `All tests passed!`
- `flutter analyze lib test`
  - PASS, `No issues found!`
- `dart run custom_lint`
  - PASS, `No issues found!`
- `git diff --check`
  - PASS
- `flutter test`
  - PASS, `All tests passed!`, final count `+1835 ~3`
- `npx gitnexus detect-changes --scope all -r /Users/yu/Flutter_Projects/fleet_ledger_codex_s1s7`
  - PASS, risk `low`, affected processes `0`

## Invariant Self-Check

- No schema or migration change.
- No production UI route exposes the phase-B templates yet.
- Existing `TimingEntryTemplates.forDevice` still resolves only phase-A device
  templates.
- `project_id` identity and FK behavior unchanged.
- AmountPolicy and integer fen path unchanged.
- No new double/float money calculation path.
- `quantity_scaled` remains the stats authority; `aux_raw` is auxiliary input
  provenance only.
- External work remains separated from timing records.
- No sharing, settlement, write-off, sync, cloud, backup, or restore behavior
  changed.
- UI still does not expose `project_id` or `share_id`.

## Risks And Residuals

- The `aux_raw` support added here is an in-memory domain draft. Persisting
  `aux_raw` into `timing_records` would be a schema/migration decision and is
  intentionally deferred to a separately approved migration slice.
- Phase-B templates are declared but not routed into the current production
  entry sheet. That keeps this slice low risk and avoids changing current
  device-type persistence.
- No OpenClaw high-risk approval was required for this low-risk domain-template
  slice.

## Next

S2-3 completes the S2 implementation slices. The next action is to generate the
S2 stage report and run the stage-level gate before moving to S3.
