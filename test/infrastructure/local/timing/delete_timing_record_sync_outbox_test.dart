import 'dart:convert';

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
import 'package:asset_ledger/infrastructure/local/account/project_sync_enqueuer.dart';
import 'package:asset_ledger/infrastructure/local/account/project_write_off_sync_enqueuer.dart';
import 'package:asset_ledger/infrastructure/local/timing/external_work_sync_enqueuer.dart';
import 'package:asset_ledger/infrastructure/local/timing/local_delete_timing_record_with_impact_use_case.dart';
import 'package:asset_ledger/infrastructure/sync/entity_sync_meta.dart';
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
    expect(
      (payload['record'] as Map<String, Object?>)['project_id'],
      'project:a',
    );

    final metaRows = await db.query('entity_sync_meta');
    expect(metaRows, hasLength(1));
    expect(metaRows.single['entity_type'], 'timing_record');
    expect(metaRows.single['local_id'], deleteId.toString());
    expect(metaRows.single['sync_status'], SyncStatus.pendingDelete.name);
    expect(metaRows.single['source'], 'owner_app');
    expect(metaRows.single['payload_hash'], outboxRows.single['payload_hash']);
    expect(
      _outboxRows(
        outboxRows,
        entityType: ProjectWriteOffSyncEnqueuer.entityType,
      ),
      isEmpty,
    );
    expect(
      _outboxRows(outboxRows, entityType: ProjectSyncEnqueuer.entityType),
      isEmpty,
    );
  });

  test('被收款阻止删除时：不删记录、不入队 outbox/meta', () async {
    final db = await AppDatabase.database;
    await _insertProject(
      db,
      id: 'project:a',
      status: ProjectStatus.settled,
      settledAt: '2026-05-20T00:00:00.000Z',
      settledSnapshot: '{"remaining":0}',
    );
    final recordId = await _insertTiming(projectId: 'project:a');
    await _insertWriteOff(db, 'project:a');
    await SqfliteAccountPaymentRepository().insert(_payment('project:a'));

    await expectLater(
      _useCase().executeDeleteWithImpact(recordId),
      throwsA(isA<TimingDeleteBlockedByPaymentsException>()),
    );

    // 记录仍在；没有任何 outbox/meta 写入。
    expect(await SqfliteTimingRepository().findById(recordId), isNotNull);
    expect(await db.query('project_write_offs'), hasLength(1));
    expect(await _projectStatus(db, 'project:a'), ProjectStatus.settled);
    expect(await db.query('sync_outbox'), isEmpty);
    expect(await db.query('entity_sync_meta'), isEmpty);
  });

  test(
    '删除撤销结清时写入 timing_record delete、ProjectWriteOff delete 和 project update',
    () async {
      final db = await AppDatabase.database;
      await _insertProject(
        db,
        id: 'project:a',
        status: ProjectStatus.settled,
        settledAt: '2026-05-20T00:00:00.000Z',
        settledSnapshot: '{"remaining":0}',
      );
      final keepId = await _insertTiming(projectId: 'project:a');
      final deleteId = await _insertTiming(projectId: 'project:a');
      await _insertWriteOff(
        db,
        'project:a',
        id: 'writeoff-a-1',
        amount: 100,
        note: 'first',
      );
      await _insertWriteOff(
        db,
        'project:a',
        id: 'writeoff-a-2',
        amount: 80.25,
        writeOffDate: '2026-05-21',
      );

      final outcome = await _useCase().executeDeleteWithImpact(deleteId);

      expect(outcome.settlementRevoked, isTrue);
      expect(await SqfliteTimingRepository().findById(deleteId), isNull);
      expect(await SqfliteTimingRepository().findById(keepId), isNotNull);
      expect(await db.query('project_write_offs'), isEmpty);
      final project = await SqfliteProjectRepository().findById('project:a');
      expect(project?.status, ProjectStatus.active);
      expect(project?.settledAt, isNull);
      expect(project?.settledSnapshot, isNull);

      final outboxRows = await db.query('sync_outbox');
      expect(outboxRows, hasLength(4));
      _expectUniqueOutboxIds(outboxRows);
      final timingRows = _outboxRows(
        outboxRows,
        entityType: 'timing_record',
        operation: 'delete',
      );
      final writeOffRows = _outboxRows(
        outboxRows,
        entityType: ProjectWriteOffSyncEnqueuer.entityType,
        operation: 'delete',
      );
      final projectRows = _outboxRows(
        outboxRows,
        entityType: ProjectSyncEnqueuer.entityType,
        operation: 'update',
      );
      expect(timingRows, hasLength(1));
      expect(writeOffRows, hasLength(2));
      expect(projectRows, hasLength(1));
      expect(
        _outboxRows(
          outboxRows,
          entityType: ProjectWriteOffSyncEnqueuer.entityType,
          operation: 'create',
        ),
        isEmpty,
      );
      expect(
        _outboxRows(
          outboxRows,
          entityType: 'account_payment',
          operation: 'delete',
        ),
        isEmpty,
      );
      expect(writeOffRows.map((row) => row['id']).toSet(), hasLength(2));
      expect(writeOffRows.map((row) => row['entity_id']).toSet(), {
        'writeoff-a-1',
        'writeoff-a-2',
      });

      final firstWriteOff = _payloadRecord(
        _singleOutboxRow(writeOffRows, entityId: 'writeoff-a-1'),
      );
      expect(firstWriteOff['id'], 'writeoff-a-1');
      expect(firstWriteOff['project_id'], 'project:a');
      expect(firstWriteOff.containsKey('amount'), isFalse);
      expect(firstWriteOff['amount_fen'], 10000);
      expect(firstWriteOff['reason'], ProjectWriteOffReason.settlement.dbValue);
      expect(firstWriteOff['write_off_date'], '2026-05-20');
      expect(firstWriteOff['note'], 'first');

      final secondWriteOff = _payloadRecord(
        _singleOutboxRow(writeOffRows, entityId: 'writeoff-a-2'),
      );
      expect(secondWriteOff['id'], 'writeoff-a-2');
      expect(secondWriteOff['amount_fen'], 8025);
      expect(secondWriteOff['write_off_date'], '2026-05-21');

      final projectRecord = _payloadRecord(projectRows.single);
      expect(projectRecord['id'], 'project:a');
      expect(projectRecord['status'], ProjectStatus.active.name);
      expect(projectRecord['settled_at'], isNull);
      expect(projectRecord['settled_snapshot'], isNull);
      expect(projectRecord['updated_at'], '2026-06-01T12:00:00.000Z');

      final metaRows = await db.query('entity_sync_meta');
      expect(metaRows, hasLength(4));
      _expectMetaMatchesOutbox(
        outboxRows,
        metaRows,
        entityType: 'timing_record',
        entityId: deleteId.toString(),
        status: SyncStatus.pendingDelete,
      );
      for (final writeOffId in const ['writeoff-a-1', 'writeoff-a-2']) {
        _expectMetaMatchesOutbox(
          outboxRows,
          metaRows,
          entityType: ProjectWriteOffSyncEnqueuer.entityType,
          entityId: writeOffId,
          status: SyncStatus.pendingDelete,
        );
      }
      _expectMetaMatchesOutbox(
        outboxRows,
        metaRows,
        entityType: ProjectSyncEnqueuer.entityType,
        entityId: 'project:a',
        status: SyncStatus.pendingUpdate,
      );
    },
  );

  test('删除最后一条计时记录时：ExternalWork 解绑与 delete outbox 同事务落库', () async {
    final db = await AppDatabase.database;
    await _insertProject(db, id: 'project:a');
    final recordId = await _insertTiming(projectId: 'project:a');
    await _insertLinkedExternalWorkRecords(projectId: 'project:a');

    final outcome = await _useCase().executeDeleteWithImpact(recordId);

    expect(outcome.externalWorkUnlinked, isTrue);
    expect(await SqfliteTimingRepository().findById(recordId), isNull);
    final externalRecords = await SqfliteExternalWorkRecordRepository()
        .listByBatchId('external-batch-1');
    expect(externalRecords, hasLength(2));
    expect(
      externalRecords.every((record) => record.linkedProjectId == null),
      isTrue,
    );
    expect(externalRecords.map((record) => record.updatedAt).toSet(), {
      '2026-06-01T12:00:00.000Z',
    });

    final outboxRows = await db.query('sync_outbox');
    expect(outboxRows, hasLength(3));
    _expectUniqueOutboxIds(outboxRows);
    expect(
      _outboxRows(outboxRows, entityType: 'timing_record', operation: 'delete'),
      hasLength(1),
    );
    final externalRows = _outboxRows(
      outboxRows,
      entityType: ExternalWorkSyncEnqueuer.entityType,
      operation: 'update',
    );
    expect(externalRows, hasLength(2));
    expect(externalRows.map((row) => row['entity_id']).toSet(), {
      'external-record-a',
      'external-record-b',
    });
    for (final row in externalRows) {
      final record = _payloadRecord(row);
      expect(record['linked_project_id'], isNull);
      expect(record['updated_at'], '2026-06-01T12:00:00.000Z');
    }

    final metaRows = await db.query('entity_sync_meta');
    expect(metaRows, hasLength(3));
    _expectMetaMatchesOutbox(
      outboxRows,
      metaRows,
      entityType: 'timing_record',
      entityId: recordId.toString(),
      status: SyncStatus.pendingDelete,
    );
    for (final externalRecordId in const [
      'external-record-a',
      'external-record-b',
    ]) {
      _expectMetaMatchesOutbox(
        outboxRows,
        metaRows,
        entityType: ExternalWorkSyncEnqueuer.entityType,
        entityId: externalRecordId,
        status: SyncStatus.pendingUpdate,
      );
    }
  });

  test('analyzeImpact 只读：不删核销、不恢复项目、不入队 sync', () async {
    final db = await AppDatabase.database;
    await _insertProject(
      db,
      id: 'project:a',
      status: ProjectStatus.settled,
      settledAt: '2026-05-20T00:00:00.000Z',
      settledSnapshot: '{"remaining":0}',
    );
    final recordId = await _insertTiming(projectId: 'project:a');
    await _insertWriteOff(db, 'project:a');

    final impact = await _useCase().analyzeImpact(recordId);

    expect(impact.requiresSettlementRevoke, isTrue);
    expect(await SqfliteTimingRepository().findById(recordId), isNotNull);
    expect(await db.query('project_write_offs'), hasLength(1));
    expect(await _projectStatus(db, 'project:a'), ProjectStatus.settled);
    expect(await db.query('sync_outbox'), isEmpty);
    expect(await db.query('entity_sync_meta'), isEmpty);
  });

  test('timing_record outbox 写失败：删除 + 撤销结清整体回滚，不留半条', () async {
    final db = await AppDatabase.database;
    // 已结清项目 + 核销：删除会触发撤销结清（删核销 + 恢复 active）。
    await _insertProject(
      db,
      id: 'project:a',
      status: ProjectStatus.settled,
      settledAt: '2026-05-20T00:00:00.000Z',
      settledSnapshot: '{"remaining":0}',
    );
    final keepId = await _insertTiming(projectId: 'project:a');
    final deleteId = await _insertTiming(projectId: 'project:a');
    await _insertWriteOff(db, 'project:a');

    final failingUseCase = _useCase(
      syncOutboxRepository: const _ThrowingSyncOutboxRepository(
        entityType: 'timing_record',
        operation: 'delete',
      ),
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

  test('timing_record meta 写失败：新增 cascade outbox 也整体回滚', () async {
    final db = await AppDatabase.database;
    final deleteId = await _seedSettledProjectCascade(db);

    final failingUseCase = _useCase(
      entitySyncMetaRepository: const _ThrowingEntitySyncMetaRepository(
        entityType: 'timing_record',
      ),
    );

    await expectLater(
      failingUseCase.executeDeleteWithImpact(deleteId),
      throwsA(isA<StateError>()),
    );

    await _expectCascadeRolledBack(db, deleteId: deleteId);
  });

  test(
    'ProjectWriteOff delete outbox 失败：整笔 timing delete cascade 回滚',
    () async {
      final db = await AppDatabase.database;
      final deleteId = await _seedSettledProjectCascade(db);

      final failingUseCase = _useCase(
        syncOutboxRepository: const _ThrowingSyncOutboxRepository(
          entityType: ProjectWriteOffSyncEnqueuer.entityType,
          operation: 'delete',
        ),
      );

      await expectLater(
        failingUseCase.executeDeleteWithImpact(deleteId),
        throwsA(isA<StateError>()),
      );

      await _expectCascadeRolledBack(db, deleteId: deleteId);
    },
  );

  test('ProjectWriteOff delete meta 失败：整笔 timing delete cascade 回滚', () async {
    final db = await AppDatabase.database;
    final deleteId = await _seedSettledProjectCascade(db);

    final failingUseCase = _useCase(
      entitySyncMetaRepository: const _ThrowingEntitySyncMetaRepository(
        entityType: ProjectWriteOffSyncEnqueuer.entityType,
      ),
    );

    await expectLater(
      failingUseCase.executeDeleteWithImpact(deleteId),
      throwsA(isA<StateError>()),
    );

    await _expectCascadeRolledBack(db, deleteId: deleteId);
  });

  test('project update outbox 失败：整笔 timing delete cascade 回滚', () async {
    final db = await AppDatabase.database;
    final deleteId = await _seedSettledProjectCascade(db);

    final failingUseCase = _useCase(
      syncOutboxRepository: const _ThrowingSyncOutboxRepository(
        entityType: ProjectSyncEnqueuer.entityType,
        operation: 'update',
      ),
    );

    await expectLater(
      failingUseCase.executeDeleteWithImpact(deleteId),
      throwsA(isA<StateError>()),
    );

    await _expectCascadeRolledBack(db, deleteId: deleteId);
  });

  test('project update meta 失败：整笔 timing delete cascade 回滚', () async {
    final db = await AppDatabase.database;
    final deleteId = await _seedSettledProjectCascade(db);

    final failingUseCase = _useCase(
      entitySyncMetaRepository: const _ThrowingEntitySyncMetaRepository(
        entityType: ProjectSyncEnqueuer.entityType,
      ),
    );

    await expectLater(
      failingUseCase.executeDeleteWithImpact(deleteId),
      throwsA(isA<StateError>()),
    );

    await _expectCascadeRolledBack(db, deleteId: deleteId);
  });

  test('ExternalWork update outbox 失败：整笔 timing delete cascade 回滚', () async {
    final db = await AppDatabase.database;
    final deleteId = await _seedSettledProjectCascadeWithExternalWork(db);

    final failingUseCase = _useCase(
      syncOutboxRepository: const _ThrowingSyncOutboxRepository(
        entityType: ExternalWorkSyncEnqueuer.entityType,
        operation: 'update',
      ),
    );

    await expectLater(
      failingUseCase.executeDeleteWithImpact(deleteId),
      throwsA(isA<StateError>()),
    );

    await _expectCascadeWithExternalWorkRolledBack(db, deleteId: deleteId);
  });

  test('ExternalWork update meta 失败：整笔 timing delete cascade 回滚', () async {
    final db = await AppDatabase.database;
    final deleteId = await _seedSettledProjectCascadeWithExternalWork(db);

    final failingUseCase = _useCase(
      entitySyncMetaRepository: const _ThrowingEntitySyncMetaRepository(
        entityType: ExternalWorkSyncEnqueuer.entityType,
      ),
    );

    await expectLater(
      failingUseCase.executeDeleteWithImpact(deleteId),
      throwsA(isA<StateError>()),
    );

    await _expectCascadeWithExternalWorkRolledBack(db, deleteId: deleteId);
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
  const _ThrowingSyncOutboxRepository({this.entityType, this.operation});

  final String? entityType;
  final String? operation;

  @override
  Future<SyncOutboxEntry> enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
    String? transactionGroupId,
    int? localSequence,
  }) {
    _throwIfMatched(entityType: entityType, operation: operation);
    return const LocalSyncOutboxRepository().enqueue(
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
    );
  }

  @override
  Future<SyncOutboxEntry> enqueueWithExecutor(
    DatabaseExecutor executor, {
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
    String? transactionGroupId,
    int? localSequence,
  }) {
    _throwIfMatched(entityType: entityType, operation: operation);
    return const LocalSyncOutboxRepository().enqueueWithExecutor(
      executor,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
    );
  }

  @override
  Future<List<SyncOutboxEntry>> listPending({int limit = 50}) async {
    return const [];
  }

  void _throwIfMatched({
    required String entityType,
    required String operation,
  }) {
    final entityMatched =
        this.entityType == null || this.entityType == entityType;
    final operationMatched =
        this.operation == null || this.operation == operation;
    if (entityMatched && operationMatched) {
      throw StateError('注入的失败：sync_outbox 写入失败');
    }
  }
}

class _ThrowingEntitySyncMetaRepository implements EntitySyncMetaRepository {
  const _ThrowingEntitySyncMetaRepository({this.entityType});

  final String? entityType;

  @override
  Future<void> upsert(EntitySyncMeta meta) {
    throw StateError('注入的失败：entity_sync_meta 写入失败');
  }

  @override
  Future<void> upsertWithExecutor(
    DatabaseExecutor executor,
    EntitySyncMeta meta,
  ) {
    if (entityType == null || entityType == meta.entityType) {
      throw StateError('注入的失败：entity_sync_meta 写入失败');
    }
    return const LocalEntitySyncMetaRepository().upsertWithExecutor(
      executor,
      meta,
    );
  }

  @override
  Future<EntitySyncMeta?> find({
    required String entityType,
    required String localId,
  }) async {
    return null;
  }
}

DeleteTimingRecordWithImpactUseCase _useCase({
  SyncOutboxRepository? syncOutboxRepository,
  EntitySyncMetaRepository? entitySyncMetaRepository,
}) {
  return LocalDeleteTimingRecordWithImpactUseCase(
    timingRepository: SqfliteTimingRepository(),
    paymentRepository: SqfliteAccountPaymentRepository(),
    mergeRepository: SqfliteAccountProjectMergeRepository(),
    externalWorkRecordRepository: SqfliteExternalWorkRecordRepository(),
    writeOffRepository: SqfliteProjectWriteOffRepository(),
    projectRepository: SqfliteProjectRepository(),
    syncOutboxRepository: syncOutboxRepository,
    entitySyncMetaRepository: entitySyncMetaRepository,
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
  String? settledSnapshot,
}) async {
  await db.insert(
    'projects',
    Project(
      id: id,
      contact: contact,
      site: site,
      status: status,
      settledAt: settledAt,
      settledSnapshot: settledSnapshot,
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

Future<void> _insertWriteOff(
  Database db,
  String projectId, {
  String? id,
  double amount = 100,
  String? note,
  String writeOffDate = '2026-05-20',
}) async {
  await db.insert(
    'project_write_offs',
    ProjectWriteOff(
      id: id ?? 'writeoff-$projectId',
      projectId: projectId,
      amount: amount,
      reason: ProjectWriteOffReason.settlement.dbValue,
      note: note,
      writeOffDate: writeOffDate,
      createdAt: '2026-05-20T00:00:00.000Z',
      updatedAt: '2026-05-20T00:00:00.000Z',
    ).toMap(),
  );
}

Future<List<ExternalWorkRecord>> _insertLinkedExternalWorkRecords({
  required String projectId,
}) async {
  await SqfliteExternalImportRepository().insertBatch(
    ExternalImportBatch(
      id: 'external-batch-1',
      sourceShareId: 'external-share-1',
      sourceDisplayName: '王师傅',
      recordCount: 2,
      totalHoursMilli: 3000,
      totalAmountFen: 90000,
      siteSummary: '工地',
      importedAt: '2026-05-18T00:00:00.000Z',
      createdAt: '2026-05-18T00:00:00.000Z',
      updatedAt: '2026-05-18T00:00:00.000Z',
    ),
  );
  final records = [
    _externalWorkRecord(
      id: 'external-record-a',
      sourceRecordUuid: 'external-source-a',
      projectId: projectId,
    ),
    _externalWorkRecord(
      id: 'external-record-b',
      sourceRecordUuid: 'external-source-b',
      projectId: projectId,
    ),
  ];
  await SqfliteExternalWorkRecordRepository().insertRecords(records);
  return records;
}

ExternalWorkRecord _externalWorkRecord({
  required String id,
  required String sourceRecordUuid,
  required String projectId,
}) {
  return ExternalWorkRecord.create(
    id: id,
    importBatchId: 'external-batch-1',
    sourceShareId: 'external-share-1',
    sourceRecordUuid: sourceRecordUuid,
    sourceInstallationUuid: 'external-installation',
    originFingerprint: 'fingerprint-$sourceRecordUuid',
    collaboratorName: '王师傅',
    contactSnapshot: '甲方',
    siteSnapshot: '工地',
    equipmentBrand: '三一',
    equipmentModel: '75',
    equipmentType: 'excavator',
    workDate: 20260518,
    hoursMilli: 1500,
    sourceUnitPriceFen: 30000,
    projectReceivedFen: 0,
    linkedProjectId: projectId,
    createdAt: '2026-05-18T00:00:00.000Z',
    updatedAt: '2026-05-18T00:00:00.000Z',
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

Future<ProjectStatus> _projectStatus(Database db, String id) async {
  final rows = await db.query(
    'projects',
    where: 'id = ?',
    whereArgs: [id],
    limit: 1,
  );
  return Project.fromMap(rows.single).status;
}

Future<int> _seedSettledProjectCascade(Database db) async {
  await _insertProject(
    db,
    id: 'project:a',
    status: ProjectStatus.settled,
    settledAt: '2026-05-20T00:00:00.000Z',
    settledSnapshot: '{"remaining":0}',
  );
  await _insertTiming(projectId: 'project:a');
  final deleteId = await _insertTiming(projectId: 'project:a');
  await _insertWriteOff(db, 'project:a', id: 'writeoff-a-1');
  await _insertWriteOff(db, 'project:a', id: 'writeoff-a-2', amount: 50);
  return deleteId;
}

Future<int> _seedSettledProjectCascadeWithExternalWork(Database db) async {
  await _insertProject(
    db,
    id: 'project:a',
    status: ProjectStatus.settled,
    settledAt: '2026-05-20T00:00:00.000Z',
    settledSnapshot: '{"remaining":0}',
  );
  final deleteId = await _insertTiming(projectId: 'project:a');
  await _insertWriteOff(db, 'project:a', id: 'writeoff-a-1');
  await _insertWriteOff(db, 'project:a', id: 'writeoff-a-2', amount: 50);
  await _insertLinkedExternalWorkRecords(projectId: 'project:a');
  return deleteId;
}

Future<void> _expectCascadeRolledBack(
  Database db, {
  required int deleteId,
}) async {
  expect(await SqfliteTimingRepository().findById(deleteId), isNotNull);
  expect(await db.query('project_write_offs'), hasLength(2));
  final project = await SqfliteProjectRepository().findById('project:a');
  expect(project?.status, ProjectStatus.settled);
  expect(project?.settledAt, '2026-05-20T00:00:00.000Z');
  expect(project?.settledSnapshot, '{"remaining":0}');
  expect(await db.query('sync_outbox'), isEmpty);
  expect(await db.query('entity_sync_meta'), isEmpty);
}

Future<void> _expectCascadeWithExternalWorkRolledBack(
  Database db, {
  required int deleteId,
}) async {
  await _expectCascadeRolledBack(db, deleteId: deleteId);
  final externalRecords = await SqfliteExternalWorkRecordRepository()
      .listByBatchId('external-batch-1');
  expect(externalRecords, hasLength(2));
  expect(externalRecords.map((record) => record.linkedProjectId).toSet(), {
    'project:a',
  });
  expect(externalRecords.map((record) => record.updatedAt).toSet(), {
    '2026-05-18T00:00:00.000Z',
  });
}

List<Map<String, Object?>> _outboxRows(
  List<Map<String, Object?>> rows, {
  required String entityType,
  String? operation,
}) {
  return rows
      .where(
        (row) =>
            row['entity_type'] == entityType &&
            (operation == null || row['operation'] == operation),
      )
      .toList(growable: false);
}

Map<String, Object?> _singleOutboxRow(
  List<Map<String, Object?>> rows, {
  required String entityId,
}) {
  return rows.singleWhere((row) => row['entity_id'] == entityId);
}

Map<String, Object?> _payloadRecord(Map<String, Object?> outboxRow) {
  final payload =
      jsonDecode(outboxRow['payload_json'] as String) as Map<String, Object?>;
  return payload['record'] as Map<String, Object?>;
}

void _expectMetaMatchesOutbox(
  List<Map<String, Object?>> outboxRows,
  List<Map<String, Object?>> metaRows, {
  required String entityType,
  required String entityId,
  required SyncStatus status,
}) {
  final outbox = outboxRows.singleWhere(
    (row) => row['entity_type'] == entityType && row['entity_id'] == entityId,
  );
  final meta = metaRows.singleWhere(
    (row) => row['entity_type'] == entityType && row['local_id'] == entityId,
  );
  expect(meta['sync_status'], status.name);
  expect(meta['source'], 'owner_app');
  expect(meta['version'], 0);
  expect(meta['payload_hash'], outbox['payload_hash']);
}

void _expectUniqueOutboxIds(List<Map<String, Object?>> rows) {
  expect(rows.map((row) => row['id']).toSet(), hasLength(rows.length));
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
