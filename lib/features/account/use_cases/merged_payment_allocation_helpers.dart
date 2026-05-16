import '../../../core/utils/format_utils.dart';
import '../../../data/models/account_payment.dart';

const double mergedPaymentAllocationEpsilon = 0.000001;

class MergedPaymentAllocationCandidate {
  final String projectKey;
  final int minYmd;
  final double remaining;
  final String? site;

  const MergedPaymentAllocationCandidate({
    required this.projectKey,
    required this.minYmd,
    required this.remaining,
    this.site,
  });
}

String? cleanMergedPaymentNote(String? raw) {
  final note = raw?.trim();
  if (note == null || note.isEmpty) return null;
  return note;
}

String mergedPaymentAllocationNote({
  required int ymd,
  required double totalAmount,
  required String? batchNote,
}) {
  final suffix =
      '合并分摊(从${FormatUtils.date(ymd)}收款${FormatUtils.money(totalAmount)})';
  if (batchNote == null) return suffix;
  return '$batchNote / $suffix';
}

List<AccountPayment> buildMergedPaymentAllocationRows({
  required List<MergedPaymentAllocationCandidate> candidates,
  required int mergeGroupId,
  required String mergeBatchId,
  required int ymd,
  required double amount,
  required String? note,
  required String? createdAt,
}) {
  if (amount <= 0) {
    throw ArgumentError.value(amount, 'amount', '金额必须是 > 0 的整数');
  }

  final payableCandidates =
      candidates.where((candidate) {
        return candidate.remaining > mergedPaymentAllocationEpsilon;
      }).toList()..sort((a, b) {
        final byMinYmd = a.minYmd.compareTo(b.minYmd);
        if (byMinYmd != 0) return byMinYmd;
        return a.projectKey.compareTo(b.projectKey);
      });

  final sumRemaining = payableCandidates.fold<double>(
    0,
    (sum, candidate) => sum + candidate.remaining,
  );
  if (amount > sumRemaining + mergedPaymentAllocationEpsilon) {
    throw StateError('超出剩余应收（剩余约 ${FormatUtils.money(sumRemaining)}）');
  }

  final batchNote = cleanMergedPaymentNote(note);
  final rowNote = mergedPaymentAllocationNote(
    ymd: ymd,
    totalAmount: amount,
    batchNote: batchNote,
  );

  var left = amount;
  final allocations = <AccountPayment>[];
  for (final candidate in payableCandidates) {
    if (left <= mergedPaymentAllocationEpsilon) break;
    final take = left < candidate.remaining ? left : candidate.remaining;
    if (take <= mergedPaymentAllocationEpsilon) continue;
    allocations.add(
      AccountPayment(
        projectKey: candidate.projectKey,
        ymd: ymd,
        amount: take,
        note: rowNote,
        sourceType: AccountPayment.sourceTypeMergeAllocation,
        mergeGroupId: mergeGroupId,
        mergeBatchId: mergeBatchId,
        mergeBatchTotalAmount: amount,
        mergeBatchNote: batchNote,
        createdAt: createdAt,
      ),
    );
    left -= take;
  }

  if (left > mergedPaymentAllocationEpsilon) {
    throw StateError('合并收款分摊失败');
  }
  return allocations;
}
