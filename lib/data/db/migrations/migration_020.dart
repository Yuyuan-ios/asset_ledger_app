part of '../db_migrations.dart';

/// v20：external_work_records 增加来源项目累计实收款快照。
class Migration020 {
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 20) {
      await ensureExternalWorkProjectReceivedFen(db);
    }
  }

  /// 幂等：DbSchemaCompat.ensure 调用以兜底已升级过的库。
  static Future<void> ensureExternalWorkProjectReceivedFen(Database db) async {
    if (!await _tableExists(db, 'external_work_records')) return;
    final columns = await db.rawQuery(
      'PRAGMA table_info(external_work_records);',
    );
    final hasColumn = columns.any((row) {
      return row['name'] == 'project_received_fen';
    });
    if (hasColumn) return;

    await db.execute('''
      ALTER TABLE external_work_records
      ADD COLUMN project_received_fen INTEGER NOT NULL DEFAULT 0
        CHECK (project_received_fen >= 0);
    ''');
  }
}
