# Money REAL Migration Plan

Current compatibility fields that still store financial values as `REAL`:

| Table/source | Field | Current type | Risk | Migration strategy |
| --- | --- | --- | --- | --- |
| `devices` | `default_unit_price` | `REAL` | medium | add `default_unit_price_fen INTEGER`, read legacy fallback |
| `devices` | `breaking_unit_price` | `REAL` | medium | add `breaking_unit_price_fen INTEGER`, read legacy fallback |
| `fuel_logs` | `cost` | `REAL` | medium | add `cost_fen INTEGER`, keep `liters REAL` as non-money |
| `maintenance_records` | `amount` | `REAL` | high | add `amount_fen INTEGER`, backfill rounded fen |
| `account_payments` | `amount` | `REAL` | high | add `amount_fen INTEGER`, backfill rounded fen |
| `account_payments` | `merge_batch_total_amount` | `REAL` | high | add `merge_batch_total_amount_fen INTEGER`, backfill with nullable fallback |
| `project_write_offs` | `amount` | `REAL` | high | add `amount_fen INTEGER`, backfill rounded fen |
| `timing_records` | `income` | `REAL` | high | add `income_fen INTEGER`; keep rent legacy fallback and prefer recalculated work income |
| `project_device_rates` | rate fields | `REAL` | medium | add `*_fen INTEGER` per hour, keep legacy fallback |

Non-money `REAL` fields such as meters, hours, liters, and calculator
intermediate results remain `REAL` by design.

Rules for new code:

- New sync/share/work-record fields must use `*_fen INTEGER`.
- Domain finance calculation continues through `ProjectFinanceCalculator` and
  integer fen/milli-hour conversion.
- UI display continues through `MoneyFormatter` or `FormatUtils.money`.
- Historical `REAL` fields stay readable until a dedicated migration/backfill
  release is validated on production-like backups.
