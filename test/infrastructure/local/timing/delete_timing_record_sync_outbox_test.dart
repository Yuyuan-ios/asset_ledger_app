import 'dart:convert';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:asset_ledger/data/models/account_project_merge_group.dart';
import 'package:asset_ledger/data/models/account_project_merge_member.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:asset_ledger/data/models/project_key.dart';
import 'package:asset_ledger/data/models/project_write_off.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/repositories/account_payment_repository.dart';
import 'package:asset_ledger/data/repositories/account_project_merge_repository.dart';
import 'package:asset_ledger/data/repositories/external_work_record_repository.dart';
import 'package:asset_ledger/data/repositories/project_repository.dart';
import 'package:asset_ledger/data/repositories/project_write_off_repository.dart';
import 'package:asset_ledger/data/repositories/timing_repository.dart';
import 'package:asset_ledger/features/timing/use_cases/delete_timing_record_with_impact_use_case.dart';
import 'package:asset_ledger/infrastructure/local/timing/local_delete_timing_record_with_impact_use_case.dart';
import 'package:asset_ledger/infrastructure/sync/sync_outbox_entry.dart';
import 'package:asset_ledger/infrastructure/sync/sync_repositories.dart';
import 'package:asset_ledger/infrastructure/sync/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../../test_setup.dart';

/// R5.2 — 删除计时记录在同一事务内入队 delete outbox + pendingDelete meta。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  setUp(() async {
    await AppDatabase.resetForTest();
    await _openCurrentInMemoryDb();
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  test('删除成功后同事务写入 pending delete outbox 和 pendingDelete meta', () async {
    final db = await AppDatabase.database;
    await _insertProject(db, id: 'project:a');
    final keepId = await _insertTiming(projectId: 'project:a');
    final deleteId = await _insertTiming(projectId: 'project:a');

    final outcome = await _useCase().executeDeleteWithImpact(deleteId);

    expect(outcome.hasCascade, isFalse);
    // 目标记录已删，其它记录保留。
    expect(await SqfliteTimingRepository().findById(deleteId), isNull);
    expect(await SqfliteTimingRepository().findById(keepId), isNotNull);

    final outboxRows = await db.query('sync_outbox');
    expect(outboxRows, hasLength(1));
    expect(outboxRows.single['entity_type'], 'timing_record');
    expect(outboxRows.single['entity_id'], deleteId.toString());
    expect(outboxRows.single['operation'], 'delete');
    expect(outboxRows.single['status'], SyncOutboxStatus.pending.name);
    final payload =
        jsonDecode(outboxRows.single['payload_json'] as String)
            as Map<String, Object?>;
    expect(payload['operation'], 'delete');
    expect(payload['entity_id'], deleteId.toString());
    expect((payload['record'] as Map<String, Object?>)['id'], deleteId);
    expect((payload['record'] as Map<String, Object?>)['project_id'], 'project:a');

    final metaRows = await db.query('entity_sync_meta');
    expect(metaRows, hasLength(1));
    expect(metaRows.single['entity_type'], 'timing_record');
    expect(metaRows.single['local_id'], deleteId.toString());
    expect(metaRows.single['sync_status'], SyncStatus.pendingDelete.name);
    expect(metaRows.single['source'], 'owner_app');
    expect(metaRows.single['payload_hash'], outboxRows.single['payload_hash']);
  });

  test('被收款阻止删除时：不删记录、不入队 outbox/meta', () async {
    final db = await AppDatabase.database;
    await _insertProject(db, id: 'project:a');
    final recordId = await _insertTiming(projectId: 'project:a');
    await SqfliteAccountPaymentRepository().insert(_payment('project:a'));

    await expectLater(
      _useCase().executeDeleteWithImpact(recordId),
      throwsA(isA<TimingDeleteBlockedByPaymentsException>()),
    );

    // 记录仍在；没有任何 outbox/meta 写入。
    expect(await SqfliteTimingRepository().findById(recordId), isNotNull);
    expect(await db.query('sync_outbox'), isEmpty);
    expect(await db.query('entity_sync_meta'), isEmpty);
  });

  test('outbox 写失败：删除 + 撤销结清整体回滚，不留半条', () async {
    final db = await AppDatabase.database;
    // 已结清项目 + 核销：删除会触发撤销结清（删核销 + 恢复 active）。
    await _insertProject(
      db,
      id: 'project:a',
      status: ProjectStatus.settled,
      settledAt: '2026-05-20T00:00:00.000Z',
    );
    final keepId = await _insertTiming(projectId: 'project:a');
    final deleteId = await _insertTiming(projectId: 'project:a');
    await _insertWriteOff(db, 'project:a');

    final failingUseCase = LocalDeleteTimingRecordWithImpactUseCase(
      timingRepository: SqfliteTimingRepository(),
      paymentRepository: SqfliteAccountPaymentRepository(),
      mergeRepository: SqfliteAccountProjectMergeRepository(),
      externalWorkRecordRepository: SqfliteExternalWorkRecordRepository(),
      writeOffRepository: SqfliteProjectWriteOffRepository(),
      projectRepository: SqfliteProjectRepository(),
      syncOutboxRepository: const _ThrowingSyncOutboxRepository(),
    );

    await expectLater(
      failingUseCase.executeDeleteWithImpact(deleteId),
      throwsA(isA<StateError>()),
    );

    // 1) 两条记录都还在（删除回滚）。
    expect(await SqfliteTimingRepository().findById(deleteId), isNotNull);
    expect(await SqfliteTimingRepository().findById(keepId), isNotNull);
    // 2) 核销仍在、项目仍 settled（撤销结清回滚）。
    final writeOffs = await db.query('project_write_offs');
    expect(writeOffs, hasLength(1));
    final projectRow = (await db.query(
      'projects',
      where: 'id = ?',
      whereArgs: ['project:a'],
    )).single;
    expect(projectRow['status'], ProjectStatus.settled.name);
    // 3) 没有半条 outbox/meta。
    expect(await db.query('sync_outbox'), isEmpty);
    expect(await db.query('entity_sync_meta'), isEmpty);
  });

  test('删除触发合并解除时：解除与 delete outbox 同事务落库', () async {
    final db = await AppDatabase.database;
    await _insertProject(db, id: 'project:a', site: '工地1');
    await _insertProject(db, id: 'project:b', site: '工地2');
    final recordId = await _insertTiming(projectId: 'project:a', site: '工地1');
    await _createMergeGroup(['project:a', 'project:b']);

    final outcome = await _useCase().executeDeleteWithImpact(recordId);

    // 删的是 A 的最后一条 → A 退出合并组 → 组只剩 B（<2 有效成员）→ 解散。
    expect(outcome.mergeMemberRemoved, isTrue);
    expect(outcome.mergeGroupDissolved, isTrue);
    final groupRows = await db.query('account_project_merge_groups');
    expect(groupRows.single['is_active'], 0);

    // 合并解除与 delete outbox 同事务提交。
    final outboxRows = await db.query('sync_outbox');
    expect(outboxRows, hasLength(1));
    expect(outboxRows.single['operation'], 'delete');
    expect(outboxRows.single['entity_id'], recordId.toString());
    final metaRows = await db.query('entity_sync_meta');
    expect(metaRows.single['sync_status'], SyncStatus.pendingDelete.name);
  });
}

class _ThrowingSyncOutboxRepository implements SyncOutboxRepository {
  const _ThrowingSyncOutboxRepository();

  @override
  Future<SyncOutboxEntry> enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
  }) {
    throw StateError('注入的失败：sync_outbox 写入失败');
  }

  @override
  Future<SyncOutboxEntry> enqueueWithExecutor(
    DatabaseExecutor executor, {
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
  }) {
    throw StateError('注入的失败：sync_outbox 写入失败');
  }

  @override
  Future<List<SyncOutboxEntry>> listPending({int limit = 50}) async {
    return const [];
  }
}

DeleteTimingRecordWithImpactUseCase _useCase() {
  return LocalDeleteTimingRecordWithImpactUseCase(
    timingRepository: SqfliteTimingRepository(),
    paymentRepository: SqfliteAccountPaymentRepository(),
    mergeRepository: SqfliteAccountProjectMergeRepository(),
    externalWorkRecordRepository: SqfliteExternalWorkRecordRepository(),
    writeOffRepository: SqfliteProjectWriteOffRepository(),
    projectRepository: SqfliteProjectRepository(),
    now: () => DateTime.utc(2026, 6, 1, 12),
  );
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
