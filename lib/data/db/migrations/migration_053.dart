part of '../db_migrations.dart';

/// v53：为历史 hours 计时记录补齐项目级单价快照。
///
/// 只补缺失的 (project_id, device_id, is_breaking)，不覆盖已有项目价。
/// 快照值来自迁移时的设备默认价；破碎记录优先使用破碎默认价，缺省回落普通默认价。
class Migration053 {
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 53) {
      await ensureProjectRateSnapshots(db);
    }
  }

  static Future<void> ensureProjectRateSnapshots(Database db) async {
    if (!await _hasRequiredTables(db)) return;
    if (!await _hasRequiredColumns(db)) return;

    await db.execute('''
      INSERT OR IGNORE INTO project_device_rates (
        project_id,
        project_key,
        device_id,
        is_breaking,
        rate_fen
      )
      SELECT
        source.project_id,
        COALESCE(NULLIF(projects.legacy_project_key, ''), source.project_key),
        source.device_id,
        source.is_breaking,
        CASE
          WHEN source.is_breaking = 1 THEN
            COALESCE(devices.breaking_unit_price_fen, devices.default_unit_price_fen)
          ELSE devices.default_unit_price_fen
        END
      FROM (
        SELECT DISTINCT
          project_id,
          contact || '||' || site AS project_key,
          device_id,
          COALESCE(is_breaking, 0) AS is_breaking
        FROM timing_records
        WHERE type = 'hours' AND TRIM(project_id) <> ''
      ) AS source
      INNER JOIN projects ON projects.id = source.project_id
      INNER JOIN devices ON devices.id = source.device_id
      WHERE NOT EXISTS (
        SELECT 1
        FROM project_device_rates AS existing
        WHERE existing.project_id = source.project_id
          AND existing.device_id = source.device_id
          AND existing.is_breaking = source.is_breaking
      );
    ''');
  }

  static Future<bool> _hasRequiredTables(Database db) async {
    return await _tableExists(db, 'timing_records') &&
        await _tableExists(db, 'devices') &&
        await _tableExists(db, 'projects') &&
        await _tableExists(db, 'project_device_rates');
  }

  static Future<bool> _hasRequiredColumns(Database db) async {
    return await _columnExists(db, 'timing_records', 'project_id') &&
        await _columnExists(db, 'timing_records', 'contact') &&
        await _columnExists(db, 'timing_records', 'site') &&
        await _columnExists(db, 'timing_records', 'device_id') &&
        await _columnExists(db, 'timing_records', 'type') &&
        await _columnExists(db, 'timing_records', 'is_breaking') &&
        await _columnExists(db, 'devices', 'id') &&
        await _columnExists(db, 'devices', 'default_unit_price_fen') &&
        await _columnExists(db, 'devices', 'breaking_unit_price_fen') &&
        await _columnExists(db, 'projects', 'id') &&
        await _columnExists(db, 'projects', 'legacy_project_key') &&
        await _columnExists(db, 'project_device_rates', 'project_id') &&
        await _columnExists(db, 'project_device_rates', 'project_key') &&
        await _columnExists(db, 'project_device_rates', 'device_id') &&
        await _columnExists(db, 'project_device_rates', 'is_breaking') &&
        await _columnExists(db, 'project_device_rates', 'rate_fen');
  }
}
