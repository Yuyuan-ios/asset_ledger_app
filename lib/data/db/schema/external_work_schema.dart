import 'package:sqflite/sqflite.dart';

/// external work import tables.
class ExternalWorkSchema {
  static Future<void> create(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS external_import_batches (
        id TEXT PRIMARY KEY,
        source_share_id TEXT NOT NULL,
        source_display_name TEXT NOT NULL,
        record_count INTEGER NOT NULL DEFAULT 0 CHECK (record_count >= 0),
        total_hours_milli INTEGER NOT NULL DEFAULT 0
          CHECK (total_hours_milli >= 0),
        total_amount_fen INTEGER NOT NULL DEFAULT 0
          CHECK (total_amount_fen >= 0),
        site_summary TEXT NOT NULL DEFAULT '',
        imported_at TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'active'
          CHECK (status IN ('active', 'ignored', 'archived', 'voided')),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_external_import_batches_source_share
      ON external_import_batches(source_share_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_external_import_batches_status
      ON external_import_batches(status);
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS external_work_records (
        id TEXT PRIMARY KEY,
        import_batch_id TEXT NOT NULL,
        source_share_id TEXT NOT NULL,
        source_record_uuid TEXT NOT NULL,
        source_installation_uuid TEXT NOT NULL,
        origin_fingerprint TEXT NOT NULL,
        collaborator_name TEXT NOT NULL,
        contact_snapshot TEXT NOT NULL,
        site_snapshot TEXT NOT NULL,
        equipment_brand TEXT,
        equipment_model TEXT,
        equipment_type TEXT,
        work_date INTEGER NOT NULL,
        hours_milli INTEGER NOT NULL CHECK (hours_milli >= 0),
        source_unit_price_fen INTEGER
          CHECK (source_unit_price_fen IS NULL OR source_unit_price_fen >= 0),
        local_unit_price_fen INTEGER
          CHECK (local_unit_price_fen IS NULL OR local_unit_price_fen >= 0),
        amount_fen INTEGER NOT NULL CHECK (amount_fen >= 0),
        linked_project_id TEXT,
        record_kind TEXT NOT NULL DEFAULT 'hours'
          CHECK (record_kind IN ('hours', 'rent')),
        status TEXT NOT NULL DEFAULT 'active'
          CHECK (status IN ('active', 'ignored', 'archived', 'voided')),
        note TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (import_batch_id)
          REFERENCES external_import_batches(id) ON DELETE RESTRICT,
        FOREIGN KEY (linked_project_id)
          REFERENCES projects(id) ON DELETE RESTRICT
      );
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_external_work_records_source_record
      ON external_work_records(source_share_id, source_record_uuid);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_external_work_records_batch
      ON external_work_records(import_batch_id, work_date);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_external_work_records_linked_project
      ON external_work_records(linked_project_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_external_work_records_status
      ON external_work_records(status);
    ''');
  }
}
