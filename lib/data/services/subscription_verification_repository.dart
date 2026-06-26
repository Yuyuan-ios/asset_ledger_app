import 'package:in_app_purchase/in_app_purchase.dart';

enum SubscriptionVerificationOutcome {
  verifiedActivePro,
  verifiedActiveMax,
  verifiedGracePeriodPro,
  verifiedGracePeriodMax,
  billingRetry,
  expired,
  revoked,
  verificationFailed,
  verificationUnavailable,
  noActiveEntitlement,
}

enum SubscriptionEntitlementTier {
  none,
  pro,
  max;

  bool get includesPro => this == pro || this == max;
  bool get includesMax => this == max;
}

class VerifiedEntitlement {
  VerifiedEntitlement({
    required this.outcome,
    SubscriptionEntitlementTier? entitlementTier,
    this.productId,
    this.appAccountToken,
    this.expiryDate,
    DateTime? lastSyncedAt,
    this.reason,
  }) : entitlementTier = entitlementTier ?? _tierFromOutcome(outcome),
       lastSyncedAt = lastSyncedAt ?? DateTime.now();

  final SubscriptionVerificationOutcome outcome;
  final SubscriptionEntitlementTier entitlementTier;
  final String? productId;
  final String? appAccountToken;
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

  static SubscriptionEntitlementTier _tierFromOutcome(
    SubscriptionVerificationOutcome outcome,
  ) {
    return switch (outcome) {
      SubscriptionVerificationOutcome.verifiedActivePro ||
      SubscriptionVerificationOutcome.verifiedGracePeriodPro =>
        SubscriptionEntitlementTier.pro,
      SubscriptionVerificationOutcome.verifiedActiveMax ||
      SubscriptionVerificationOutcome.verifiedGracePeriodMax =>
        SubscriptionEntitlementTier.max,
      _ => SubscriptionEntitlementTier.none,
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
      reason: '订阅校验服务暂不可用',
    );
  }
}
