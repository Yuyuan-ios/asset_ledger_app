import '../../../data/models/account_payment.dart';
import '../../../data/models/project_key.dart';

enum AccountProjectPaymentDisplayType { normalMemberPayment, mergeBatchPayment }

class AccountProjectPaymentDisplayVM {
  final String id;
  final AccountProjectPaymentDisplayType type;
  final int ymd;
  final double amount;
  final String? note;
  final String sourceLabel;
  final String? relatedProjectId;
  final String? relatedProjectKey;
  final String? relatedSite;
  final String? mergeBatchId;
  final String? sortCreatedAt;
  final int? sortId;

  const AccountProjectPaymentDisplayVM({
    required this.id,
    required this.type,
    required this.ymd,
    required this.amount,
    this.note,
    required this.sourceLabel,
    this.relatedProjectId,
    this.relatedProjectKey,
    this.relatedSite,
    this.mergeBatchId,
    this.sortCreatedAt,
    this.sortId,
  });
}

List<AccountProjectPaymentDisplayVM> buildMergedPaymentDisplayItems({
  required List<AccountPayment> payments,
  required List<String> memberProjectKeys,
}) {
  final memberKeySet = memberProjectKeys.toSet();
  final normalItems = <AccountProjectPaymentDisplayVM>[];
  final mergeBatchPayments = <String, List<AccountPayment>>{};

  for (final payment in payments) {
    final batchId = payment.mergeBatchId?.trim();
    if (payment.sourceType == AccountPayment.sourceTypeMergeAllocation &&
        batchId != null &&
        batchId.isNotEmpty) {
      (mergeBatchPayments[batchId] ??= []).add(payment);
      continue;
    }

    if (memberKeySet.isNotEmpty && !memberKeySet.contains(payment.projectKey)) {
      continue;
    }
    normalItems.add(_normalMemberPaymentItem(payment));
  }

  final batchItems = mergeBatchPayments.entries.map((entry) {
    return _mergeBatchPaymentItem(entry.key, entry.value);
  });

  return [...normalItems, ...batchItems]..sort(_comparePaymentDisplayItems);
}

AccountProjectPaymentDisplayVM _normalMemberPaymentItem(
  AccountPayment payment,
) {
  final key = ProjectKey.fromKey(payment.projectKey);
  final site = key.site.trim();
  final sourceLabel = site.isNotEmpty ? site : payment.projectKey;
  return AccountProjectPaymentDisplayVM(
    id:
        payment.id?.toString() ??
        'payment:${payment.projectKey}:${payment.ymd}',
    type: AccountProjectPaymentDisplayType.normalMemberPayment,
    ymd: payment.ymd,
    amount: payment.amount,
    note: _cleanNote(payment.note),
    sourceLabel: sourceLabel,
    relatedProjectId: payment.effectiveProjectId,
    relatedProjectKey: payment.projectKey,
    relatedSite: site.isEmpty ? null : site,
    sortCreatedAt: payment.createdAt,
    sortId: payment.id,
  );
}

AccountProjectPaymentDisplayVM _mergeBatchPaymentItem(
  String batchId,
  List<AccountPayment> payments,
) {
  var ymd = 0;
  var amountSum = 0.0;
  double? totalAmount;
  String? note;
  String? sortCreatedAt;
  int? sortId;

  for (final payment in payments) {
    if (payment.ymd > ymd) ymd = payment.ymd;
    amountSum += payment.amount;
    totalAmount ??= payment.mergeBatchTotalAmount;
    note ??= _cleanNote(payment.mergeBatchNote);

    final createdAt = payment.createdAt;
    if (createdAt != null &&
        (sortCreatedAt == null || createdAt.compareTo(sortCreatedAt) > 0)) {
      sortCreatedAt = createdAt;
    }

    final id = payment.id;
    if (id != null && (sortId == null || id > sortId)) {
      sortId = id;
    }
  }

  return AccountProjectPaymentDisplayVM(
    id: batchId,
    type: AccountProjectPaymentDisplayType.mergeBatchPayment,
    ymd: ymd,
    amount: totalAmount ?? amountSum,
    note: note,
    sourceLabel: '合并分摊',
    mergeBatchId: batchId,
    sortCreatedAt: sortCreatedAt,
    sortId: sortId,
  );
}

int _comparePaymentDisplayItems(
  AccountProjectPaymentDisplayVM a,
  AccountProjectPaymentDisplayVM b,
) {
  final byDate = b.ymd.compareTo(a.ymd);
  if (byDate != 0) return byDate;
  final byCreatedAt = (b.sortCreatedAt ?? '').compareTo(a.sortCreatedAt ?? '');
  if (byCreatedAt != 0) return byCreatedAt;
  return (b.sortId ?? 0).compareTo(a.sortId ?? 0);
}

String? _cleanNote(String? raw) {
  final note = raw?.trim();
  if (note == null || note.isEmpty) return null;
  return note;
}
