import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/services/local_backup_export_service.dart';
import 'package:asset_ledger/data/services/local_backup_import_preview_service.dart';
import 'package:asset_ledger/data/services/local_backup_restore_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../../test_setup.dart';

/// R5.26-B3：legacy backup restore 的 timing_records.income_fen 回填不变式。
///
/// 钉死：一个 timing_records 缺 income_fen 的旧备份经 restore 后，income_fen 被
/// 回填为非 NULL（round(income*100)），且 restore 不因缺列失败、不影响其它字段。
/// 不触碰 restore reconcile / push gate 逻辑。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  setUp(() async {
    await AppDatabase.resetForTest();
    AppDatabase.debugInitDbOverride = () {
      return openDatabase(
        inMemoryDatabasePath,
        version: AppDatabase.schemaVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, _) => DbSchema.create(db),
      );
    };
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  test(
    'legacy backup without income_fen restores timing_records with non-null '
    'backfilled fen and does not fail',
    () async {
      final restoreService = LocalBackupRestoreService(
        previewService: const LocalBackupImportPreviewService(),
        exportBackup: () async => const LocalBackupExportResult(
          success: true,
          filePath: '/tmp/pre-restore-stub.json',
          fileName: 'pre-restore-stub.json',
        ),
      );

      final result = await restoreService.restoreFromDecodedJson(
        _buildLegacyTimingBackupMissingIncomeFen(),
      );
      expect(
        result.success,
        isTrue,
        reason: '缺 income_fen 的旧备份不应导致 restore 失败：${result.message}',
      );

      final db = await AppDatabase.database;
      final rows = await db.query('timing_records', orderBy: 'id ASC');
      expect(rows.length, 3);

      // 无 NULL income_fen + 逐行回填正确。
      for (final row in rows) {
        final income = (row['income'] as num).toDouble();
        expect(
          (row['income_fen'] as num?)?.toInt(),
          (income * 100).round(),
          reason: 'timing_records ${row['id']} income_fen 应 == round(income*100)',
        );
      }
      // 其它字段未受影响。
      final first = rows.first;
      expect(first['hours'], 8.0);
      expect(first['type'], 'hours');
      expect(first['contact'], '甲方');
    },
  );
}

Map<String, dynamic> _buildLegacyTimingBackupMissingIncomeFen() {
  return <String, dynamic>{
    'meta': <String, dynamic>{
      'app_name': 'FleetLedger',
      'app_version': 'test',
      'export_format_version': 2,
      'schema_version': AppDatabase.schemaVersion,
      'exported_at': '2026-06-01T00:00:00.000Z',
    },
    'data': <String, dynamic>{
      'projects': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'project:restore',
          'contact': '甲方',
          'site': '回灌工地',
          'status': 'active',
          'created_at': '2026-06-01T00:00:00.000Z',
          'updated_at': '2026-06-01T00:00:00.000Z',
          'legacy_project_key': '甲方||回灌工地',
        },
      ],
      'devices': <Map<String, dynamic>>[],
      'timing_records': <Map<String, dynamic>>[
        // 缺 income_fen：hours 记录。
        _timingRecord(id: 1, income: 200.0, type: 'hours'),
        _timingRecord(id: 2, income: 19.99, type: 'hours'),
        // 缺 income_fen：rent 记录。
        _timingRecord(id: 3, income: 1200.0, type: 'rent'),
      ],
      'fuel_logs': <Map<String, dynamic>>[],
      'maintenance_records': <Map<String, dynamic>>[],
      'account_payments': <Map<String, dynamic>>[],
      'project_write_offs': <Map<String, dynamic>>[],
      'project_device_rates': <Map<String, dynamic>>[],
      'timing_calculation_history': <Map<String, dynamic>>[],
      'account_project_merge_groups': <Map<String, dynamic>>[],
      'account_project_merge_members': <Map<String, dynamic>>[],
      'external_import_batches': <Map<String, dynamic>>[],
      'external_work_records': <Map<String, dynamic>>[],
    },
  };
}

Map<String, dynamic> _timingRecord({
  required int id,
  required double income,
  required String type,
}) {
  return <String, dynamic>{
    'id': id,
    'project_id': 'project:restore',
    'device_id': 7,
    'start_date': 20260601,
    'contact': '甲方',
    'site': '回灌工地',
    'type': type,
    'start_meter': 100.0,
    'end_meter': 108.0,
    'hours': 8.0,
    'income': income,
    'exclude_from_fuel_eff': 0,
    'is_breaking': 0,
    // 故意不含 income_fen。
  };
}
