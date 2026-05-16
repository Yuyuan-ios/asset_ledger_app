import '../../../core/utils/format_utils.dart';
import '../../../data/models/account_payment.dart';
import '../../../data/repositories/account_payment_repository.dart';
import '../model/account_view_model.dart';
import 'merged_payment_allocation_helpers.dart';

class UpdateMergedPaymentBatchUseCase {
  UpdateMergedPaymentBatchUseCase({
    required AccountPaymentRepository repository,
  }) : _repository = repository;

  final AccountPaymentRepository _repository;

  Future<List<AccountPayment>> execute({
    required AccountProjectVM mergedProject,
    required List<AccountProjectVM> memberProjects,
    required String mergeBatchId,
    required int ymd,
    required double amount,
    String? note,
  }) async {
    final groupId = mergedProject.mergeGroupId;
    if (mergedProject.kind != AccountProjectKind.merged || groupId == null) {
      throw StateError('合并组不存在');
    }

    final batchId = mergeBatchId.trim();
    if (batchId.isEmpty) {
      throw StateError('合并收款批次不存在');
    }

    final oldRows = await _repository.listByMergeBatchId(batchId);
    if (oldRows.isEmpty) {
      throw StateError('这笔合并收款不存在或已被删除，请刷新后重试。');
    }
    if (oldRows.any((row) {
      return row.sourceType != AccountPayment.sourceTypeMergeAllocation;
    })) {
      throw StateError('合并状态已变化，请重新打开项目详情后再操作。');
    }
    if (oldRows.any((row) => row.mergeGroupId != groupId)) {
      throw StateError('合并状态已变化，请重新打开项目详情后再操作。');
    }

    final oldAmountByProject = <String, double>{};
    var oldRowsTotal = 0.0;
    double? oldBatchTotalAmount;
    final oldCreatedAtValues = <String>[];
    for (final row in oldRows) {
      oldAmountByProject[row.projectKey] =
          (oldAmountByProject[row.projectKey] ?? 0.0) + row.amount;
      oldRowsTotal += row.amount;
      oldBatchTotalAmount ??= row.mergeBatchTotalAmount;
      final createdAt = row.createdAt?.trim();
      if (createdAt != null && createdAt.isNotEmpty) {
        oldCreatedAtValues.add(createdAt);
      }
    }
    final oldBatchAmount = oldBatchTotalAmount ?? oldRowsTotal;

    if (amount > mergedProject.remaining + oldBatchAmount + 0.000001) {
      final editableRemaining = mergedProject.remaining + oldBatchAmount;
      throw StateError('超出剩余应收（剩余约 ${FormatUtils.money(editableRemaining)}）');
    }

    final memberKeys = mergedProject.memberProjectKeys.toSet();
    final createdAt = _batchCreatedAt(oldCreatedAtValues);
    final allocations = buildMergedPaymentAllocationRows(
      candidates: [
        for (final project in memberProjects)
          if (memberKeys.contains(project.projectKey))
            MergedPaymentAllocationCandidate(
              projectKey: project.projectKey,
              minYmd: project.minYmd,
              remaining:
                  project.remaining +
                  (oldAmountByProject[project.projectKey] ?? 0.0),
            ),
      ],
      mergeGroupId: groupId,
      mergeBatchId: batchId,
      ymd: ymd,
      amount: amount,
      note: note,
      createdAt: createdAt,
    );
    if (allocations.any((row) {
      return row.mergeGroupId != groupId ||
          row.mergeBatchId != batchId ||
          row.sourceType != AccountPayment.sourceTypeMergeAllocation ||
          row.projectKey.startsWith('merge:');
    })) {
      throw StateError('合并收款分摊结果不合法');
    }

    await _repository.replaceMergeBatchInTransaction(
      batchId: batchId,
      newRows: allocations,
    );
    return allocations;
  }

  String? _batchCreatedAt(List<String> values) {
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
  }
}
