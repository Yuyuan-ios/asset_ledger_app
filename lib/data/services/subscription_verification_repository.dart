import 'package:in_app_purchase/in_app_purchase.dart';

enum SubscriptionVerificationOutcome {
  verifiedActiveMonthly,
  verifiedActiveYearly,
  verifiedGracePeriod,
  verifiedBillingRetry,
  verifiedInactive,
  verifiedExpired,
  verifiedRevoked,
  verificationFailed,
  verificationUnavailable,
}

class VerifiedEntitlement {
  VerifiedEntitlement({
    required this.outcome,
    this.productId,
    this.expiryDate,
    DateTime? lastSyncedAt,
    this.reason,
  }) : lastSyncedAt = lastSyncedAt ?? DateTime.now();

  final SubscriptionVerificationOutcome outcome;
  final String? productId;
  final DateTime? expiryDate;
  final DateTime lastSyncedAt;
  final String? reason;

  bool get isVerified {
    return switch (outcome) {
      SubscriptionVerificationOutcome.verificationFailed => false,
      SubscriptionVerificationOutcome.verificationUnavailable => false,
      _ => true,
    };
  }
}

abstract class SubscriptionVerificationRepository {
  Future<VerifiedEntitlement> verifyPurchase(PurchaseDetails purchase);

  Future<VerifiedEntitlement> fetchCurrentEntitlement();
}

class PendingServerSubscriptionVerificationRepository
    implements SubscriptionVerificationRepository {
  const PendingServerSubscriptionVerificationRepository();

  @override
  Future<VerifiedEntitlement> verifyPurchase(PurchaseDetails purchase) async {
    // TODO(iap): Send purchase.verificationData.serverVerificationData,
    // productID, transactionDate and purchaseID to your backend. The backend
    // should verify against App Store Server API, then return entitlement state.
    return VerifiedEntitlement(
      outcome: SubscriptionVerificationOutcome.verificationUnavailable,
      productId: purchase.productID,
      reason: '订阅交易已收到，但服务端校验尚未接入',
    );
  }

  @override
  Future<VerifiedEntitlement> fetchCurrentEntitlement() async {
    // TODO(iap): Fetch latest entitlement from backend / App Store Server API.
    return VerifiedEntitlement(
      outcome: SubscriptionVerificationOutcome.verificationUnavailable,
      reason: '订阅状态同步服务尚未接入',
    );
  }
}
