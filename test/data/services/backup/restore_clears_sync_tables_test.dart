import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/services/local_backup_export_service.dart';
import 'package:asset_ledger/data/services/local_backup_import_preview_service.dart';
import 'package:asset_ledger/data/services/local_backup_restore_service.dart';
import 'package:asset_ledger/infrastructure/sync/entity_sync_meta.dart';
import 'package:asset_ledger/infrastructure/sync/sync_repositories.dart';
import 'package:asset_ledger/infrastructure/sync/sync_state_repository.dart';
import 'package:asset_ledger/infrastructure/sync/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../../test_setup.dart';

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
    'restore commits sync_outbox/entity_sync_meta clear and push gate in the same '
    'transaction as the business restore',
    () async {
      // 1) 准备：插入一些 sync_outbox / entity_sync_meta 残留行，restore 必须清掉。
      final outbox = LocalSyncOutboxRepository(
        now: () => DateTime.utc(2026, 6, 5, 1),
      );
      await outbox.enqueue(
        entityType: 'timing_record',
        entityId: 'pre-restore-1',
        operation: 'create',
        payload: const {'amount_fen': 100},
      );
      await outbox.enqueue(
        entityType: 'account_payment',
        entityId: 'pre-restore-2',
        operation: 'update',
        payload: const {'amount_fen': 200},
      );

      const metaRepo = LocalEntitySyncMetaRepository();
      await metaRepo.upsert(
        const EntitySyncMeta(
          entityType: 'timing_record',
          localId: 'pre-restore-1',
          syncStatus: SyncStatus.pendingUpload,
          version: 0,
          source: 'owner_app',
        ),
      );

      // sanity：两表先有残留，sync_state 中 push gate 还未设置。
      final db = await AppDatabase.database;
      expect((await db.query('sync_outbox')).length, 2);
      expect((await db.query('entity_sync_meta')).length, 1);
      const gateRepo = LocalSyncStateRepository();
      expect(await gateRepo.isPushGated(), isFalse);

      // 2) 构造一个最小可校验的 backup JSON：什么业务行都不放（仅 meta + 空 data
      //    满足 BackupRestoreValidator 必备 schema），restore 的"清旧业务表 + 插
      //    新业务表"这一段不产生数据；我们只关心同事务的 sync 状态清理。
      final backupJson = _buildEmptyValidBackup();

      // 3) 执行 restore，注入一个不做 IO 的 exportBackup 桩，避免依赖文件系统。
      final restoreService = LocalBackupRestoreService(
        previewService: const LocalBackupImportPreviewService(),
        exportBackup: () async => const LocalBackupExportResult(
          success: true,
          filePath: '/tmp/pre-restore-stub.json',
          fileName: 'pre-restore-stub.json',
        ),
      );
      final result = await restoreService.restoreFromDecodedJson(backupJson);
      expect(result.success, isTrue, reason: result.message);

      // 4) restore 成功路径下 sync 状态必须被同事务清空 + push gate 置为
      //    restore-pending。
      expect(
        (await db.query('sync_outbox')).length,
        0,
        reason: 'restore must clear sync_outbox in the same transaction',
      );
      expect(
        (await db.query('entity_sync_meta')).length,
        0,
        reason: 'restore must clear entity_sync_meta in the same transaction',
      );
      expect(
        await gateRepo.readPushGate(),
        SyncStateRepository.gateRestorePending,
        reason: 'restore must arm push gate so cloud push waits for reconcile',
      );
    },
  );

  test('failed restore rolls back the sync state cleanup as well', () async {
    final outbox = LocalSyncOutboxRepository(
      now: () => DateTime.utc(2026, 6, 5, 2),
    );
    await outbox.enqueue(
      entityType: 'timing_record',
      entityId: 'survives-failure',
      operation: 'create',
      payload: const {'amount_fen': 100},
    );

    // 让 exportBackup 返回失败 → restoreFromDecodedJson 应在进入业务事务前
    // 终止，sync_outbox 残留必须仍在。
    final restoreService = LocalBackupRestoreService(
      previewService: const LocalBackupImportPreviewService(),
      exportBackup: () async => const LocalBackupExportResult(
        success: false,
        errorMessage: 'simulated failure',
      ),
    );
    final result = await restoreService.restoreFromDecodedJson(
      _buildEmptyValidBackup(),
    );
    expect(result.success, isFalse);

    final db = await AppDatabase.database;
    expect(
      (await db.query('sync_outbox')).length,
      1,
      reason: 'restore that never entered the transaction must not clear outbox',
    );
    const gateRepo = LocalSyncStateRepository();
    expect(
      await gateRepo.isPushGated(),
      isFalse,
      reason: 'push gate must not be armed when restore aborts before commit',
    );
  });
}

/// 构造一个 schema 合法但 data 段全空的 backup JSON。仅用于本测试触发 restore
/// 的事务路径；不依赖任何 production 数据。
Map<String, dynamic> _buildEmptyValidBackup() {
  return <String, dynamic>{
    'meta': <String, dynamic>{
      'app_name': 'FleetLedger',
      'app_version': 'test',
      'export_format_version': 2,
      'schema_version': AppDatabase.schemaVersion,
      'exported_at': '2026-06-05T00:00:00.000Z',
    },
    'data': <String, dynamic>{
      'projects': <Map<String, dynamic>>[],
      'devices': <Map<String, dynamic>>[],
      'timing_records': <Map<String, dynamic>>[],
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
