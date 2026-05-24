import 'package:sqflite/sqflite.dart';

import '../db/database.dart';
import '../models/external_work_record.dart';
import 'external_import_repository.dart';

abstract class ExternalWorkRecordRepository {
  Future<void> insertRecord(ExternalWorkRecord record);

  Future<void> insertRecords(List<ExternalWorkRecord> records);

  Future<List<ExternalWorkRecord>> listByBatchId(String batchId);

  Future<List<ExternalWorkRecord>> listByLinkedProjectId(String projectId);

  Future<int> deleteById(String recordId);

  Future<int> deleteByBatchId(String batchId);

  /// 把整个 importBatch 关联到一个本地项目：事务化地把该 batch 下所有记录的
  /// `linked_project_id` 统一写成 [projectId]，保证"一包一项目、同包一致"。
  /// 返回受影响的记录数（0 表示该 batch 没有记录）。
  Future<int> linkBatchToProject({
    required String importBatchId,
    required String projectId,
    required String updatedAt,
  });

  /// 解除整个 importBatch 的关联：事务化地把该 batch 下所有记录的
  /// `linked_project_id` 清空（不删除任何外协记录）。返回受影响的记录数。
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
  static const String table = 'external_work_records';

  @override
  Future<void> insertRecord(ExternalWorkRecord record) async {
    final db = await AppDatabase.database;
    await insertRecordWithExecutor(db, record);
  }

  @override
  Future<void> insertRecords(List<ExternalWorkRecord> records) async {
    if (records.isEmpty) return;
    await AppDatabase.inTransaction<void>((txn) async {
      for (final record in records) {
        await insertRecordWithExecutor(txn, record);
      }
    });
  }

  @override
  Future<List<ExternalWorkRecord>> listByBatchId(String batchId) async {
    final normalized = batchId.trim();
    if (normalized.isEmpty) return const [];
    final db = await AppDatabase.database;
    final rows = await db.query(
      table,
      where: 'import_batch_id = ?',
      whereArgs: [normalized],
      orderBy: 'work_date ASC, id ASC',
    );
    return rows.map(ExternalWorkRecord.fromMap).toList();
  }

  @override
  Future<List<ExternalWorkRecord>> listByLinkedProjectId(
    String projectId,
  ) async {
    final normalized = projectId.trim();
    if (normalized.isEmpty) return const [];
    final db = await AppDatabase.database;
    final rows = await db.query(
      table,
      where: 'linked_project_id = ?',
      whereArgs: [normalized],
      orderBy: 'work_date ASC, id ASC',
    );
    return rows.map(ExternalWorkRecord.fromMap).toList();
  }

  @override
  Future<int> deleteById(String recordId) async {
    final normalized = recordId.trim();
    if (normalized.isEmpty) return 0;
    return AppDatabase.inTransaction<int>((txn) async {
      final rows = await txn.query(
        table,
        columns: const ['import_batch_id'],
        where: 'id = ?',
        whereArgs: [normalized],
        limit: 1,
      );
      if (rows.isEmpty) return 0;

      final batchId = rows.single['import_batch_id'] as String;
      final deleted = await txn.delete(
        table,
        where: 'id = ?',
        whereArgs: [normalized],
      );
      if (deleted == 0) return 0;

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
      final deleted = await txn.delete(
        table,
        where: 'import_batch_id = ?',
        whereArgs: [normalized],
      );
      if (deleted == 0) return 0;

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
    final normalizedProjectId = projectId.trim();
    if (normalizedProjectId.isEmpty) {
      throw ArgumentError.value(projectId, 'projectId', '关联项目 id 不能为空');
    }
    if (normalizedBatchId.isEmpty) return 0;
    return AppDatabase.inTransaction<int>((txn) async {
      return txn.update(
        table,
        {'linked_project_id': normalizedProjectId, 'updated_at': updatedAt},
        where: 'import_batch_id = ?',
        whereArgs: [normalizedBatchId],
      );
    });
  }

  @override
  Future<int> unlinkBatch({
    required String importBatchId,
    required String updatedAt,
  }) async {
    final normalizedBatchId = importBatchId.trim();
    if (normalizedBatchId.isEmpty) return 0;
    return AppDatabase.inTransaction<int>((txn) async {
      return txn.update(
        table,
        {'linked_project_id': null, 'updated_at': updatedAt},
        where: 'import_batch_id = ?',
        whereArgs: [normalizedBatchId],
      );
    });
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
