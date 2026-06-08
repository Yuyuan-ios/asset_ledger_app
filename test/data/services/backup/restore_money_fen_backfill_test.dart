import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/services/local_backup_export_service.dart';
import 'package:asset_ledger/data/services/local_backup_import_preview_service.dart';
import 'package:asset_ledger/data/services/local_backup_restore_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../../test_setup.dart';

/// R5.26-B0.5：legacy backup restore 的 money fen no-NULL 安全网（test-only）。
///
/// 钉死：一个**缺 amount_fen** 的旧备份（account_payments / project_write_offs
/// 只有 REAL amount）经 restore 后，两表 amount_fen 一律被回填为非 NULL，且
/// restore 不因缺列而失败。这是 R5.26-B1/B2 把这两列改 NOT NULL 前，restore
/// 路径侧的前置保障——避免「旧备份回灌出 NULL fen」在 NOT NULL 落地后炸库。
///
/// 不改 restore reconcile / push gate 逻辑，仅断言现有 normalize 回填行为。
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
    'legacy backup without amount_fen restores both money tables with non-null '
    'backfilled fen and does not fail',
    () async {
      final backupJson = _buildLegacyMoneyBackupMissingFen();

      final restoreService = LocalBackupRestoreService(
        previewService: const LocalBackupImportPreviewService(),
        // 桩掉 restore 前的自动备份，避免依赖文件系统。
        exportBackup: () async => const LocalBackupExportResult(
          success: true,
          filePath: '/tmp/pre-restore-stub.json',
          fileName: 'pre-restore-stub.json',
        ),
      );

      final result = await restoreService.restoreFromDecodedJson(backupJson);
      expect(
        result.success,
        isTrue,
        reason: '缺 amount_fen 的旧备份不应导致 restore 失败：${result.message}',
      );

      final db = await AppDatabase.database;

      // 核心不变式：两表均无 NULL amount_fen。
      expect(await _nullFenCount(db, 'account_payments'), 0);
      expect(await _nullFenCount(db, 'project_write_offs'), 0);

      // 行数与回填值正确。
      final payments = await db.query('account_payments', orderBy: 'id ASC');
      expect(payments.length, 3);
      for (final row in payments) {
        final amount = (row['amount'] as num).toDouble();
        expect(
          (row['amount_fen'] as num?)?.toInt(),
          (amount * 100).round(),
          reason: 'account_payments ${row['id']} fen 应 == round(amount*100)',
        );
      }

      // merge 行的 merge_batch_total_amount_fen 也被回填。
      final mergeRow = payments.firstWhere((row) => row['id'] == 3);
      expect(mergeRow['source_type'], 'merge_allocation');
      expect(
        (mergeRow['merge_batch_total_amount_fen'] as num?)?.toInt(),
        ((mergeRow['merge_batch_total_amount'] as num).toDouble() * 100).round(),
      );

      final writeOffs = await db.query('project_write_offs', orderBy: 'id ASC');
      expect(writeOffs.length, 2);
      for (final row in writeOffs) {
        final amount = (row['amount'] as num).toDouble();
        expect(
          (row['amount_fen'] as num?)?.toInt(),
          (amount * 100).round(),
          reason: 'project_write_offs ${row['id']} fen 应 == round(amount*100)',
        );
        // REAL amount 兼容列仍保留原值。
        expect(amount > 0, isTrue);
      }
    },
  );
}

Future<int> _nullFenCount(DatabaseExecutor db, String table) async {
  final rows = await db.rawQuery(
    'SELECT COUNT(*) AS c FROM $table WHERE amount_fen IS NULL',
  );
  return (rows.single['c'] as num?)?.toInt() ?? 0;
}

/// 构造一个 schema 合法、但 account_payments / project_write_offs 行**缺
/// amount_fen** 的旧备份（export_format_version 2，app_name FleetLedger）。
Map<String, dynamic> _buildLegacyMoneyBackupMissingFen() {
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
      'timing_records': <Map<String, dynamic>>[],
      'fuel_logs': <Map<String, dynamic>>[],
      'maintenance_records': <Map<String, dynamic>>[],
      'account_payments': <Map<String, dynamic>>[
        // 缺 amount_fen：普通收款。
        <String, dynamic>{
          'id': 1,
          'project_id': 'project:restore',
          'project_key': '甲方||回灌工地',
          'ymd': 20260601,
          'amount': 123.45,
          'source_type': 'manual',
        },
        <String, dynamic>{
          'id': 2,
          'project_id': 'project:restore',
          'project_key': '甲方||回灌工地',
          'ymd': 20260602,
          'amount': 0.1,
          'source_type': 'manual',
        },
        // 缺 amount_fen + 缺 merge_batch_total_amount_fen：合并分摊收款。
        <String, dynamic>{
          'id': 3,
          'project_id': 'project:restore',
          'project_key': '甲方||回灌工地',
          'ymd': 20260603,
          'amount': 200.0,
          'source_type': 'merge_allocation',
          'merge_group_id': 7,
          'merge_batch_id': 'batch-restore',
          'merge_batch_total_amount': 600.0,
        },
      ],
      'project_write_offs': <Map<String, dynamic>>[
        // 缺 amount_fen。
        <String, dynamic>{
          'id': 'wo-1',
          'project_id': 'project:restore',
          'amount': 6.78,
          'reason': 'rounding',
          'write_off_date': '2026-06-01',
          'created_at': '2026-06-01T00:00:00.000Z',
          'updated_at': '2026-06-01T00:00:00.000Z',
        },
        <String, dynamic>{
          'id': 'wo-2',
          'project_id': 'project:restore',
          'amount': 0.03,
          'reason': 'bad_debt',
          'write_off_date': '2026-06-02',
          'created_at': '2026-06-02T00:00:00.000Z',
          'updated_at': '2026-06-02T00:00:00.000Z',
        },
      ],
      'project_device_rates': <Map<String, dynamic>>[],
      'timing_calculation_history': <Map<String, dynamic>>[],
      'account_project_merge_groups': <Map<String, dynamic>>[],
      'account_project_merge_members': <Map<String, dynamic>>[],
      'external_import_batches': <Map<String, dynamic>>[],
      'external_work_records': <Map<String, dynamic>>[],
    },
  };
}
