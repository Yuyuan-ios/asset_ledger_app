import 'package:sqflite/sqflite.dart';

import '../../../data/db/database.dart';
import '../../../data/models/account_payment.dart';
import '../../../data/repositories/account_payment_repository.dart';
import '../../../features/account/use_cases/account_payment_write_use_case.dart';
import '../../sync/entity_sync_meta.dart';
import '../../sync/sync_repositories.dart';
import '../../sync/sync_status.dart';

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
       _syncOutboxRepository =
           syncOutboxRepository ?? const LocalSyncOutboxRepository(),
       _entitySyncMetaRepository =
           entitySyncMetaRepository ?? const LocalEntitySyncMetaRepository();

  final SqfliteAccountPaymentRepository _paymentRepository;
  final SyncOutboxRepository _syncOutboxRepository;
  final EntitySyncMetaRepository _entitySyncMetaRepository;

  static const String _entityType = 'account_payment';
  static const String _ownerAppSource = 'owner_app';

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
      final affected = await _paymentRepository.updateWithExecutor(txn, payment);
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

  Future<void> _enqueueSync(
    DatabaseExecutor txn, {
    required AccountPayment payment,
    required String operation,
    required SyncStatus status,
  }) async {
    final id = payment.id;
    if (id == null) {
      throw StateError('sync_outbox 入队需要最终落库后的 account_payment id');
    }
    final entityId = id.toString();
    final entry = await _syncOutboxRepository.enqueueWithExecutor(
      txn,
      entityType: _entityType,
      entityId: entityId,
      operation: operation,
      payload: {
        'entity_type': _entityType,
        'entity_id': entityId,
        'operation': operation,
        'record': payment.toMap(),
      },
    );
    await _entitySyncMetaRepository.upsertWithExecutor(
      txn,
      EntitySyncMeta(
        entityType: _entityType,
        localId: entityId,
        syncStatus: status,
        version: 0,
        source: _ownerAppSource,
        payloadHash: entry.payloadHash,
      ),
    );
  }
}
