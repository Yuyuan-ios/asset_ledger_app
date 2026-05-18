import '../../../core/utils/format_utils.dart';
import '../../../data/models/account_payment.dart';
import '../../../data/repositories/account_payment_repository.dart';
import '../model/account_view_model.dart';
import 'merged_payment_allocation_helpers.dart';

class CreateMergedPaymentUseCase {
  CreateMergedPaymentUseCase({
    required AccountPaymentRepository repository,
    DateTime Function()? now,
    String Function()? batchIdFactory,
  }) : _repository = repository,
       _now = now ?? DateTime.now,
       _batchIdFactory = batchIdFactory;

  final AccountPaymentRepository _repository;
  final DateTime Function() _now;
  final String Function()? _batchIdFactory;

  Future<List<AccountPayment>> execute({
    required AccountProjectVM mergedProject,
    required List<AccountProjectVM> memberProjects,
    required int ymd,
    required double amount,
    String? note,
  }) async {
    final groupId = mergedProject.mergeGroupId;
    if (mergedProject.kind != AccountProjectKind.merged || groupId == null) {
      throw StateError('合并组不存在');
    }
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', '金额必须是 > 0 的整数');
    }
    const eps = 0.000001;
    if (amount > mergedProject.remaining + eps) {
      throw StateError(
        '超出剩余应收（剩余约 ${FormatUtils.money(mergedProject.remaining)}）',
      );
    }

    final memberProjectIds = mergedProject.memberProjectIds.toSet();
    final memberKeys = mergedProject.memberProjectKeys.toSet();
    final createdAt = _now().toUtc().toIso8601String();
    final batchId = _batchIdFactory?.call() ?? _defaultBatchId(groupId);
    final allocations = buildMergedPaymentAllocationRows(
      candidates: [
        for (final project in memberProjects)
          if (memberProjectIds.isNotEmpty
              ? memberProjectIds.contains(project.effectiveProjectId)
              : memberKeys.contains(project.projectKey))
            MergedPaymentAllocationCandidate(
              projectId: project.effectiveProjectId,
              projectKey: project.projectKey,
              minYmd: project.minYmd,
              remaining: project.remaining,
            ),
      ],
      mergeGroupId: groupId,
      mergeBatchId: batchId,
      ymd: ymd,
      amount: amount,
      note: note,
      createdAt: createdAt,
    );

    await _repository.insertAllInTransaction(allocations);
    return allocations;
  }

  String _defaultBatchId(int groupId) {
    final micros = _now().toUtc().microsecondsSinceEpoch;
    return 'merge-$groupId-$micros';
  }
}
