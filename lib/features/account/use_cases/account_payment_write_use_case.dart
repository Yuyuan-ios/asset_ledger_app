import '../../../data/models/account_payment.dart';

/// 常规收款记录写路径契约（R5.3 / R5.6）。
///
/// 把单条收款 create / update / delete 与合并批次 create / replace / delete
/// 收口到一个事务化业务入口，使 account_payments 写入与 sync_outbox +
/// entity_sync_meta 入队处于同一个 SQLite transaction。实现位于
/// infrastructure 层（需要数据库事务），UI / store 仅依赖此抽象。
///
/// 单项目结清流程内创建的 payment 必须嵌入 settlement 既有 transaction，
/// 因此不通过本 use case 另开事务；该路径由
/// LocalProjectSettlementRepository.settle 在同一事务内直接调用
/// AccountPaymentSyncEnqueuer 覆盖。不要把 settlement payment 改成调用
/// AccountPaymentWriteUseCase，否则会引入嵌套 transaction 风险。
///
/// restore / migration / fallback 仍是明确 deferred / exemption；未来由
/// restore reconcile 和 fallback 收紧任务处理。
abstract class AccountPaymentWriteUseCase {
  /// 新建收款，返回落库后的 id；同事务入队 create / pendingUpload。
  Future<int> create(AccountPayment payment);

  /// 更新收款；同事务入队 update / pendingUpdate。
  Future<void> update(AccountPayment payment);

  /// 删除收款；命中时同事务入队 delete / pendingDelete，未命中为幂等空操作。
  Future<void> deleteById(int id);

  /// 合并批次新建：同事务插入 N 条 + 逐条入队 create / pendingUpload。
  /// 返回带最终 id 的已落库收款列表。
  Future<List<AccountPayment>> createBatch(List<AccountPayment> payments);

  /// 合并批次替换（delete old + insert new 语义）：同事务读旧快照 → 删旧 → 插新，
  /// 旧行逐条入队 delete / pendingDelete，新行逐条入队 create / pendingUpload。
  /// 返回带最终 id 的新收款列表。
  Future<List<AccountPayment>> replaceBatch({
    required String batchId,
    required List<AccountPayment> newRows,
  });

  /// 合并批次删除：同事务读旧快照 → 删除 → 逐条入队 delete / pendingDelete。
  /// 返回删除行数（批次为空为幂等 0，不入队）。
  Future<int> deleteBatch(String batchId);
}
