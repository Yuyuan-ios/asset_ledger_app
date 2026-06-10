enum SubscriptionTier { pro, max }

enum SubscriptionDuration { monthly, yearly }

class SubscriptionProductDefinition {
  const SubscriptionProductDefinition({
    required this.productId,
    required this.tier,
    required this.duration,
  });

  final String productId;
  final SubscriptionTier tier;
  final SubscriptionDuration duration;
}

class SubscriptionProductIds {
  const SubscriptionProductIds._();

  static const String proYearly = 'com.yuyuan.assetledger.pro.yearly';
  static const String maxYearly = 'com.yuyuan.assetledger.max.yearly';

  static const Map<String, SubscriptionProductDefinition> currentProducts = {
    proYearly: SubscriptionProductDefinition(
      productId: proYearly,
      tier: SubscriptionTier.pro,
      duration: SubscriptionDuration.yearly,
    ),
    maxYearly: SubscriptionProductDefinition(
      productId: maxYearly,
      tier: SubscriptionTier.max,
      duration: SubscriptionDuration.yearly,
    ),
  };

  static const Set<String> currentProductIds = {proYearly, maxYearly};

  static SubscriptionProductDefinition? definitionFor(String productId) {
    return currentProducts[productId];
  }
}
