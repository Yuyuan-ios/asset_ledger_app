import 'package:asset_ledger/core/operations/operation_models.dart';
import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/repositories/account_project_merge_repository.dart';
import 'package:asset_ledger/data/repositories/device_repository.dart';
import 'package:asset_ledger/data/repositories/project_rate_repository.dart';
import 'package:asset_ledger/data/repositories/project_repository.dart';
import 'package:asset_ledger/data/repositories/timing_repository.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_operation_analyzer.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_operation_command.dart';
import 'package:asset_ledger/infrastructure/local/account/project_settlement_impact_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  late SaveTimingRecordOperationAnalyzer analyzer;

  setUp(() async {
    await AppDatabase.resetForTest();
    await _openCurrentInMemoryDb();
    final projectRepository = SqfliteProjectRepository();
    analyzer = SaveTimingRecordOperationAnalyzer(
      command: const SaveTimingRecordOperationCommand(),
      timingRepository: SqfliteTimingRepository(),
      mergeRepository: SqfliteAccountProjectMergeRepository(),
      projectRepository: projectRepository,
      deviceRepository: SqfliteDeviceRepository(),
      projectRateRepository: SqfliteProjectRateRepository(),
      impactService: ProjectSettlementImpactService(
        projectRepository: projectRepository,
      ),
    );
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  group('project identity preview', () {
    test(
      'reuses an existing active project without writing a new project',
      () async {
        final db = await AppDatabase.database;
        final deviceId = await _seedDevice(db, name: 'Hitachi 200');
        await _seedProject(
          db,
          projectId: 'project:active-a',
          contact: '丁队',
          site: '五里山',
        );

        final result = await analyzer.analyze(
          SaveTimingRecordOperationAnalyzeInput(
            operationId: 'op-1',
            draftRecord: _draftRecord(
              deviceId: deviceId,
              contact: '丁队',
              site: '五里山',
            ),
          ),
        );

        expect(result.existingNewProjectId, 'project:active-a');
        expect(result.wouldCreateNewProject, isFalse);
        expect(result.preview.operationType, OperationType.saveTimingRecord);
        expect(result.preview.riskLevel, OperationRiskLevel.medium);
        expect(result.preview.requiresConfirmation, isTrue);
        expect(result.previewInput.projectChanged, isFalse);
        expect(result.previewInput.deviceLabel, 'Hitachi 200');
        expect(result.previewInput.projectLabel, '丁队 · 五里山');
        expect(
          await db.query('projects'),
          hasLength(1),
          reason: 'analyzer 只读，不应创建 project',
        );
        expect(await db.query('timing_records'), isEmpty);
      },
    );

    test(
      'reports wouldCreateNewProject when no active project exists',
      () async {
        final db = await AppDatabase.database;
        final deviceId = await _seedDevice(db);

        final result = await analyzer.analyze(
          SaveTimingRecordOperationAnalyzeInput(
            operationId: 'op-create',
            draftRecord: _draftRecord(
              deviceId: deviceId,
              contact: '新甲方',
              site: '新工地',
            ),
          ),
        );

        expect(result.existingNewProjectId, isNull);
        expect(result.wouldCreateNewProject, isTrue);
        expect(result.requiresReanalysisBeforeExecute, isTrue);
        expect(result.warnings.join('\n'), contains('将创建新项目'));
        expect(
          result.preview.affectedEntities,
          contains(
            const OperationEntityRef(
              entityType: 'project',
              entityId: 'new:新甲方||新工地',
              label: '新甲方 · 新工地',
            ),
          ),
        );
        expect(
          await db.query('projects'),
          isEmpty,
          reason: 'preview 只能提示 execute 将创建，不能自己写库',
        );
      },
    );

    test('throws when editing record no longer exists', () async {
      final db = await AppDatabase.database;
      final deviceId = await _seedDevice(db);

      await expectLater(
        analyzer.analyze(
          SaveTimingRecordOperationAnalyzeInput(
            operationId: 'op-stale',
            editingRecordId: 404,
            draftRecord: _draftRecord(
              deviceId: deviceId,
              contact: '甲方',
              site: '工地',
            ),
          ),
        ),
        throwsA(isA<SaveTimingRecordAnalyzeException>()),
      );
      expect(await db.query('timing_records'), isEmpty);
    });

    test('uses DB fresh old project instead of stale UI assumptions', () async {
      final db = await AppDatabase.database;
      final deviceId = await _seedDevice(db);
      await _seedProject(db, projectId: 'project:c', contact: '甲方', site: 'C');
      await _seedProject(db, projectId: 'project:b', contact: '甲方', site: 'B');
      final oldRecord = await _seedTimingRecord(
        db,
        deviceId: deviceId,
        projectId: 'project:c',
        contact: '甲方',
        site: 'C',
        hours: 1,
        income: 100,
      );

      final result = await analyzer.analyze(
        SaveTimingRecordOperationAnalyzeInput(
          operationId: 'op-fresh-old',
          editingRecordId: oldRecord.id,
          draftRecord: oldRecord.copyWith(
            projectId: '',
            contact: '甲方',
            site: 'B',
          ),
        ),
      );

      expect(result.oldProjectId, 'project:c');
      expect(result.existingNewProjectId, 'project:b');
      expect(result.previewInput.projectChanged, isTrue);
      expect(result.preview.summary, contains('项目归属：甲方 · C -> 甲方 · B'));
    });
  });

  group('merge and settlement impact preview', () {
    test('detects old and new active merge groups on project move', () async {
      final db = await AppDatabase.database;
      final deviceId = await _seedDevice(db);
      await _seedProject(db, projectId: 'project:a', contact: '甲方', site: 'A');
      await _seedProject(db, projectId: 'project:b', contact: '甲方', site: 'B');
      await _seedProject(db, projectId: 'project:c', contact: '甲方', site: 'C');
      await _seedProject(db, projectId: 'project:d', contact: '甲方', site: 'D');
      final oldRecord = await _seedTimingRecord(
        db,
        deviceId: deviceId,
        projectId: 'project:a',
        contact: '甲方',
        site: 'A',
        hours: 1,
        income: 100,
      );
      final groupA = await _seedActiveMergeGroup(
        db,
        contact: '甲方',
        members: const [('project:a', '甲方||A'), ('project:c', '甲方||C')],
      );
      final groupB = await _seedActiveMergeGroup(
        db,
        contact: '甲方',
        members: const [('project:b', '甲方||B'), ('project:d', '甲方||D')],
      );

      final result = await analyzer.analyze(
        SaveTimingRecordOperationAnalyzeInput(
          operationId: 'op-move-merge',
          editingRecordId: oldRecord.id,
          draftRecord: oldRecord.copyWith(
            projectId: '',
            contact: '甲方',
            site: 'B',
          ),
        ),
      );

      expect(result.mergeGroupIdsToDissolve, containsAll([groupA, groupB]));
      expect(result.mergeGroupIdsToDissolve, hasLength(2));
      expect(
        result.affectedProjectIds,
        containsAll(['project:a', 'project:b', 'project:c', 'project:d']),
      );
      expect(result.preview.riskLevel, OperationRiskLevel.high);
      expect(
        result.preview.impactItems.map((item) => item.code),
        contains('merge_dissolve'),
      );
      expect(
        result.preview.affectedEntities
            .where((ref) => ref.entityType == 'merge_group')
            .map((ref) => ref.entityId),
        containsAll([groupA.toString(), groupB.toString()]),
      );
      final groupRows = await db.query('account_project_merge_groups');
      expect(
        groupRows.map((row) => row['is_active']).toSet(),
        {1},
        reason: 'analyzer 不应解除合并组',
      );
      expect(await db.query('timing_records'), hasLength(1));
    });

    test(
      'deduplicates merge group when old and new projects are in same group',
      () async {
        final db = await AppDatabase.database;
        final deviceId = await _seedDevice(db);
        await _seedProject(
          db,
          projectId: 'project:a',
          contact: '甲方',
          site: 'A',
        );
        await _seedProject(
          db,
          projectId: 'project:b',
          contact: '甲方',
          site: 'B',
        );
        final oldRecord = await _seedTimingRecord(
          db,
          deviceId: deviceId,
          projectId: 'project:a',
          contact: '甲方',
          site: 'A',
          hours: 1,
          income: 100,
        );
        final groupId = await _seedActiveMergeGroup(
          db,
          contact: '甲方',
          members: const [('project:a', '甲方||A'), ('project:b', '甲方||B')],
        );

        final result = await analyzer.analyze(
          SaveTimingRecordOperationAnalyzeInput(
            operationId: 'op-same-group',
            editingRecordId: oldRecord.id,
            draftRecord: oldRecord.copyWith(
              projectId: '',
              contact: '甲方',
              site: 'B',
            ),
          ),
        );

        expect(result.mergeGroupIdsToDissolve, [groupId]);
        expect(
          result.affectedProjectIds,
          containsAll(['project:a', 'project:b']),
        );
        expect(result.preview.riskLevel, OperationRiskLevel.high);
      },
    );

    test(
      'detects settlement revocation using simulated receivable fen',
      () async {
        final db = await AppDatabase.database;
        final deviceId = await _seedDevice(db, defaultUnitPrice: 100);
        await _seedProject(
          db,
          projectId: 'project:settled',
          contact: '甲方',
          site: '已结清',
          status: ProjectStatus.settled,
          settledAt: '2026-05-20T00:00:00.000Z',
        );
        final oldRecord = await _seedTimingRecord(
          db,
          deviceId: deviceId,
          projectId: 'project:settled',
          contact: '甲方',
          site: '已结清',
          hours: 1,
          income: 100,
        );
        await _seedPayment(db, projectId: 'project:settled', amountFen: 10000);

        final result = await analyzer.analyze(
          SaveTimingRecordOperationAnalyzeInput(
            operationId: 'op-revoke-settlement',
            editingRecordId: oldRecord.id,
            draftRecord: oldRecord.copyWith(hours: 2, endMeter: 2, income: 200),
          ),
        );

        expect(result.previewInput.willRevokeSettlement, isTrue);
        expect(result.preview.riskLevel, OperationRiskLevel.high);
        expect(
          result.preview.impactItems.map((item) => item.code),
          contains('settlement_revoke'),
        );
        final projects = await db.query(
          'projects',
          where: 'id = ?',
          whereArgs: ['project:settled'],
        );
        expect(
          projects.single['status'],
          ProjectStatus.settled.name,
          reason: 'analyzer 只预判撤销，不实际恢复 active',
        );
      },
    );
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

TimingRecord _draftRecord({
  required int deviceId,
  required String contact,
  required String site,
  String projectId = '',
  double hours = 1,
  double income = 100,
}) {
  return TimingRecord(
    deviceId: deviceId,
    startDate: 20260520,
    projectId: projectId,
    contact: contact,
    site: site,
    type: TimingType.hours,
    startMeter: 0,
    endMeter: hours,
    hours: hours,
    income: income,
  );
}

Future<int> _seedDevice(
  Database db, {
  String name = 'Device',
  double defaultUnitPrice = 100.0,
}) {
  return db.rawInsert(
    '''
    INSERT INTO devices (
      name, brand, default_unit_price, base_meter_hours, is_active,
      equipment_type
    )
    VALUES (?, ?, ?, ?, ?, ?)
    ''',
    [name, 'brand', defaultUnitPrice, 0.0, 1, 'excavator'],
  );
}

Future<void> _seedProject(
  Database db, {
  required String projectId,
  required String contact,
  required String site,
  ProjectStatus status = ProjectStatus.active,
  String? settledAt,
}) async {
  await db.rawInsert(
    '''
    INSERT INTO projects (
      id, contact, site, status, settled_at, settled_snapshot,
      created_at, updated_at, legacy_project_key
    )
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
    [
      projectId,
      contact,
      site,
      status.name,
      settledAt,
      null,
      '2026-05-18T00:00:00.000Z',
      '2026-05-18T00:00:00.000Z',
      '$contact||$site',
    ],
  );
}

Future<TimingRecord> _seedTimingRecord(
  Database db, {
  required int deviceId,
  required String projectId,
  required String contact,
  required String site,
  required double hours,
  required double income,
}) async {
  final id = await db.rawInsert(
    '''
    INSERT INTO timing_records (
      project_id, device_id, start_date, contact, site, type,
      start_meter, end_meter, hours, income, exclude_from_fuel_eff,
      is_breaking
    )
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
    [
      projectId,
      deviceId,
      20260518,
      contact,
      site,
      TimingType.hours.name,
      0.0,
      hours,
      hours,
      income,
      0,
      0,
    ],
  );
  return TimingRecord(
    id: id,
    deviceId: deviceId,
    startDate: 20260518,
    projectId: projectId,
    contact: contact,
    site: site,
    type: TimingType.hours,
    startMeter: 0,
    endMeter: hours,
    hours: hours,
    income: income,
  );
}

Future<int> _seedActiveMergeGroup(
  Database db, {
  required String contact,
  required List<(String, String)> members,
}) async {
  final groupId = await db.rawInsert(
    '''
    INSERT INTO account_project_merge_groups (
      contact, created_at, updated_at, is_active, dissolved_at, source_type
    )
    VALUES (?, ?, ?, ?, ?, ?)
    ''',
    [
      contact,
      '2026-05-18T00:00:00.000Z',
      '2026-05-18T00:00:00.000Z',
      1,
      null,
      'local',
    ],
  );
  for (var i = 0; i < members.length; i++) {
    final (projectId, projectKey) = members[i];
    final parts = projectKey.split('||');
    await db.rawInsert(
      '''
      INSERT INTO account_project_merge_members (
        group_id, project_id, project_key, contact, site, sort_order,
        created_at, is_active
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        groupId,
        projectId,
        projectKey,
        parts.first,
        parts.last,
        i,
        '2026-05-18T00:00:00.000Z',
        1,
      ],
    );
  }
  return groupId;
}

Future<void> _seedPayment(
  Database db, {
  required String projectId,
  required int amountFen,
}) async {
  await db.rawInsert(
    '''
    INSERT INTO account_payments (
      project_id, project_key, ymd, amount, amount_fen, note, source_type,
      created_at
    )
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''',
    [
      projectId,
      '甲方||$projectId',
      20260518,
      amountFen / 100.0,
      amountFen,
      null,
      'manual',
      '2026-05-18T00:00:00.000Z',
    ],
  );
}
