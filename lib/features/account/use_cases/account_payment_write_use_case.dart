import '../../../data/models/account_payment.dart';

/// 收款记录写路径契约（R5.3）。
///
/// 把单条收款的 create / update / delete 收口到一个事务化业务入口，使
/// account_payments 写入与 sync_outbox + entity_sync_meta 入队处于同一个
/// SQLite transaction。实现位于 infrastructure 层（需要数据库事务），
/// UI / store 仅依赖此抽象。
///
/// 仅覆盖**单条**收款；合并收款批次（insertAllInTransaction /
/// deleteByMergeBatchId / replaceMergeBatchInTransaction）与结清流程内创建的
/// 收款属于多行 / 跨流程写入，暂不接入（见 R5.3 deferred）。
abstract class AccountPaymentWriteUseCase {
  /// 新建收款，返回落库后的 id；同事务入队 create / pendingUpload。
  Future<int> create(AccountPayment payment);

  /// 更新收款；同事务入队 update / pendingUpdate。
  Future<void> update(AccountPayment payment);

  /// 删除收款；命中时同事务入队 delete / pendingDelete，未命中为幂等空操作。
  Future<void> deleteById(int id);
}
