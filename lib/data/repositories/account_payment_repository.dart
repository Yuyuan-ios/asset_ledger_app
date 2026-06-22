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
    return AppDatabase.inTransaction((txn) => insertWithExecutor(txn, p));
  }

  /// 事务化单条新增：供同事务内接 sync_outbox 的协调器复用（R5.3）。
  /// 行为与 [insert] 一致（确保项目存在 + 插入），但使用调用方传入的 executor。
  Future<int> insertWithExecutor(
    DatabaseExecutor executor,
    AccountPayment p,
  ) async {
    await _ensureProjectWithExecutor(executor, p);
    return executor.insert(table, p.toMap());
  }

  @override
  Future<void> insertAllInTransaction(List<AccountPayment> payments) async {
    if (payments.isEmpty) return;
    await AppDatabase.inTransaction<void>((txn) async {
      await insertAllWithExecutor(txn, payments);
    });
  }

  /// 事务化批量新增：逐条 ensureProject + insert，返回各行落库 id（顺序与入参一致）。
  /// 供合并批次同事务接 sync_outbox 的协调器复用（R5.6）。
  Future<List<int>> insertAllWithExecutor(
    DatabaseExecutor executor,
    List<AccountPayment> payments,
  ) async {
    final ids = <int>[];
    for (final payment in payments) {
      await _ensureProjectWithExecutor(executor, payment);
      ids.add(await executor.insert(table, payment.toMap()));
    }
    return ids;
  }

  @override
  Future<List<AccountPayment>> listByMergeBatchId(String batchId) async {
    final db = await AppDatabase.database;
    return listByMergeBatchIdWithExecutor(db, batchId);
  }

  /// 事务内按批次重读合并收款（删除前取权威快照写 delete payload）。
  Future<List<AccountPayment>> listByMergeBatchIdWithExecutor(
    DatabaseExecutor executor,
    String batchId,
  ) async {
    final rows = await executor.query(
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
    return deleteByMergeBatchIdWithExecutor(db, batchId);
  }

  /// 事务化按批次删除合并收款。
  Future<int> deleteByMergeBatchIdWithExecutor(
    DatabaseExecutor executor,
    String batchId,
  ) async {
    return executor.delete(
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
    validateMergeBatchReplacement(batchId: batchId, newRows: newRows);
    await AppDatabase.inTransaction<void>((txn) async {
      await deleteByMergeBatchIdWithExecutor(txn, batchId);
      await insertAllWithExecutor(txn, newRows);
    });
  }

  /// 校验合并批次替换的入参合法性（全为分摊、同批次、同总额、金额 > 0 等）。
  /// 公开供 R5.6 同事务协调器在 executor 路径上复用同款校验。
  void validateMergeBatchReplacement({
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
    return AppDatabase.inTransaction((txn) => updateWithExecutor(txn, p));
  }

  /// 事务化单条更新：供同事务内接 sync_outbox 的协调器复用（R5.3）。
  Future<int> updateWithExecutor(
    DatabaseExecutor executor,
    AccountPayment p,
  ) async {
    await _ensureProjectWithExecutor(executor, p);
    return executor.update(
      table,
      p.toMap(),
      where: 'id = ?',
      whereArgs: [p.id],
    );
  }

  @override
  Future<int> deleteById(int id) async {
    final db = await AppDatabase.database;
    return deleteByIdWithExecutor(db, id);
  }

  /// 事务化单条删除：供同事务内接 sync_outbox 的协调器复用（R5.3）。
  Future<int> deleteByIdWithExecutor(DatabaseExecutor executor, int id) {
    return executor.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  /// 事务内按 id 重读单条收款，供删除前取权威快照写入 outbox payload。
  Future<AccountPayment?> findByIdWithExecutor(
    DatabaseExecutor executor,
    int id,
  ) async {
    final rows = await executor.query(
      table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AccountPayment.fromMap(rows.single);
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

  Future<int> sumFenByProjectId(String projectId) async {
    final normalized = projectId.trim();
    if (normalized.isEmpty) return 0;
    final db = await AppDatabase.database;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(amount_fen), 0) AS total FROM $table '
      'WHERE project_id = ?',
      [normalized],
    );
    return (rows.single['total'] as num?)?.toInt() ?? 0;
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
