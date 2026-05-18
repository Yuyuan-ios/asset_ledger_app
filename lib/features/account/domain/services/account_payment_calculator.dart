import '../entities/account_entities.dart';

class AccountPaymentCalculator {
  const AccountPaymentCalculator._();

  static double sumReceivedByProject({
    String? projectKey,
    String? projectId,
    required List<AccountPayment> payments,
    int? excludePaymentId,
  }) {
    double sum = 0.0;
    final targetProjectId = _resolveProjectId(
      projectId: projectId,
      projectKey: projectKey,
    );
    for (final payment in payments) {
      if (payment.effectiveProjectId != targetProjectId) continue;
      if (excludePaymentId != null && payment.id == excludePaymentId) continue;
      sum += payment.amount;
    }
    return sum;
  }

  static String _resolveProjectId({String? projectId, String? projectKey}) {
    final normalizedProjectId = projectId?.trim();
    if (normalizedProjectId != null && normalizedProjectId.isNotEmpty) {
      return normalizedProjectId;
    }
    return projectKey?.trim() ?? '';
  }
}
