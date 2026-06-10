import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/config/subscription_product_ids.dart';
import 'subscription_verification_repository.dart';

class LocalTestSubscriptionVerificationRepository
    implements SubscriptionVerificationRepository {
  const LocalTestSubscriptionVerificationRepository();

  @override
  Future<VerifiedEntitlement> verifyPurchase(PurchaseDetails purchase) async {
    final now = DateTime.now();

    if (purchase.productID == SubscriptionProductIds.proYearly) {
      return VerifiedEntitlement(
        outcome: SubscriptionVerificationOutcome.verifiedActivePro,
        entitlementTier: SubscriptionEntitlementTier.pro,
        productId: purchase.productID,
        expiryDate: now.add(const Duration(days: 365)),
      );
    }

    if (purchase.productID == SubscriptionProductIds.maxYearly) {
      return VerifiedEntitlement(
        outcome: SubscriptionVerificationOutcome.verifiedActiveMax,
        entitlementTier: SubscriptionEntitlementTier.max,
        productId: purchase.productID,
        expiryDate: now.add(const Duration(days: 365)),
      );
    }

    return VerifiedEntitlement(
      outcome: SubscriptionVerificationOutcome.verificationFailed,
      productId: purchase.productID,
      reason: 'Unknown local test subscription product: ${purchase.productID}',
    );
  }

  @override
  Future<VerifiedEntitlement> fetchCurrentEntitlement() async {
    return VerifiedEntitlement(
      outcome: SubscriptionVerificationOutcome.noActiveEntitlement,
    );
  }
}
