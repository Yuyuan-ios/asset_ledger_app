import 'package:flutter/foundation.dart';

import '../../../../core/config/subscription_config.dart';
import '../../../../data/services/subscription_service.dart';
import '../../../../data/services/subscription_verification_repository_factory.dart';

class SubscriptionController {
  const SubscriptionController();

  ValueListenable<SubscriptionSnapshot> get notifier =>
      SubscriptionService.notifier;

  SubscriptionSnapshot get snapshot => SubscriptionService.snapshot;

  bool get canUseCustomAvatar => SubscriptionService.canUseCustomAvatar;

  bool get canUsePurchaseFlow => isPurchaseFlowAvailable(
    config: SubscriptionConfig.fromEnvironment,
    useLocalIapVerification: kUseLocalIapVerification,
  );

  /// Returns whether the current build has a configured IAP verification path.
  @visibleForTesting
  static bool isPurchaseFlowAvailable({
    required SubscriptionConfig config,
    required bool useLocalIapVerification,
  }) {
    return config.isConfigured || useLocalIapVerification;
  }

  Future<void> init() => SubscriptionService.init();

  Future<void> buySelectedProduct(SubscriptionProductKind kind) {
    return SubscriptionService.buySelectedProduct(kind);
  }

  Future<void> restorePurchases() => SubscriptionService.restorePurchases();
}
