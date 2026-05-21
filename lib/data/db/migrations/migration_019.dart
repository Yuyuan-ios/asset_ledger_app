part of '../db_migrations.dart';

/// v19：放开 external_work_records 单价列的 NOT NULL，并新增 record_kind。
///
/// 设计：rich 富 records 路径下，单价可能未知（rent / 人工覆写金额 / 设备缺失），
/// 0 已被语义占用为"真实单价为 0"，故未知必须用 null。SQLite 不支持
/// ALTER COLUMN，使用 create-copy-rename 重建表。
class Migration019 {
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 19) {
      await ensureNullableExternalWorkUnitPrice(db);
    }
  }

  /// 幂等：DbSchemaCompat.ensure 调用以兜底已升级过的库。
  /// 判定标准：若 source_unit_price_fen 仍为 NOT NULL 或缺少 record_kind 列，
  /// 则执行表重建；否则跳过。
  static Future<void> ensureNullableExternalWorkUnitPrice(Database db) async {
    if (!await _tableExists(db, 'external_work_records')) return;

    final columns = await db.rawQuery(
      'PRAGMA table_info(external_work_records);',
    );
    final byName = {for (final row in columns) row['name'] as String: row};
    final sourceCol = byName['source_unit_price_fen'];
    final localCol = byName['local_unit_price_fen'];
    final hasRecordKind = byName.containsKey('record_kind');
    final sourceNotNull = ((sourceCol?['notnull'] as int?) ?? 0) == 1;
    final localNotNull = ((localCol?['notnull'] as int?) ?? 0) == 1;
    if (!sourceNotNull && !localNotNull && hasRecordKind) return;

    await db.execute('''
      CREATE TABLE external_work_records__v19 (
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

    // 历史数据全部走 legacy 路径，单价非空、record_kind='hours' 是正确口径。
    await db.execute('''
      INSERT INTO external_work_records__v19 (
        id, import_batch_id, source_share_id, source_record_uuid,
        source_installation_uuid, origin_fingerprint, collaborator_name,
        contact_snapshot, site_snapshot, equipment_brand, equipment_model,
        equipment_type, work_date, hours_milli, source_unit_price_fen,
        local_unit_price_fen, amount_fen, linked_project_id, record_kind,
        status, note, created_at, updated_at
      )
      SELECT
        id, import_batch_id, source_share_id, source_record_uuid,
        source_installation_uuid, origin_fingerprint, collaborator_name,
        contact_snapshot, site_snapshot, equipment_brand, equipment_model,
        equipment_type, work_date, hours_milli, source_unit_price_fen,
        local_unit_price_fen, amount_fen, linked_project_id, 'hours',
        status, note, created_at, updated_at
      FROM external_work_records;
    ''');

    await db.execute('DROP TABLE external_work_records;');
    await db.execute(
      'ALTER TABLE external_work_records__v19 RENAME TO external_work_records;',
    );

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
