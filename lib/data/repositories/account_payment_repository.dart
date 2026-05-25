import 'package:sqflite/sqflite.dart';

import '../db/database.dart';
import '../models/account_payment.dart';
import '../models/project.dart';
import '../models/project_key.dart';
import 'project_repository.dart';

abstract class AccountPaymentRepository {
  Future<List<AccountPayment>> listAll();

  Future<int> insert(AccountPayment payment);

  Future<void> insertAllInTransaction(List<AccountPayment> payments);

  Future<List<AccountPayment>> listByMergeBatchId(String batchId);

  Future<int> deleteByMergeBatchId(String batchId);

  Future<void> replaceMergeBatchInTransaction({
    required String batchId,
    required List<AccountPayment> newRows,
  });

  Future<int> update(AccountPayment payment);

  Future<int> deleteById(int id);
}

// =====================================================================
// ============================== AccountPaymentRepo ==============================
// =====================================================================
//
// 纯 CRUD：不写业务口径
// =====================================================================

class SqfliteAccountPaymentRepository implements AccountPaymentRepository {
  static const String table = 'account_payments';

  @override
  Future<List<AccountPayment>> listAll() async {
    final db = await AppDatabase.database;
    final rows = await db.query(
      table,
      orderBy: 'ymd DESC, created_at DESC, id DESC',
    );
    return rows.map((e) => AccountPayment.fromMap(e)).toList();
  }

  @override
  Future<int> insert(AccountPayment p) async {
    return AppDatabase.inTransaction((txn) async {
      await _ensureProjectWithExecutor(txn, p);
      return txn.insert(table, p.toMap());
    });
  }

  @override
  Future<void> insertAllInTransaction(List<AccountPayment> payments) async {
    if (payments.isEmpty) return;
    await AppDatabase.inTransaction<void>((txn) async {
      for (final payment in payments) {
        await _ensureProjectWithExecutor(txn, payment);
        await txn.insert(table, payment.toMap());
      }
    });
  }

  @override
  Future<List<AccountPayment>> listByMergeBatchId(String batchId) async {
    final db = await AppDatabase.database;
    final rows = await db.query(
      table,
      where: 'source_type = ? AND merge_batch_id = ?',
      whereArgs: [AccountPayment.sourceTypeMergeAllocation, batchId],
      orderBy: 'id ASC',
    );
    return rows.map((e) => AccountPayment.fromMap(e)).toList();
  }

  @override
  Future<int> deleteByMergeBatchId(String batchId) async {
    final db = await AppDatabase.database;
    return db.delete(
      table,
      where: 'source_type = ? AND merge_batch_id = ?',
      whereArgs: [AccountPayment.sourceTypeMergeAllocation, batchId],
    );
  }

  @override
  Future<void> replaceMergeBatchInTransaction({
    required String batchId,
    required List<AccountPayment> newRows,
  }) async {
    _validateMergeBatchReplacement(batchId: batchId, newRows: newRows);
    await AppDatabase.inTransaction<void>((txn) async {
      await txn.delete(
        table,
        where: 'source_type = ? AND merge_batch_id = ?',
        whereArgs: [AccountPayment.sourceTypeMergeAllocation, batchId],
      );
      for (final payment in newRows) {
        await _ensureProjectWithExecutor(txn, payment);
        await txn.insert(table, payment.toMap());
      }
    });
  }

  void _validateMergeBatchReplacement({
    required String batchId,
    required List<AccountPayment> newRows,
  }) {
    if (newRows.isEmpty) {
      throw StateError('合并收款批次不能为空');
    }

    double? totalAmount;
    int? mergeGroupId;
    String? batchNote;
    var hasBatchNote = false;
    int? ymd;
    String? createdAt;
    var hasCreatedAt = false;

    for (final row in newRows) {
      if (row.sourceType != AccountPayment.sourceTypeMergeAllocation) {
        throw StateError('合并收款批次包含非分摊收款');
      }
      if (row.mergeBatchId != batchId) {
        throw StateError('合并收款批次 ID 不一致');
      }
      if (row.mergeGroupId == null) {
        throw StateError('合并收款缺少合并组 ID');
      }
      mergeGroupId ??= row.mergeGroupId;
      if (row.mergeGroupId != mergeGroupId) {
        throw StateError('合并收款合并组 ID 不一致');
      }
      if (row.projectKey.startsWith('merge:') ||
          row.effectiveProjectId.startsWith('merge:')) {
        throw StateError('合并收款不能写入合并项目 key');
      }
      if (row.amount <= 0) {
        throw StateError('合并收款分摊金额必须大于 0');
      }

      totalAmount ??= row.mergeBatchTotalAmount;
      if (row.mergeBatchTotalAmount != totalAmount) {
        throw StateError('合并收款总金额不一致');
      }

      if (!hasBatchNote) {
        batchNote = row.mergeBatchNote;
        hasBatchNote = true;
      } else if (row.mergeBatchNote != batchNote) {
        throw StateError('合并收款备注不一致');
      }

      ymd ??= row.ymd;
      if (row.ymd != ymd) {
        throw StateError('合并收款日期不一致');
      }

      if (!hasCreatedAt) {
        createdAt = row.createdAt;
        hasCreatedAt = true;
      } else if (row.createdAt != createdAt) {
        throw StateError('合并收款创建时间不一致');
      }
    }

    if (totalAmount == null) {
      throw StateError('合并收款缺少总金额');
    }
  }

  @override
  Future<int> update(AccountPayment p) async {
    return AppDatabase.inTransaction((txn) async {
      await _ensureProjectWithExecutor(txn, p);
      return txn.update(table, p.toMap(), where: 'id = ?', whereArgs: [p.id]);
    });
  }

  @override
  Future<int> deleteById(int id) async {
    final db = await AppDatabase.database;
    return db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  // 删除影响协调器使用的具体读辅助（不纳入抽象接口）。
  Future<int> countByProjectId(String projectId) async {
    final db = await AppDatabase.database;
    return countByProjectIdWithExecutor(db, projectId);
  }

  Future<int> countByProjectIdWithExecutor(
    DatabaseExecutor executor,
    String projectId,
  ) async {
    final normalized = projectId.trim();
    if (normalized.isEmpty) return 0;
    final rows = await executor.rawQuery(
      'SELECT COUNT(*) AS count FROM $table WHERE project_id = ?',
      [normalized],
    );
    return (rows.single['count'] as num?)?.toInt() ?? 0;
  }

  static Future<void> _ensureProjectWithExecutor(
    DatabaseExecutor executor,
    AccountPayment payment,
  ) async {
    final projectId = payment.effectiveProjectId.trim();
    if (projectId.isEmpty) {
      throw StateError('收款缺少项目 ID');
    }

    final existing = await executor.query(
      SqfliteProjectRepository.table,
      columns: const ['id'],
      where: 'id = ?',
      whereArgs: [projectId],
      limit: 1,
    );
    if (existing.isNotEmpty) return;

    final parsed = ProjectKey.fromKey(payment.projectKey);
    final timestamp = DateTime.now().toUtc().toIso8601String();
    await SqfliteProjectRepository.upsertWithExecutor(
      executor,
      Project(
        id: projectId,
        contact: parsed.contact.trim(),
        site: parsed.site.trim(),
        createdAt: timestamp,
        updatedAt: timestamp,
        legacyProjectKey: payment.projectKey,
      ),
    );
  }
}
