import '../../../data/repositories/account_payment_repository.dart';

class DeleteMergedPaymentBatchUseCase {
  DeleteMergedPaymentBatchUseCase({
    required AccountPaymentRepository repository,
  }) : _repository = repository;

  final AccountPaymentRepository _repository;

  Future<int> execute({required String mergeBatchId}) async {
    final batchId = mergeBatchId.trim();
    if (batchId.isEmpty) {
      throw StateError('合并收款批次不存在');
    }

    final rows = await _repository.listByMergeBatchId(batchId);
    if (rows.isEmpty) {
      throw StateError('这笔合并收款不存在或已被删除，请刷新后重试。');
    }

    final deleted = await _repository.deleteByMergeBatchId(batchId);
    if (deleted == 0) {
      throw StateError('这笔合并收款不存在或已被删除，请刷新后重试。');
    }
    return deleted;
  }
}
