# DB Migrations Split Plan

Current state: `lib/data/db/db_migrations.dart` remains the migration runner and
is still the largest data-layer file.

Planned split without changing execution order:

| Target file | Responsibility | Versions |
| --- | --- | --- |
| `lib/data/db/migrations/migration_runner.dart` | Public runner and version dispatch | all |
| `lib/data/db/migrations/migration_001_010.dart` | legacy bootstrap and early schema repair | 1-10 |
| `lib/data/db/migrations/migration_011_017.dart` | project id, calculation history, sync schema | 11-17 |
| `lib/data/db/migrations/migration_helpers.dart` | idempotent column/table/index helpers | shared |

Guardrails:

- Keep `AppDatabase.schemaVersion` at 17 until a new schema change is required.
- Move code by version range only; do not reorder existing `if (oldVersion < n)`
  checks.
- Preserve v17 `sync_outbox`, `sync_state`, `entity_sync_meta`, and
  `work_records` creation.
- Run `test/data/db/db_migrations_test.dart` plus full `flutter test` after each
  range extraction.

