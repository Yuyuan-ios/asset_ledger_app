import 'dart:convert';
import 'dart:io';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/backup_restore_result.dart';
import 'package:asset_ledger/data/models/project_id.dart';
import 'package:asset_ledger/data/services/local_backup_export_service.dart';
import 'package:asset_ledger/data/services/local_backup_restore_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  late Directory documentsDir;
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    documentsDir = await Directory.systemTemp.createTemp(
      'asset_ledger_backup_external_test_',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return documentsDir.path;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, null),
    );
    await AppDatabase.resetForTest();
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
    if (await documentsDir.exists()) {
      await documentsDir.delete(recursive: true);
    }
  });

  test(
    '导出包含 external_import_batches 与 external_work_records',
    () async {
      final db = await _openCurrentInMemoryDb();
      await _seedProject(db, projectKey: '甲方||一号工地');
      await _seedExternalBatch(db, id: 'batch-1');
      await _seedExternalRecord(
        db,
        id: 'rec-1',
        batchId: 'batch-1',
        linkedProjectId: _projectIdForKey('甲方||一号工地'),
      );

      final result = await LocalBackupExportService.exportJsonBackup();
      expect(result.success, isTrue);

      final rawJson = await File(result.filePath!).readAsString();
      final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>;
      final summary = decoded['summary'] as Map<String, dynamic>;
      final tableCounts = summary['table_counts'] as Map<String, dynamic>;

      expect(tableCounts['external_import_batches'], 1);
      expect(tableCounts['external_work_records'], 1);
      expect(
        (data['external_import_batches'] as List).single['id'],
        'batch-1',
      );
      expect(
        (data['external_work_records'] as List).single['id'],
        'rec-1',
      );
    },
  );

  test(
    '空库恢复后，external_import_batches 与 external_work_records 被恢复',
    () async {
      final db = await _openCurrentInMemoryDb();

      final result = await _restoreService().restoreFromDecodedJson(
        _backupJson(
          projects: [_projectMap()],
          externalBatches: [_externalBatchMap()],
          externalRecords: [
            _externalRecordMap(linkedProjectId: _projectIdForKey('甲方||一号工地')),
          ],
        ),
      );

      expect(result.success, isTrue, reason: result.message);
      expect(result.restoredCounts['external_import_batches'], 1);
      expect(result.restoredCounts['external_work_records'], 1);

      final batches = await db.query('external_import_batches');
      final records = await db.query('external_work_records');
      expect(batches, hasLength(1));
      expect(records, hasLength(1));
      expect(records.single['linked_project_id'], _projectIdForKey('甲方||一号工地'));
    },
  );

  test('覆盖恢复时，旧外协数据不会残留，且不会被旧 FK 阻断', () async {
    final db = await _openCurrentInMemoryDb();
    // 旧库已有外协批次和外协记录（且关联到旧项目）。
    await _seedProject(db, projectKey: '旧甲方||旧工地', projectId: 'project:legacy-old');
    await _seedExternalBatch(db, id: 'old-batch');
    await _seedExternalRecord(
      db,
      id: 'old-rec',
      batchId: 'old-batch',
      linkedProjectId: 'project:legacy-old',
    );

    final result = await _restoreService().restoreFromDecodedJson(
      _backupJson(
        projects: [_projectMap()],
        externalBatches: [_externalBatchMap(id: 'batch-new')],
        externalRecords: [
          _externalRecordMap(
            id: 'rec-new',
            batchId: 'batch-new',
            linkedProjectId: _projectIdForKey('甲方||一号工地'),
          ),
        ],
      ),
    );

    expect(result.success, isTrue, reason: result.message);
    final batches = await db.query('external_import_batches');
    final records = await db.query('external_work_records');
    expect(batches.map((r) => r['id']).toList(), ['batch-new']);
    expect(records.map((r) => r['id']).toList(), ['rec-new']);
    // 旧项目也被覆盖清空。
    final projects = await db.query('projects');
    expect(projects, hasLength(1));
    expect(projects.single['id'], _projectIdForKey('甲方||一号工地'));
  });

  test(
    'linked_project_id 在备份 projects 中存在时，恢复后保持关联',
    () async {
      final db = await _openCurrentInMemoryDb();

      final result = await _restoreService().restoreFromDecodedJson(
        _backupJson(
          projects: [_projectMap()],
          externalBatches: [_externalBatchMap()],
          externalRecords: [
            _externalRecordMap(
              linkedProjectId: _projectIdForKey('甲方||一号工地'),
            ),
          ],
        ),
      );

      expect(result.success, isTrue);
      expect(result.warnings, isEmpty);
      final records = await db.query('external_work_records');
      expect(records.single['linked_project_id'], _projectIdForKey('甲方||一号工地'));
    },
  );

  test(
    'linked_project_id 在备份 projects 中不存在时：保留外协、解除关联、记录 warning',
    () async {
      final db = await _openCurrentInMemoryDb();

      final result = await _restoreService().restoreFromDecodedJson(
        _backupJson(
          projects: [_projectMap()],
          externalBatches: [_externalBatchMap()],
          externalRecords: [
            _externalRecordMap(
              id: 'rec-orphan',
              linkedProjectId: 'project:does-not-exist',
            ),
          ],
        ),
      );

      expect(result.success, isTrue, reason: result.message);
      expect(result.restoredCounts['external_work_records'], 1);

      final records = await db.query('external_work_records');
      expect(records, hasLength(1));
      expect(records.single['id'], 'rec-orphan');
      expect(records.single['linked_project_id'], isNull);

      expect(result.warnings, hasLength(1));
      final warning = result.warnings.single;
      expect(
        warning.code,
        BackupRestoreWarningCode.externalWorkLinkedProjectMissing,
      );
      expect(warning.context['detached_count'], 1);
      expect(
        warning.context['external_work_record_ids'],
        contains('rec-orphan'),
      );
    },
  );

  test('恢复过程中发生结构性错误时，整体回滚不产生半恢复', () async {
    final db = await _openCurrentInMemoryDb();
    // 旧库先放入业务数据，用来验证回滚不会清空它们。
    await _seedProject(db, projectKey: '甲方||旧工地', projectId: 'project:keep');

    // 制造结构性错误：external_work_records 的 import_batch_id 在备份中不存在。
    final result = await _restoreService().restoreFromDecodedJson(
      _backupJson(
        projects: [_projectMap()],
        externalBatches: const [],
        externalRecords: [
          _externalRecordMap(
            id: 'rec-bad',
            batchId: 'batch-missing',
            linkedProjectId: _projectIdForKey('甲方||一号工地'),
          ),
        ],
      ),
    );

    expect(result.success, isFalse);
    expect(result.errorCode, 'transaction_failed');

    // 旧项目仍在（回滚后没有半恢复）。
    final projects = await db.query('projects');
    expect(projects.single['id'], 'project:keep');
    final batches = await db.query('external_import_batches');
    expect(batches, isEmpty);
    final records = await db.query('external_work_records');
    expect(records, isEmpty);
  });

  test('旧版备份不含外协表时也能恢复（optional 表）', () async {
    final db = await _openCurrentInMemoryDb();

    final result = await _restoreService().restoreFromDecodedJson(
      _backupJson(
        projects: [_projectMap()],
        // 不传 externalBatches/externalRecords —— 模拟旧备份缺这两张表。
      ),
    );

    expect(result.success, isTrue, reason: result.message);
    expect(result.restoredCounts['external_import_batches'], 0);
    expect(result.restoredCounts['external_work_records'], 0);
    expect(await db.query('external_import_batches'), isEmpty);
    expect(await db.query('external_work_records'), isEmpty);
  });
}

Future<Database> _openCurrentInMemoryDb() {
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
  return AppDatabase.database;
}

LocalBackupRestoreService _restoreService() {
  return LocalBackupRestoreService(
    exportBackup: () async {
      return LocalBackupExportResult(
        success: true,
        filePath: p.join('/tmp', 'pre_restore.json'),
        fileName: 'pre_restore.json',
      );
    },
  );
}

Map<String, dynamic> _backupJson({
  int exportFormatVersion = 2,
  int? schemaVersion,
  required List<Map<String, Object?>> projects,
  List<Map<String, Object?>>? externalBatches,
  List<Map<String, Object?>>? externalRecords,
}) {
  final data = <String, Object?>{
    'projects': projects,
    'devices': const [],
    'timing_records': const [],
    'fuel_logs': const [],
    'maintenance_records': const [],
    'account_payments': const [],
    'project_device_rates': const [],
    'timing_calculation_history': const [],
    'account_project_merge_groups': const [],
    'account_project_merge_members': const [],
    'project_write_offs': const [],
    'external_import_batches': ?externalBatches,
    'external_work_records': ?externalRecords,
  };

  return <String, dynamic>{
    'meta': <String, Object?>{
      'export_format_version': exportFormatVersion,
      'schema_version': schemaVersion ?? AppDatabase.schemaVersion,
      'exported_at': '2026-05-26T10:00:00.000Z',
      'app_version': 'test',
      'app_name': 'FleetLedger',
    },
    'summary': <String, Object?>{
      'table_counts': <String, int>{
        'projects': projects.length,
        if (externalBatches != null)
          'external_import_batches': externalBatches.length,
        if (externalRecords != null)
          'external_work_records': externalRecords.length,
      },
    },
    'data': data,
  };
}

Map<String, Object?> _projectMap({String projectKey = '甲方||一号工地'}) {
  final parts = projectKey.split('||');
  return {
    'id': _projectIdForKey(projectKey),
    'contact': parts[0],
    'site': parts.length > 1 ? parts[1] : '',
    'status': 'active',
    'settled_at': null,
    'settled_snapshot': null,
    'created_at': '2026-05-26T10:00:00.000Z',
    'updated_at': '2026-05-26T10:00:00.000Z',
    'legacy_project_key': projectKey,
  };
}

Map<String, Object?> _externalBatchMap({
  String id = 'batch-1',
  String sourceShareId = 'share-1',
  String sourceDisplayName = '示例分享',
  int recordCount = 1,
  int totalHoursMilli = 8000,
  int totalAmountFen = 80000,
  String siteSummary = '一号工地',
  String importedAt = '2026-05-25T01:02:03.000Z',
  String status = 'active',
  String createdAt = '2026-05-25T01:02:03.000Z',
  String updatedAt = '2026-05-25T01:02:03.000Z',
}) {
  return {
    'id': id,
    'source_share_id': sourceShareId,
    'source_display_name': sourceDisplayName,
    'record_count': recordCount,
    'total_hours_milli': totalHoursMilli,
    'total_amount_fen': totalAmountFen,
    'site_summary': siteSummary,
    'imported_at': importedAt,
    'status': status,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };
}

Map<String, Object?> _externalRecordMap({
  String id = 'rec-1',
  String batchId = 'batch-1',
  String sourceShareId = 'share-1',
  String sourceRecordUuid = 'uuid-rec-1',
  String sourceInstallationUuid = 'inst-uuid',
  String originFingerprint = 'fp-1',
  String collaboratorName = '合作方',
  String contactSnapshot = '甲方',
  String siteSnapshot = '一号工地',
  int workDate = 20260525,
  int hoursMilli = 8000,
  int amountFen = 80000,
  int? sourceUnitPriceFen = 10000,
  int? localUnitPriceFen = 10000,
  int projectReceivedFen = 0,
  String? linkedProjectId,
  String recordKind = 'hours',
  String status = 'active',
  String createdAt = '2026-05-25T01:02:03.000Z',
  String updatedAt = '2026-05-25T01:02:03.000Z',
}) {
  return {
    'id': id,
    'import_batch_id': batchId,
    'source_share_id': sourceShareId,
    'source_record_uuid': sourceRecordUuid,
    'source_installation_uuid': sourceInstallationUuid,
    'origin_fingerprint': originFingerprint,
    'collaborator_name': collaboratorName,
    'contact_snapshot': contactSnapshot,
    'site_snapshot': siteSnapshot,
    'equipment_brand': null,
    'equipment_model': null,
    'equipment_type': null,
    'work_date': workDate,
    'hours_milli': hoursMilli,
    'source_unit_price_fen': sourceUnitPriceFen,
    'local_unit_price_fen': localUnitPriceFen,
    'amount_fen': amountFen,
    'project_received_fen': projectReceivedFen,
    'linked_project_id': linkedProjectId,
    'record_kind': recordKind,
    'status': status,
    'note': null,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };
}

Future<void> _seedProject(
  Database db, {
  required String projectKey,
  String? projectId,
}) async {
  final parts = projectKey.split('||');
  await db.insert('projects', {
    'id': projectId ?? _projectIdForKey(projectKey),
    'contact': parts[0],
    'site': parts.length > 1 ? parts[1] : '',
    'status': 'active',
    'created_at': '2026-05-25T01:02:03.000Z',
    'updated_at': '2026-05-25T01:02:03.000Z',
    'legacy_project_key': projectKey,
  }, conflictAlgorithm: ConflictAlgorithm.ignore);
}

Future<void> _seedExternalBatch(
  Database db, {
  required String id,
}) async {
  await db.insert('external_import_batches', _externalBatchMap(id: id));
}

Future<void> _seedExternalRecord(
  Database db, {
  required String id,
  required String batchId,
  String? linkedProjectId,
}) async {
  await db.insert(
    'external_work_records',
    _externalRecordMap(
      id: id,
      batchId: batchId,
      linkedProjectId: linkedProjectId,
    ),
  );
}

String _projectIdForKey(String projectKey) =>
    ProjectId.legacyFromKey(projectKey);
