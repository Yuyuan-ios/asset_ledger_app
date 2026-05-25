import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:asset_ledger/data/models/account_project_merge_group.dart';
import 'package:asset_ledger/data/models/account_project_merge_member.dart';
import 'package:asset_ledger/data/models/external_import_batch.dart';
import 'package:asset_ledger/data/models/external_work_record.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:asset_ledger/data/models/project_key.dart';
import 'package:asset_ledger/data/models/project_write_off.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/repositories/account_payment_repository.dart';
import 'package:asset_ledger/data/repositories/account_project_merge_repository.dart';
import 'package:asset_ledger/data/repositories/external_import_repository.dart';
import 'package:asset_ledger/data/repositories/external_work_record_repository.dart';
import 'package:asset_ledger/data/repositories/project_repository.dart';
import 'package:asset_ledger/data/repositories/project_write_off_repository.dart';
import 'package:asset_ledger/data/repositories/timing_repository.dart';
import 'package:asset_ledger/features/timing/use_cases/delete_timing_record_with_impact_use_case.dart';
import 'package:asset_ledger/infrastructure/local/timing/local_delete_timing_record_with_impact_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  setUp(() async {
    await AppDatabase.resetForTest();
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  group('analyzeImpact', () {
    test('plain non-last record carries no cascade', () async {
      final db = await _openCurrentInMemoryDb();
      await _insertProject(db, id: 'project:a');
      final keepId = await _insertTiming(projectId: 'project:a');
      final deleteId = await _insertTiming(projectId: 'project:a');

      final impact = await _useCase().analyzeImpact(deleteId);

      expect(impact.projectId, 'project:a');
      expect(impact.isLastTimingRecordOfProject, isFalse);
      expect(impact.hasPayments, isFalse);
      expect(impact.isSettled, isFalse);
      expect(impact.isBlockedByPayments, isFalse);
      expect(impact.requiresSettlementRevoke, isFalse);
      expect(impact.hasLastRecordCascade, isFalse);
      expect(keepId, isNot(deleteId));
    });

    test('last record with payments is flagged blocked', () async {
      final db = await _openCurrentInMemoryDb();
      await _insertProject(db, id: 'project:a');
      final recordId = await _insertTiming(projectId: 'project:a');
      await SqfliteAccountPaymentRepository().insert(_payment('project:a'));

      final impact = await _useCase().analyzeImpact(recordId);

      expect(impact.isLastTimingRecordOfProject, isTrue);
      expect(impact.hasPayments, isTrue);
      expect(impact.isBlockedByPayments, isTrue);
    });

    test('last record in a 2-member group flags dissolve', () async {
      final db = await _openCurrentInMemoryDb();
      await _insertProject(db, id: 'project:a', site: '工地A');
      await _insertProject(db, id: 'project:b', site: '工地B');
      final recordId = await _insertTiming(projectId: 'project:a', site: '工地A');
      await _createMergeGroup(['project:a', 'project:b']);

      final impact = await _useCase().analyzeImpact(recordId);

      expect(impact.willRemoveMergeMember, isTrue);
      expect(impact.willDissolveMergeGroup, isTrue);
      expect(impact.mergeGroupId, isNotNull);
    });
  });

  group('executeDeleteWithImpact', () {
    // #1
    test('deletes a non-last record in a plain active project', () async {
      final db = await _openCurrentInMemoryDb();
      await _insertProject(db, id: 'project:a');
      final keepId = await _insertTiming(projectId: 'project:a');
      final deleteId = await _insertTiming(projectId: 'project:a');
      final useCase = _useCase();

      final outcome = await useCase.executeDeleteWithImpact(deleteId);

      expect(outcome.hasCascade, isFalse);
      final repo = SqfliteTimingRepository();
      expect(await repo.findById(deleteId), isNull);
      expect(await repo.findById(keepId), isNotNull);
    });

    // #2
    test('non-last record in a settled project revokes settlement', () async {
      final db = await _openCurrentInMemoryDb();
      await _insertProject(
        db,
        id: 'project:a',
        status: ProjectStatus.settled,
        settledAt: '2026-05-20T00:00:00.000Z',
      );
      final keepId = await _insertTiming(projectId: 'project:a');
      final deleteId = await _insertTiming(projectId: 'project:a');
      await _insertWriteOff(db, 'project:a');

      final outcome = await _useCase().executeDeleteWithImpact(deleteId);

      expect(outcome.settlementRevoked, isTrue);
      final repo = SqfliteTimingRepository();
      expect(await repo.findById(deleteId), isNull);
      expect(await repo.findById(keepId), isNotNull);
      expect(await db.query('project_write_offs'), isEmpty);
      expect(await _projectStatus(db, 'project:a'), ProjectStatus.active);
    });

    // #3
    test('deletes the last record when there is nothing attached', () async {
      final db = await _openCurrentInMemoryDb();
      await _insertProject(db, id: 'project:a');
      final recordId = await _insertTiming(projectId: 'project:a');

      final outcome = await _useCase().executeDeleteWithImpact(recordId);

      expect(outcome.hasCascade, isFalse);
      expect(await SqfliteTimingRepository().findById(recordId), isNull);
    });

    // #4
    test('blocks deleting the last record while payments exist', () async {
      final db = await _openCurrentInMemoryDb();
      await _insertProject(db, id: 'project:a');
      final recordId = await _insertTiming(projectId: 'project:a');
      await SqfliteAccountPaymentRepository().insert(_payment('project:a'));

      await expectLater(
        _useCase().executeDeleteWithImpact(recordId),
        throwsA(isA<TimingDeleteBlockedByPaymentsException>()),
      );

      // 记录与收款都不动。
      expect(await SqfliteTimingRepository().findById(recordId), isNotNull);
      expect(await SqfliteAccountPaymentRepository().countByProjectId('project:a'), 1);
    });

    // #5
    test('removes the merge member but keeps a >=2 member group', () async {
      final db = await _openCurrentInMemoryDb();
      await _insertProject(db, id: 'project:a', site: '工地A');
      await _insertProject(db, id: 'project:b', site: '工地B');
      await _insertProject(db, id: 'project:c', site: '工地C');
      final recordId = await _insertTiming(projectId: 'project:a', site: '工地A');
      // b/c 也有计时，保证它们仍是有计时的合并项目。
      await _insertTiming(projectId: 'project:b', site: '工地B');
      await _insertTiming(projectId: 'project:c', site: '工地C');
      await _createMergeGroup(['project:a', 'project:b', 'project:c']);

      final outcome = await _useCase().executeDeleteWithImpact(recordId);

      expect(outcome.mergeMemberRemoved, isTrue);
      expect(outcome.mergeGroupDissolved, isFalse);
      final mergeRepo = SqfliteAccountProjectMergeRepository();
      expect(await mergeRepo.findActiveMemberByProjectId('project:a'), isNull);
      expect(await mergeRepo.findActiveMemberByProjectId('project:b'), isNotNull);
      expect(await mergeRepo.findActiveMemberByProjectId('project:c'), isNotNull);
      expect(await mergeRepo.listActiveGroups(), hasLength(1));
    });

    // #6
    test('dissolves the group when fewer than 2 members remain', () async {
      final db = await _openCurrentInMemoryDb();
      await _insertProject(db, id: 'project:a', site: '工地A');
      await _insertProject(db, id: 'project:b', site: '工地B');
      final recordId = await _insertTiming(projectId: 'project:a', site: '工地A');
      await _insertTiming(projectId: 'project:b', site: '工地B');
      await _createMergeGroup(['project:a', 'project:b']);

      final outcome = await _useCase().executeDeleteWithImpact(recordId);

      expect(outcome.mergeMemberRemoved, isTrue);
      expect(outcome.mergeGroupDissolved, isTrue);
      final mergeRepo = SqfliteAccountProjectMergeRepository();
      expect(await mergeRepo.listActiveGroups(), isEmpty);
      expect(await mergeRepo.listActiveMembers(), isEmpty);
    });

    // #7 + #12
    test('unlinks external work but keeps the records', () async {
      final db = await _openCurrentInMemoryDb();
      await _insertProject(db, id: 'project:a');
      final recordId = await _insertTiming(projectId: 'project:a');
      await _insertLinkedExternalBatch(linkedProjectId: 'project:a');

      final outcome = await _useCase().executeDeleteWithImpact(recordId);

      expect(outcome.externalWorkUnlinked, isTrue);
      final externalRepo = SqfliteExternalWorkRecordRepository();
      final records = await externalRepo.listByBatchId('batch-1');
      expect(records, hasLength(2)); // 外协记录保留
      expect(records.every((r) => r.linkedProjectId == null), isTrue);
      expect(await externalRepo.getLinkedProjectId('batch-1'), isNull);
    });

    // #8
    test('last record settled by write-off only revokes and deletes', () async {
      final db = await _openCurrentInMemoryDb();
      await _insertProject(
        db,
        id: 'project:a',
        status: ProjectStatus.settled,
        settledAt: '2026-05-20T00:00:00.000Z',
      );
      final recordId = await _insertTiming(projectId: 'project:a');
      await _insertWriteOff(db, 'project:a');

      final outcome = await _useCase().executeDeleteWithImpact(recordId);

      expect(outcome.settlementRevoked, isTrue);
      expect(await SqfliteTimingRepository().findById(recordId), isNull);
      expect(await db.query('project_write_offs'), isEmpty);
      expect(await _projectStatus(db, 'project:a'), ProjectStatus.active);
    });

    // #9
    test('rolls back the whole transaction when a cascade step fails', () async {
      final db = await _openCurrentInMemoryDb();
      await _insertProject(db, id: 'project:a');
      final recordId = await _insertTiming(projectId: 'project:a');
      await _insertLinkedExternalBatch(linkedProjectId: 'project:a');

      final useCase = LocalDeleteTimingRecordWithImpactUseCase(
        timingRepository: SqfliteTimingRepository(),
        paymentRepository: SqfliteAccountPaymentRepository(),
        mergeRepository: SqfliteAccountProjectMergeRepository(),
        externalWorkRecordRepository: _ThrowingExternalWorkRecordRepository(),
        writeOffRepository: SqfliteProjectWriteOffRepository(),
        projectRepository: SqfliteProjectRepository(),
      );

      await expectLater(
        useCase.executeDeleteWithImpact(recordId),
        throwsA(isA<StateError>()),
      );

      // 记录仍在、外协关联未被清空：整笔事务已回滚。
      expect(await SqfliteTimingRepository().findById(recordId), isNotNull);
      final records = await SqfliteExternalWorkRecordRepository().listByBatchId(
        'batch-1',
      );
      expect(records.every((r) => r.linkedProjectId == 'project:a'), isTrue);
    });

    // #10 + #11: no residual active merge members after the merged projects'
    // last records are deleted (account card count == merge sheet members).
    test('clears residual merge members after both projects lose timing',
        () async {
      final db = await _openCurrentInMemoryDb();
      await _insertProject(db, id: 'project:a', contact: '李杰', site: '工地A');
      await _insertProject(db, id: 'project:b', contact: '富牛', site: '工地B');
      final aId = await _insertTiming(
        projectId: 'project:a',
        contact: '李杰',
        site: '工地A',
      );
      final bId = await _insertTiming(
        projectId: 'project:b',
        contact: '富牛',
        site: '工地B',
      );
      await _createMergeGroup(['project:a', 'project:b'], contact: '李杰');

      final mergeRepo = SqfliteAccountProjectMergeRepository();
      // 删除第一个项目最后一条计时 → 组降到 1 个有效成员，自动停用整组。
      await _useCase().executeDeleteWithImpact(aId);
      expect(await mergeRepo.listActiveGroupsWithMembers(), isEmpty);

      // 删除第二个项目最后一条计时 → 无残留可清，安全完成。
      final outcome = await _useCase().executeDeleteWithImpact(bId);
      expect(outcome.mergeMemberRemoved, isFalse);
      expect(await mergeRepo.listActiveMembers(), isEmpty);
      expect(await SqfliteTimingRepository().findById(aId), isNull);
      expect(await SqfliteTimingRepository().findById(bId), isNull);
    });
  });
}

DeleteTimingRecordWithImpactUseCase _useCase() {
  return LocalDeleteTimingRecordWithImpactUseCase(
    timingRepository: SqfliteTimingRepository(),
    paymentRepository: SqfliteAccountPaymentRepository(),
    mergeRepository: SqfliteAccountProjectMergeRepository(),
    externalWorkRecordRepository: SqfliteExternalWorkRecordRepository(),
    writeOffRepository: SqfliteProjectWriteOffRepository(),
    projectRepository: SqfliteProjectRepository(),
  );
}

class _ThrowingExternalWorkRecordRepository
    extends SqfliteExternalWorkRecordRepository {
  @override
  Future<int> unlinkByProjectIdWithExecutor(
    DatabaseExecutor executor, {
    required String projectId,
    required String updatedAt,
  }) {
    throw StateError('boom');
  }
}

Future<int> _insertTiming({
  required String projectId,
  String contact = '甲方',
  String site = '工地',
  int startDate = 20260510,
}) {
  return SqfliteTimingRepository().insert(
    TimingRecord(
      deviceId: 1,
      startDate: startDate,
      projectId: projectId,
      contact: contact,
      site: site,
      type: TimingType.hours,
      startMeter: 0,
      endMeter: 10,
      hours: 10,
      income: 1000,
    ),
  );
}

Future<void> _insertProject(
  Database db, {
  required String id,
  String contact = '甲方',
  String site = '工地',
  ProjectStatus status = ProjectStatus.active,
  String? settledAt,
}) async {
  await db.insert(
    'projects',
    Project(
      id: id,
      contact: contact,
      site: site,
      status: status,
      settledAt: settledAt,
      createdAt: '2026-05-01T00:00:00.000Z',
      updatedAt: '2026-05-01T00:00:00.000Z',
      legacyProjectKey: ProjectKey.buildKey(contact: contact, site: site),
    ).toMap(),
  );
}

AccountPayment _payment(String projectId) {
  return AccountPayment(
    projectId: projectId,
    projectKey: ProjectKey.buildKey(contact: '甲方', site: '工地'),
    ymd: 20260510,
    amount: 500,
    createdAt: '2026-05-10T00:00:00.000Z',
  );
}

Future<void> _insertWriteOff(Database db, String projectId) async {
  await db.insert(
    'project_write_offs',
    ProjectWriteOff(
      id: 'writeoff-$projectId',
      projectId: projectId,
      amount: 100,
      reason: ProjectWriteOffReason.settlement.dbValue,
      writeOffDate: '2026-05-20',
      createdAt: '2026-05-20T00:00:00.000Z',
      updatedAt: '2026-05-20T00:00:00.000Z',
    ).toMap(),
  );
}

Future<void> _createMergeGroup(
  List<String> projectIds, {
  String contact = '甲方',
}) async {
  const createdAt = '2026-05-05T00:00:00.000Z';
  final members = <AccountProjectMergeMember>[
    for (var i = 0; i < projectIds.length; i += 1)
      AccountProjectMergeMember(
        groupId: 0,
        projectId: projectIds[i],
        projectKey: ProjectKey.buildKey(contact: contact, site: '工地${i + 1}'),
        contact: contact,
        site: '工地${i + 1}',
        sortOrder: i,
        createdAt: createdAt,
      ),
  ];
  await SqfliteAccountProjectMergeRepository().createGroupWithMembers(
    group: AccountProjectMergeGroup(
      contact: contact,
      createdAt: createdAt,
      updatedAt: createdAt,
    ),
    members: members,
  );
}

Future<void> _insertLinkedExternalBatch({
  required String linkedProjectId,
}) async {
  await SqfliteExternalImportRepository().insertBatch(
    const ExternalImportBatch(
      id: 'batch-1',
      sourceShareId: 'share-1',
      sourceDisplayName: '王师傅',
      recordCount: 2,
      totalHoursMilli: 3000,
      totalAmountFen: 90000,
      siteSummary: '一号工地',
      importedAt: '2026-05-18T00:00:00.000Z',
      createdAt: '2026-05-18T00:00:00.000Z',
      updatedAt: '2026-05-18T00:00:00.000Z',
    ),
  );
  await SqfliteExternalWorkRecordRepository().insertRecords([
    _externalRecord(id: 'rec-a', uuid: 'src-a', linkedProjectId: linkedProjectId),
    _externalRecord(id: 'rec-b', uuid: 'src-b', linkedProjectId: linkedProjectId),
  ]);
}

ExternalWorkRecord _externalRecord({
  required String id,
  required String uuid,
  required String linkedProjectId,
}) {
  return ExternalWorkRecord.create(
    id: id,
    importBatchId: 'batch-1',
    sourceShareId: 'share-1',
    sourceRecordUuid: uuid,
    sourceInstallationUuid: 'install-1',
    originFingerprint: 'fingerprint-$uuid',
    collaboratorName: '王师傅',
    contactSnapshot: '甲方',
    siteSnapshot: '一号工地',
    equipmentBrand: '三一',
    equipmentModel: '75',
    equipmentType: 'excavator',
    workDate: 20260518,
    hoursMilli: 1500,
    sourceUnitPriceFen: 30000,
    linkedProjectId: linkedProjectId,
    createdAt: '2026-05-18T00:00:00.000Z',
    updatedAt: '2026-05-18T00:00:00.000Z',
  );
}

Future<ProjectStatus> _projectStatus(Database db, String id) async {
  final rows = await db.query(
    'projects',
    where: 'id = ?',
    whereArgs: [id],
    limit: 1,
  );
  return Project.fromMap(rows.single).status;
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
