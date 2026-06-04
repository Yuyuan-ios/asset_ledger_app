import 'package:sqflite/sqflite.dart';

import '../../core/errors/external_work_errors.dart';
import '../../infrastructure/local/timing/external_work_sync_enqueuer.dart';
import '../db/database.dart';
import '../models/external_work_record.dart';
import '../models/project.dart';
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
}

class SqfliteExternalWorkRecordRepository
    implements ExternalWorkRecordRepository {
  const SqfliteExternalWorkRecordRepository({
    ExternalWorkSyncEnqueuer syncEnqueuer = const ExternalWorkSyncEnqueuer(),
  }) : _syncEnqueuer = syncEnqueuer;

  static const String table = 'external_work_records';

  final ExternalWorkSyncEnqueuer _syncEnqueuer;

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
      await _syncEnqueuer.enqueueDelete(txn, record: snapshot);

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
      final snapshots = await listByBatchIdWithExecutor(txn, normalized);
      final deleted = await deleteByBatchIdWithExecutor(txn, normalized);
      if (deleted == 0) return 0;
      for (final snapshot in snapshots) {
        await _syncEnqueuer.enqueueDelete(txn, record: snapshot);
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
      final linked = await linkBatchToProjectWithExecutor(
        txn,
        importBatchId: normalizedBatchId,
        projectId: normalizedProjectId,
        updatedAt: updatedAt,
      );
      await _enqueueBatchUpdates(txn, batchId: normalizedBatchId);
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
      // 1) 先写关联：batch 已不存在（0 行）会抛异常，使整个事务回滚，
      //    确保不会出现"撤销结清成功但关联失败"的中间态。
      final linked = await linkBatchToProjectWithExecutor(
        txn,
        importBatchId: normalizedBatchId,
        projectId: normalizedProjectId,
        updatedAt: updatedAt,
      );

      // 2) 同事务内撤销结清：删除该项目核销记录 + 已结清恢复未结清。
      await txn.delete(
        SqfliteProjectWriteOffRepository.table,
        where: 'project_id = ?',
        whereArgs: [normalizedProjectId],
      );
      final projectRows = await txn.query(
        SqfliteProjectRepository.table,
        where: 'id = ?',
        whereArgs: [normalizedProjectId],
        limit: 1,
      );
      if (projectRows.isNotEmpty) {
        final project = Project.fromMap(projectRows.single);
        if (project.status == ProjectStatus.settled) {
          await SqfliteProjectRepository.upsertWithExecutor(
            txn,
            project.copyWith(
              status: ProjectStatus.active,
              settledAt: null,
              settledSnapshot: null,
              updatedAt: updatedAt,
            ),
          );
        }
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
      final unlinked = await unlinkBatchWithExecutor(
        txn,
        importBatchId: normalizedBatchId,
        updatedAt: updatedAt,
      );
      await _enqueueBatchUpdates(txn, batchId: normalizedBatchId);
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
  }) async {
    final snapshots = await listByBatchIdWithExecutor(executor, batchId);
    for (final snapshot in snapshots) {
      await _syncEnqueuer.enqueueUpdate(executor, record: snapshot);
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

  static Future<void> insertRecordWithExecutor(
    DatabaseExecutor executor,
    ExternalWorkRecord record,
  ) async {
    await executor.insert(table, record.toMap());
  }
}

const _sentinel = Object();
