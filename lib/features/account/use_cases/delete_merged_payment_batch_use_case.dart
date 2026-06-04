import '../../../data/repositories/account_payment_repository.dart';
import 'account_payment_write_use_case.dart';

class DeleteMergedPaymentBatchUseCase {
  DeleteMergedPaymentBatchUseCase({
    required AccountPaymentRepository repository,
    AccountPaymentWriteUseCase? writeUseCase,
  }) : _repository = repository,
       _writeUseCase = writeUseCase;

  final AccountPaymentRepository _repository;

  /// 注入时批次删除走 sync-aware 入口（同事务重读快照 + 入队 delete）；
  /// 未注入时回退 repository 直接删除。
  final AccountPaymentWriteUseCase? _writeUseCase;

  Future<int> execute({required String mergeBatchId}) async {
    final batchId = mergeBatchId.trim();
    if (batchId.isEmpty) {
      throw StateError('合并收款批次不存在');
    }

    final rows = await _repository.listByMergeBatchId(batchId);
    if (rows.isEmpty) {
      throw StateError('这笔合并收款不存在或已被删除，请刷新后重试。');
    }

    final writeUseCase = _writeUseCase;
    final deleted = writeUseCase != null
        ? await writeUseCase.deleteBatch(batchId)
        : await _repository.deleteByMergeBatchId(batchId);
    if (deleted == 0) {
      throw StateError('这笔合并收款不存在或已被删除，请刷新后重试。');
    }
    return deleted;
  }
}
