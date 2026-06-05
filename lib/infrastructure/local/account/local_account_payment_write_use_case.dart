import 'package:sqflite/sqflite.dart';

import '../../../data/db/database.dart';
import '../../../data/models/account_payment.dart';
import '../../../data/repositories/account_payment_repository.dart';
import '../../../features/account/use_cases/account_payment_write_use_case.dart';
import '../../sync/sync_repositories.dart';
import '../../sync/sync_status.dart';
import '../../sync/sync_transaction_group.dart';
import 'account_payment_sync_enqueuer.dart';

/// [AccountPaymentWriteUseCase] 的本地实现（R5.3）。
///
/// 严格照抄 timing_record 已冻结的 outbox 模式
/// （[local_save_timing_record_with_impact_use_case] /
/// [local_delete_timing_record_with_impact_use_case]），只替换 entity_type 与
/// record 快照：
/// - create → sync_outbox.operation=create + entity_sync_meta.pendingUpload
/// - update → sync_outbox.operation=update + entity_sync_meta.pendingUpdate
/// - delete → sync_outbox.operation=delete + entity_sync_meta.pendingDelete
///
/// 每个操作把"业务写 + 入队"包在同一个 [AppDatabase.inTransaction] 内：
/// 仅成功后入队；id 缺失抛错不写半条；outbox/meta 写失败整体回滚。
///
/// 保持 R5.2 deferred 纪律：entity_sync_meta 仍用当前 replace + version:0 语义，
/// 保留式 upsert 留到后续 repo 层统一切片。
class LocalAccountPaymentWriteUseCase implements AccountPaymentWriteUseCase {
  LocalAccountPaymentWriteUseCase({
    required SqfliteAccountPaymentRepository paymentRepository,
    SyncOutboxRepository? syncOutboxRepository,
    EntitySyncMetaRepository? entitySyncMetaRepository,
  }) : _paymentRepository = paymentRepository,
       _syncEnqueuer = AccountPaymentSyncEnqueuer(
         syncOutboxRepository: syncOutboxRepository,
         entitySyncMetaRepository: entitySyncMetaRepository,
       );

  final SqfliteAccountPaymentRepository _paymentRepository;
  final AccountPaymentSyncEnqueuer _syncEnqueuer;

  @override
  Future<int> create(AccountPayment payment) async {
    return AppDatabase.inTransaction((txn) async {
      final id = await _paymentRepository.insertWithExecutor(txn, payment);
      await _enqueueSync(
        txn,
        payment: payment.copyWith(id: id),
        operation: 'create',
        status: SyncStatus.pendingUpload,
      );
      return id;
    });
  }

  @override
  Future<void> update(AccountPayment payment) async {
    if (payment.id == null) {
      throw StateError('更新收款需要 id');
    }
    await AppDatabase.inTransaction((txn) async {
      final affected = await _paymentRepository.updateWithExecutor(
        txn,
        payment,
      );
      if (affected == 0) {
        throw StateError('收款记录不存在或已被并发修改，请刷新后再试');
      }
      if (affected > 1) {
        throw StateError(
          'updateWithExecutor 影响 $affected 行（期望 1）：account_payments 主键异常',
        );
      }
      await _enqueueSync(
        txn,
        payment: payment,
        operation: 'update',
        status: SyncStatus.pendingUpdate,
      );
    });
  }

  @override
  Future<void> deleteById(int id) async {
    await AppDatabase.inTransaction((txn) async {
      // 删除前事务内重读权威快照，作为 delete payload。
      final existing = await _paymentRepository.findByIdWithExecutor(txn, id);
      final affected = await _paymentRepository.deleteByIdWithExecutor(txn, id);
      // 幂等：记录已不存在 → 不入队（与旧 deleteById 的"删 0 行也算成功"一致）。
      if (affected == 0 || existing == null) return;
      await _enqueueSync(
        txn,
        payment: existing,
        operation: 'delete',
        status: SyncStatus.pendingDelete,
      );
    });
  }

  @override
  Future<List<AccountPayment>> createBatch(
    List<AccountPayment> payments,
  ) async {
    if (payments.isEmpty) return const [];
    return AppDatabase.inTransaction((txn) async {
      // R5.22-A：合并批次新建是一个同事务 cluster，N 条 create outbox 共享
      // 一个 transaction_group_id，并按插入顺序写 local_sequence 1..N。
      final group = SyncTransactionGroup.create();
      final ids = await _paymentRepository.insertAllWithExecutor(txn, payments);
      final saved = <AccountPayment>[];
      for (var i = 0; i < payments.length; i += 1) {
        final row = payments[i].copyWith(id: ids[i]);
        saved.add(row);
        await _enqueueSync(
          txn,
          payment: row,
          operation: 'create',
          status: SyncStatus.pendingUpload,
          group: group,
        );
      }
      return saved;
    });
  }

  @override
  Future<List<AccountPayment>> replaceBatch({
    required String batchId,
    required List<AccountPayment> newRows,
  }) async {
    // 与 repository.replaceMergeBatchInTransaction 同款入参校验。
    _paymentRepository.validateMergeBatchReplacement(
      batchId: batchId,
      newRows: newRows,
    );
    return AppDatabase.inTransaction((txn) async {
      // R5.22-A：替换批次（删旧 + 插新）是一个同事务 cluster。所有旧行 delete
      // 与新行 create 共享一个 transaction_group_id，local_sequence 先覆盖旧行
      // delete、再覆盖新行 create，反映业务因果顺序。
      final group = SyncTransactionGroup.create();
      // 1) 事务内重读旧批次权威快照（delete payload 源）。
      final oldRows = await _paymentRepository.listByMergeBatchIdWithExecutor(
        txn,
        batchId,
      );
      // 2) 删旧。
      await _paymentRepository.deleteByMergeBatchIdWithExecutor(txn, batchId);
      // 3) 插新并拿最终 id。
      final ids = await _paymentRepository.insertAllWithExecutor(txn, newRows);
      // 4) 旧行 delete/pendingDelete。
      for (final old in oldRows) {
        await _enqueueSync(
          txn,
          payment: old,
          operation: 'delete',
          status: SyncStatus.pendingDelete,
          group: group,
        );
      }
      // 5) 新行 create/pendingUpload。
      final saved = <AccountPayment>[];
      for (var i = 0; i < newRows.length; i += 1) {
        final row = newRows[i].copyWith(id: ids[i]);
        saved.add(row);
        await _enqueueSync(
          txn,
          payment: row,
          operation: 'create',
          status: SyncStatus.pendingUpload,
          group: group,
        );
      }
      return saved;
    });
  }

  @override
  Future<int> deleteBatch(String batchId) async {
    return AppDatabase.inTransaction((txn) async {
      // R5.22-A：删除批次的多条 delete outbox 共享一个 transaction_group_id。
      final group = SyncTransactionGroup.create();
      final oldRows = await _paymentRepository.listByMergeBatchIdWithExecutor(
        txn,
        batchId,
      );
      final deleted = await _paymentRepository.deleteByMergeBatchIdWithExecutor(
        txn,
        batchId,
      );
      // 批次为空 → 幂等 0，不入队。
      for (final old in oldRows) {
        await _enqueueSync(
          txn,
          payment: old,
          operation: 'delete',
          status: SyncStatus.pendingDelete,
          group: group,
        );
      }
      return deleted;
    });
  }

  /// 透传 sync 入队；[group] 非空时为同事务 cluster 写入同组 id + 递增 sequence。
  Future<void> _enqueueSync(
    DatabaseExecutor txn, {
    required AccountPayment payment,
    required String operation,
    required SyncStatus status,
    SyncTransactionGroup? group,
  }) async {
    await _syncEnqueuer.enqueue(
      txn,
      payment: payment,
      operation: operation,
      status: status,
      transactionGroupId: group?.id,
      localSequence: group?.nextSequence(),
    );
  }
}
