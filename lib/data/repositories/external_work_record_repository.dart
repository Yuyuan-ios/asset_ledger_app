import 'package:sqflite/sqflite.dart';

import '../../core/errors/external_work_errors.dart';
import '../../core/operations/operation_access_control.dart';
import '../../infrastructure/local/account/project_sync_enqueuer.dart';
import '../../infrastructure/local/account/project_write_off_sync_enqueuer.dart';
import '../../infrastructure/local/timing/external_work_sync_enqueuer.dart';
import '../../infrastructure/sync/sync_actor.dart';
import '../../infrastructure/sync/sync_transaction_group.dart';
import '../db/database.dart';
import '../models/external_work_record.dart';
import 'external_import_repository.dart';
import 'project_repository.dart';
import 'project_write_off_repository.dart';

abstract class ExternalWorkRecordRepository {
  Future<void> insertRecord(ExternalWorkRecord record);

  Future<void> insertRecords(List<ExternalWorkRecord> records);

  Future<List<ExternalWorkRecord>> listByBatchId(String batchId);

  Future<List<ExternalWorkRecord>> listByLinkedProjectId(String projectId);

  Future<int> deleteById(String recordId);

  Future<int> deleteByBatchId(String batchId);

  /// 把整个 importBatch 关联到一个本地项目：事务化地把该 batch 下所有记录的
  /// `linked_project_id` 统一写成 [projectId]，保证"一包一项目、同包一致"。
  /// 返回受影响的记录数；若该 batch 已无可更新记录（0 行），抛出
  /// [ExternalWorkBatchUnavailableException]，绝不静默成功。
  Future<int> linkBatchToProject({
    required String importBatchId,
    required String projectId,
    required String updatedAt,
  });

  /// 原子地"关联到已结清项目"：在同一个事务里完成
  /// (1) link batch → project，(2) 删除该项目核销记录，(3) 已结清则恢复未结清。
  /// 任一步失败（含 batch 0 行）整体回滚，避免"撤销结清成功但关联失败"的中间态。
  /// 返回关联到的记录数。
  Future<int> linkBatchToProjectWithSettlementReset({
    required String importBatchId,
    required String projectId,
    required String updatedAt,
  });

  /// 解除整个 importBatch 的关联：事务化地把该 batch 下所有记录的
  /// `linked_project_id` 清空（不删除任何外协记录）。返回受影响的记录数；
  /// 若该 batch 已无可更新记录（0 行），抛出
  /// [ExternalWorkBatchUnavailableException]。
  Future<int> unlinkBatch({
    required String importBatchId,
    required String updatedAt,
  });

  /// 读取某个 importBatch 的关联项目 id；未关联或 batch 不存在返回 null。
  Future<String?> getLinkedProjectId(String importBatchId);

  Future<int> updateLocalFields({
    required String recordId,
    int? localUnitPriceFen,
    Object? linkedProjectId = _sentinel,
    ExternalWorkRecordStatus? status,
    Object? note = _sentinel,
    required String updatedAt,
  });

  /// 设置整个 importBatch 内 hours 记录的客户侧应收单价（分）。
  ///
  /// 只写 `customer_unit_price_fen`，**不动 amountFen**（外协应付在分享人侧已定、
  /// 不可改）。null = 清除客户单价（应收回退到应付金额）。批内记录共享一个
  /// sync group 入 outbox（参照 [linkBatchToProject]）。返回受影响行数。
  Future<int> setBatchCustomerUnitPriceFen({
    required String importBatchId,
    required int? customerUnitPriceFen,
    required String updatedAt,
  });
}

class SqfliteExternalWorkRecordRepository
    implements ExternalWorkRecordRepository {
  const SqfliteExternalWorkRecordRepository({
    ExternalWorkSyncEnqueuer syncEnqueuer = const ExternalWorkSyncEnqueuer(),
    ProjectWriteOffSyncEnqueuer projectWriteOffSyncEnqueuer =
        const ProjectWriteOffSyncEnqueuer(),
    ProjectSyncEnqueuer projectSyncEnqueuer = const ProjectSyncEnqueuer(),
    SyncActorProvider? actorProvider,
  }) : _syncEnqueuer = syncEnqueuer,
       _projectWriteOffSyncEnqueuer = projectWriteOffSyncEnqueuer,
       _projectSyncEnqueuer = projectSyncEnqueuer,
       _actorProvider = actorProvider;

  static const String table = 'external_work_records';
  static const SqfliteProjectWriteOffRepository _writeOffRepository =
      SqfliteProjectWriteOffRepository();
  static const SqfliteProjectRepository _projectRepository =
      SqfliteProjectRepository();

  final ExternalWorkSyncEnqueuer _syncEnqueuer;
  final ProjectWriteOffSyncEnqueuer _projectWriteOffSyncEnqueuer;
  final ProjectSyncEnqueuer _projectSyncEnqueuer;
  final SyncActorProvider? _actorProvider;

  @override
  Future<void> insertRecord(ExternalWorkRecord record) async {
    final db = await AppDatabase.database;
    await insertRecordWithExecutor(db, record);
  }

  @override
  Future<void> insertRecords(List<ExternalWorkRecord> records) async {
    if (records.isEmpty) return;
    await AppDatabase.inTransaction<void>((txn) async {
      await insertRecordsWithExecutor(txn, records: records);
    });
  }

  @override
  Future<List<ExternalWorkRecord>> listByBatchId(String batchId) async {
    final db = await AppDatabase.database;
    return listByBatchIdWithExecutor(db, batchId);
  }

  @override
  Future<List<ExternalWorkRecord>> listByLinkedProjectId(
    String projectId,
  ) async {
    final db = await AppDatabase.database;
    return listByLinkedProjectIdWithExecutor(db, projectId);
  }

  @override
  Future<int> deleteById(String recordId) async {
    final normalized = recordId.trim();
    if (normalized.isEmpty) return 0;
    return AppDatabase.inTransaction<int>((txn) async {
      final snapshot = await findByIdWithExecutor(txn, normalized);
      if (snapshot == null) return 0;

      final batchId = snapshot.importBatchId;
      final deleted = await deleteByIdWithExecutor(txn, normalized);
      if (deleted == 0) return 0;
      await _syncEnqueuer.enqueueDelete(
        txn,
        record: snapshot,
        actor: _actorProvider?.call(),
      );

      final remaining = await txn.query(
        table,
        columns: const ['id'],
        where: 'import_batch_id = ?',
        whereArgs: [batchId],
        limit: 1,
      );
      if (remaining.isEmpty) {
        await txn.delete(
          SqfliteExternalImportRepository.table,
          where: 'id = ?',
          whereArgs: [batchId],
        );
      }
      return deleted;
    });
  }

  @override
  Future<int> deleteByBatchId(String batchId) async {
    final normalized = batchId.trim();
    if (normalized.isEmpty) return 0;
    return AppDatabase.inTransaction<int>((txn) async {
      // R5.22-A：删除整个 batch 的多条 external_work delete outbox 共享一个 group。
      final group = SyncTransactionGroup.create();
      final actor = _actorProvider?.call();
      final snapshots = await listByBatchIdWithExecutor(txn, normalized);
      final deleted = await deleteByBatchIdWithExecutor(txn, normalized);
      if (deleted == 0) return 0;
      for (final snapshot in snapshots) {
        await _syncEnqueuer.enqueueDelete(
          txn,
          record: snapshot,
          transactionGroupId: group.id,
          localSequence: group.nextSequence(),
          actor: actor,
        );
      }

      await txn.delete(
        SqfliteExternalImportRepository.table,
        where: 'id = ?',
        whereArgs: [normalized],
      );
      return deleted;
    });
  }

  @override
  Future<int> linkBatchToProject({
    required String importBatchId,
    required String projectId,
    required String updatedAt,
  }) async {
    final normalizedBatchId = importBatchId.trim();
    final normalizedProjectId = _requireProjectId(projectId);
    return AppDatabase.inTransaction<int>((txn) async {
      // R5.22-A：把整个 batch 关联到项目会对该 batch 的每条记录写一条 update
      // outbox，共享一个 group id。
      final group = SyncTransactionGroup.create();
      final linked = await linkBatchToProjectWithExecutor(
        txn,
        importBatchId: normalizedBatchId,
        projectId: normalizedProjectId,
        updatedAt: updatedAt,
      );
      await _enqueueBatchUpdates(
        txn,
        batchId: normalizedBatchId,
        group: group,
        actor: _actorProvider?.call(),
      );
      return linked;
    });
  }

  @override
  Future<int> linkBatchToProjectWithSettlementReset({
    required String importBatchId,
    required String projectId,
    required String updatedAt,
  }) async {
    final normalizedBatchId = importBatchId.trim();
    final normalizedProjectId = _requireProjectId(projectId);
    return AppDatabase.inTransaction<int>((txn) async {
      // R5.22-A：settlement reset 是跨 ExternalWork / ProjectWriteOff / Project
      // 的同事务 cluster（strategy invariant 标注的 cloud-push 重点）。所有 outbox
      // 共享一个 group id，local_sequence 按 external work updates → writeOff
      // deletes → project update 的因果顺序递增。
      final group = SyncTransactionGroup.create();
      final actor = _actorProvider?.call();
      // 1) 先写关联：batch 已不存在（0 行）会抛异常，使整个事务回滚，
      //    确保不会出现"撤销结清成功但关联失败"的中间态。
      final linked = await linkBatchToProjectWithExecutor(
        txn,
        importBatchId: normalizedBatchId,
        projectId: normalizedProjectId,
        updatedAt: updatedAt,
      );
      await _enqueueBatchUpdates(
        txn,
        batchId: normalizedBatchId,
        group: group,
        actor: actor,
      );

      // 2) 同事务内撤销结清：删除该项目核销记录 + 已结清恢复未结清。
      final writeOffSnapshots = await _writeOffRepository
          .listByProjectIdWithExecutor(txn, normalizedProjectId);
      for (final writeOff in writeOffSnapshots) {
        final deleted = await _writeOffRepository.deleteByIdWithExecutor(
          txn,
          writeOff.id,
        );
        if (deleted > 0) {
          await _projectWriteOffSyncEnqueuer.enqueueDelete(
            txn,
            writeOff,
            transactionGroupId: group.id,
            localSequence: group.nextSequence(),
            actor: actor,
          );
        }
      }

      final restoredActive = await _projectRepository.restoreActiveWithExecutor(
        txn,
        projectId: normalizedProjectId,
        updatedAt: updatedAt,
      );
      if (restoredActive) {
        final project = await _projectRepository.findByIdWithExecutor(
          txn,
          normalizedProjectId,
        );
        if (project == null) {
          throw StateError('Project sync enqueue requires project snapshot');
        }
        await _projectSyncEnqueuer.enqueueUpdate(
          txn,
          project: project,
          transactionGroupId: group.id,
          localSequence: group.nextSequence(),
          actor: actor,
        );
      }

      return linked;
    });
  }

  @override
  Future<int> unlinkBatch({
    required String importBatchId,
    required String updatedAt,
  }) async {
    final normalizedBatchId = importBatchId.trim();
    return AppDatabase.inTransaction<int>((txn) async {
      // R5.22-A：解除 batch 关联的多条 update outbox 共享一个 group id。
      final group = SyncTransactionGroup.create();
      final unlinked = await unlinkBatchWithExecutor(
        txn,
        importBatchId: normalizedBatchId,
        updatedAt: updatedAt,
      );
      await _enqueueBatchUpdates(
        txn,
        batchId: normalizedBatchId,
        group: group,
        actor: _actorProvider?.call(),
      );
      return unlinked;
    });
  }

  static String _requireProjectId(String projectId) {
    final normalized = projectId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(projectId, 'projectId', '关联项目 id 不能为空');
    }
    return normalized;
  }

  Future<List<String>> insertRecordsWithExecutor(
    DatabaseExecutor executor, {
    required List<ExternalWorkRecord> records,
  }) async {
    final ids = <String>[];
    for (final record in records) {
      await insertRecordWithExecutor(executor, record);
      ids.add(record.id);
    }
    return ids;
  }

  Future<ExternalWorkRecord?> findByIdWithExecutor(
    DatabaseExecutor executor,
    String id,
  ) async {
    final normalized = id.trim();
    if (normalized.isEmpty) return null;
    final rows = await executor.query(
      table,
      where: 'id = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ExternalWorkRecord.fromMap(rows.single);
  }

  Future<List<ExternalWorkRecord>> listByBatchIdWithExecutor(
    DatabaseExecutor executor,
    String batchId,
  ) async {
    final normalized = batchId.trim();
    if (normalized.isEmpty) return const [];
    final rows = await executor.query(
      table,
      where: 'import_batch_id = ?',
      whereArgs: [normalized],
      orderBy: 'work_date ASC, id ASC',
    );
    return rows.map(ExternalWorkRecord.fromMap).toList();
  }

  Future<List<ExternalWorkRecord>> listByLinkedProjectIdWithExecutor(
    DatabaseExecutor executor,
    String projectId,
  ) async {
    final normalized = projectId.trim();
    if (normalized.isEmpty) return const [];
    final rows = await executor.query(
      table,
      where: 'linked_project_id = ?',
      whereArgs: [normalized],
      orderBy: 'work_date ASC, id ASC',
    );
    return rows.map(ExternalWorkRecord.fromMap).toList();
  }

  Future<int> updateWithExecutor(
    DatabaseExecutor executor,
    ExternalWorkRecord record,
  ) async {
    final normalized = record.id.trim();
    if (normalized.isEmpty) return 0;
    return executor.update(
      table,
      record.toMap(),
      where: 'id = ?',
      whereArgs: [normalized],
    );
  }

  Future<int> deleteByIdWithExecutor(
    DatabaseExecutor executor,
    String id,
  ) async {
    final normalized = id.trim();
    if (normalized.isEmpty) return 0;
    return executor.delete(table, where: 'id = ?', whereArgs: [normalized]);
  }

  Future<int> deleteByBatchIdWithExecutor(
    DatabaseExecutor executor,
    String batchId,
  ) async {
    final normalized = batchId.trim();
    if (normalized.isEmpty) return 0;
    return executor.delete(
      table,
      where: 'import_batch_id = ?',
      whereArgs: [normalized],
    );
  }

  /// 在给定执行器（事务）内把 batch 的所有记录关联到项目；0 行抛异常。
  Future<int> linkBatchToProjectWithExecutor(
    DatabaseExecutor executor, {
    required String importBatchId,
    required String projectId,
    required String updatedAt,
  }) async {
    final normalizedBatchId = importBatchId.trim();
    final normalizedProjectId = _requireProjectId(projectId);
    final count = await executor.update(
      table,
      {'linked_project_id': normalizedProjectId, 'updated_at': updatedAt},
      where: 'import_batch_id = ?',
      whereArgs: [normalizedBatchId],
    );
    if (count == 0) {
      throw ExternalWorkBatchUnavailableException();
    }
    return count;
  }

  Future<int> unlinkBatchWithExecutor(
    DatabaseExecutor executor, {
    required String importBatchId,
    required String updatedAt,
  }) async {
    final normalizedBatchId = importBatchId.trim();
    final count = await executor.update(
      table,
      {'linked_project_id': null, 'updated_at': updatedAt},
      where: 'import_batch_id = ?',
      whereArgs: [normalizedBatchId],
    );
    if (count == 0) {
      throw ExternalWorkBatchUnavailableException();
    }
    return count;
  }

  @override
  Future<String?> getLinkedProjectId(String importBatchId) async {
    final normalized = importBatchId.trim();
    if (normalized.isEmpty) return null;
    final db = await AppDatabase.database;
    final rows = await db.query(
      table,
      columns: const ['linked_project_id'],
      where: 'import_batch_id = ? AND linked_project_id IS NOT NULL',
      whereArgs: [normalized],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.single['linked_project_id'] as String?;
  }

  // 删除影响协调器使用的具体读/写辅助（不纳入抽象接口）。
  Future<int> countLinkedBatchesByProjectId(String projectId) async {
    final db = await AppDatabase.database;
    return countLinkedBatchesByProjectIdWithExecutor(db, projectId);
  }

  Future<int> countLinkedBatchesByProjectIdWithExecutor(
    DatabaseExecutor executor,
    String projectId,
  ) async {
    final normalized = projectId.trim();
    if (normalized.isEmpty) return 0;
    final rows = await executor.rawQuery(
      'SELECT COUNT(DISTINCT import_batch_id) AS count FROM $table '
      'WHERE linked_project_id = ?',
      [normalized],
    );
    return (rows.single['count'] as num?)?.toInt() ?? 0;
  }

  Future<int> unlinkByProjectIdWithExecutor(
    DatabaseExecutor executor, {
    required String projectId,
    required String updatedAt,
  }) async {
    final normalized = projectId.trim();
    if (normalized.isEmpty) return 0;
    return executor.update(
      table,
      {'linked_project_id': null, 'updated_at': updatedAt},
      where: 'linked_project_id = ?',
      whereArgs: [normalized],
    );
  }

  Future<void> _enqueueBatchUpdates(
    DatabaseExecutor executor, {
    required String batchId,
    SyncTransactionGroup? group,
    ActorContext? actor,
  }) async {
    final snapshots = await listByBatchIdWithExecutor(executor, batchId);
    for (final snapshot in snapshots) {
      await _syncEnqueuer.enqueueUpdate(
        executor,
        record: snapshot,
        transactionGroupId: group?.id,
        localSequence: group?.nextSequence(),
        actor: actor,
      );
    }
  }

  @override
  Future<int> updateLocalFields({
    required String recordId,
    int? localUnitPriceFen,
    Object? linkedProjectId = _sentinel,
    ExternalWorkRecordStatus? status,
    Object? note = _sentinel,
    required String updatedAt,
  }) async {
    final normalized = recordId.trim();
    if (normalized.isEmpty) return 0;
    final db = await AppDatabase.database;
    final rows = await db.query(
      table,
      where: 'id = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    if (rows.isEmpty) return 0;

    final existing = ExternalWorkRecord.fromMap(rows.single);
    final values = <String, Object?>{'updated_at': updatedAt};
    if (localUnitPriceFen != null) {
      final amountFen = ExternalWorkRecord.calculateAmountFen(
        hoursMilli: existing.hoursMilli,
        unitPriceFen: localUnitPriceFen,
      );
      values['local_unit_price_fen'] = localUnitPriceFen;
      values['amount_fen'] = amountFen;
    }
    if (!identical(linkedProjectId, _sentinel)) {
      values['linked_project_id'] = linkedProjectId as String?;
    }
    if (status != null) {
      values['status'] = status.name;
    }
    if (!identical(note, _sentinel)) {
      values['note'] = note as String?;
    }

    return db.update(table, values, where: 'id = ?', whereArgs: [normalized]);
  }

  @override
  Future<int> setBatchCustomerUnitPriceFen({
    required String importBatchId,
    required int? customerUnitPriceFen,
    required String updatedAt,
  }) async {
    final normalizedBatchId = importBatchId.trim();
    if (normalizedBatchId.isEmpty) return 0;
    if (customerUnitPriceFen != null && customerUnitPriceFen < 0) {
      throw ArgumentError.value(
        customerUnitPriceFen,
        'customerUnitPriceFen',
        '客户应收单价不能为负',
      );
    }
    return AppDatabase.inTransaction<int>((txn) async {
      // 客户单价只对 hours 记录有意义（应收 = 单价 × 工时）；rent 记录不写。
      // 批内改动共享一个 sync group，逐条 update 入 outbox。
      final group = SyncTransactionGroup.create();
      final count = await txn.update(
        table,
        {
          'customer_unit_price_fen': customerUnitPriceFen,
          'updated_at': updatedAt,
        },
        where: 'import_batch_id = ? AND record_kind = ?',
        whereArgs: [normalizedBatchId, ExternalWorkRecordKind.hours.name],
      );
      if (count > 0) {
        await _enqueueBatchUpdates(
          txn,
          batchId: normalizedBatchId,
          group: group,
          actor: _actorProvider?.call(),
        );
      }
      return count;
    });
  }

  static Future<void> insertRecordWithExecutor(
    DatabaseExecutor executor,
    ExternalWorkRecord record,
  ) async {
    await executor.insert(table, record.toMap());
  }
}

const _sentinel = Object();
