import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/config/subscription_product_ids.dart';
import 'subscription_verification_repository.dart';

class RuntimeUnlockedSubscriptionVerificationRepository
    implements SubscriptionVerificationRepository {
  const RuntimeUnlockedSubscriptionVerificationRepository();

  @override
  Future<VerifiedEntitlement> verifyPurchase(PurchaseDetails purchase) async {
    final productId = purchase.productID;
    final definition = SubscriptionProductIds.definitionFor(productId);
    final tier = switch (definition?.tier) {
      SubscriptionTier.pro => SubscriptionEntitlementTier.pro,
      SubscriptionTier.max || null => SubscriptionEntitlementTier.max,
    };

    return VerifiedEntitlement(
      outcome: tier == SubscriptionEntitlementTier.max
          ? SubscriptionVerificationOutcome.verifiedActiveMax
          : SubscriptionVerificationOutcome.verifiedActivePro,
      entitlementTier: tier,
      productId: productId,
      expiryDate: DateTime.now().add(const Duration(days: 3650)),
    );
  }

  @override
  Future<VerifiedEntitlement> fetchCurrentEntitlement() async {
    return VerifiedEntitlement(
      outcome: SubscriptionVerificationOutcome.verifiedActiveMax,
      entitlementTier: SubscriptionEntitlementTier.max,
      productId: SubscriptionProductIds.maxYearly,
      expiryDate: DateTime.now().add(const Duration(days: 3650)),
    );
  }
}
