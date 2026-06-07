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

  static const String proMonthly = 'com.yuyuan.assetledger.pro.monthly';
  static const String proYearly = 'com.yuyuan.assetledger.pro.yearly';

  static const String monthly = proMonthly;
  static const String yearly = proYearly;

  static const Map<String, SubscriptionProductDefinition> currentProducts = {
    proMonthly: SubscriptionProductDefinition(
      productId: proMonthly,
      tier: SubscriptionTier.pro,
      duration: SubscriptionDuration.monthly,
    ),
    proYearly: SubscriptionProductDefinition(
      productId: proYearly,
      tier: SubscriptionTier.pro,
      duration: SubscriptionDuration.yearly,
    ),
  };

  static const Set<String> currentProductIds = {proMonthly, proYearly};

  static SubscriptionProductDefinition? definitionFor(String productId) {
    return currentProducts[productId];
  }
}
