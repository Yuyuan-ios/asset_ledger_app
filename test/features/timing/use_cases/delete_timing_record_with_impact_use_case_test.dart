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

  group('executeDeleteWithImpact effective merge members', () {
    // #6: 剩余成员含历史孤儿，有效成员不足 2 → 孤儿停用 + 整组解散。
    test('deactivates trace-less orphans and dissolves below 2 effective',
        () async {
      final db = await _openCurrentInMemoryDb();
      for (final id in const ['project:a', 'project:b', 'project:c', 'project:d']) {
        await _insertProject(db, id: id, site: id);
      }
      final aId = await _insertTiming(projectId: 'project:a');
      await _insertTiming(projectId: 'project:b'); // b 有计时（有效）
      // c、d 无计时、无任何痕迹 → 孤儿
      await _createMergeGroup(['project:a', 'project:b', 'project:c', 'project:d']);

      final outcome = await _useCase().executeDeleteWithImpact(aId);

      expect(outcome.mergeMemberRemoved, isTrue);
      expect(outcome.mergeGroupDissolved, isTrue);
      final mergeRepo = SqfliteAccountProjectMergeRepository();
      expect(await mergeRepo.listActiveGroups(), isEmpty);
      expect(await mergeRepo.listActiveMembers(), isEmpty);
    });

    // #7: 剩余有效成员 >= 2 → 组保持 active，同时顺带清理孤儿。
    test('keeps the group and cleans orphans when >= 2 effective remain',
        () async {
      final db = await _openCurrentInMemoryDb();
      for (final id in const ['project:a', 'project:b', 'project:c', 'project:d']) {
        await _insertProject(db, id: id, site: id);
      }
      final aId = await _insertTiming(projectId: 'project:a');
      await _insertTiming(projectId: 'project:b'); // 有效
      await _insertTiming(projectId: 'project:c'); // 有效
      // d 无痕迹 → 孤儿
      await _createMergeGroup(['project:a', 'project:b', 'project:c', 'project:d']);

      final outcome = await _useCase().executeDeleteWithImpact(aId);

      expect(outcome.mergeMemberRemoved, isTrue);
      expect(outcome.mergeGroupDissolved, isFalse);
      final mergeRepo = SqfliteAccountProjectMergeRepository();
      expect(await mergeRepo.findActiveMemberByProjectId('project:a'), isNull);
      expect(await mergeRepo.findActiveMemberByProjectId('project:d'), isNull);
      expect(await mergeRepo.findActiveMemberByProjectId('project:b'), isNotNull);
      expect(await mergeRepo.findActiveMemberByProjectId('project:c'), isNotNull);
      expect(await mergeRepo.listActiveGroups(), hasLength(1));
    });

    // #8: raw active 仍为 2，但其中 1 个是无痕迹孤儿 → 有效成员 1 → 解散。
    test('dissolves when raw active is 2 but effective is 1', () async {
      final db = await _openCurrentInMemoryDb();
      for (final id in const ['project:a', 'project:b', 'project:c']) {
        await _insertProject(db, id: id, site: id);
      }
      final aId = await _insertTiming(projectId: 'project:a');
      await _insertTiming(projectId: 'project:b'); // 有效
      // c 孤儿（删除 a 后 raw active = b,c = 2，但有效只有 b）
      await _createMergeGroup(['project:a', 'project:b', 'project:c']);

      final outcome = await _useCase().executeDeleteWithImpact(aId);

      expect(outcome.mergeGroupDissolved, isTrue);
      final mergeRepo = SqfliteAccountProjectMergeRepository();
      expect(await mergeRepo.listActiveGroups(), isEmpty);
      expect(await mergeRepo.findActiveMemberByProjectId('project:b'), isNull);
    });

    // #9: 有账务/外协/结清痕迹（无计时）的成员不被自动停用。
    test('does not deactivate members that still carry traces', () async {
      final db = await _openCurrentInMemoryDb();
      for (final id in const [
        'project:a',
        'project:pay',
        'project:wo',
        'project:settled',
        'project:ext',
      ]) {
        await _insertProject(db, id: id, site: id);
      }
      final aId = await _insertTiming(projectId: 'project:a');
      await SqfliteAccountPaymentRepository().insert(_payment('project:pay'));
      await _insertWriteOff(db, 'project:wo');
      await _insertLinkedExternalBatch(linkedProjectId: 'project:ext');
      await _createMergeGroup([
        'project:a',
        'project:pay',
        'project:wo',
        'project:settled',
        'project:ext',
      ]);
      // 合并组创建会把成员项目 upsert 为 active，结清状态必须在其后再设置。
      await _markSettled(db, 'project:settled');

      final outcome = await _useCase().executeDeleteWithImpact(aId);

      expect(outcome.mergeGroupDissolved, isFalse);
      final mergeRepo = SqfliteAccountProjectMergeRepository();
      expect(await mergeRepo.listActiveGroups(), hasLength(1));
      for (final id in const [
        'project:pay',
        'project:wo',
        'project:settled',
        'project:ext',
      ]) {
        expect(
          await mergeRepo.findActiveMemberByProjectId(id),
          isNotNull,
          reason: '$id 有痕迹，不应被自动停用',
        );
      }
    });

    // #10: 合并清理过程中后续步骤失败 → 整笔事务回滚，不留半清理状态。
    test('rolls back merge cleanup when a later step fails', () async {
      final db = await _openCurrentInMemoryDb();
      for (final id in const ['project:a', 'project:b', 'project:c']) {
        await _insertProject(db, id: id, site: id);
      }
      final aId = await _insertTiming(projectId: 'project:a');
      await _insertTiming(projectId: 'project:b');
      // c 孤儿；a 还有外协关联，解除外协时抛错触发回滚。
      await _createMergeGroup(['project:a', 'project:b', 'project:c']);
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
        useCase.executeDeleteWithImpact(aId),
        throwsA(isA<StateError>()),
      );

      // 全部合并改动回滚：记录仍在，三个成员与组都恢复 active。
      expect(await SqfliteTimingRepository().findById(aId), isNotNull);
      final mergeRepo = SqfliteAccountProjectMergeRepository();
      expect(await mergeRepo.listActiveGroups(), hasLength(1));
      for (final id in const ['project:a', 'project:b', 'project:c']) {
        expect(await mergeRepo.findActiveMemberByProjectId(id), isNotNull);
      }
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

Future<void> _markSettled(Database db, String projectId) async {
  await db.update(
    'projects',
    {
      'status': ProjectStatus.settled.name,
      'settled_at': '2026-05-20T00:00:00.000Z',
      'updated_at': '2026-05-20T00:00:00.000Z',
    },
    where: 'id = ?',
    whereArgs: [projectId],
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
