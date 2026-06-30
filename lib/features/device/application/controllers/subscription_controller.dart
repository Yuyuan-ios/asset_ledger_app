import 'package:flutter/foundation.dart';

import '../../../../core/config/app_environment.dart';
import '../../../../core/config/subscription_config.dart';
import '../../../../data/services/support_feedback_service.dart';
import '../../../../data/services/subscription_service.dart';

class SubscriptionController {
  const SubscriptionController();

  ValueListenable<SubscriptionSnapshot> get notifier =>
      SubscriptionService.notifier;

  SubscriptionSnapshot get snapshot => SubscriptionService.snapshot;

  bool get canUseCustomAvatar => SubscriptionService.canUseCustomAvatar;

  bool canCreateMoreTimingRecords(int currentCount) {
    return SubscriptionService.canCreateMoreTimingRecords(currentCount);
  }

  bool get canUsePurchaseFlow => isPurchaseFlowAvailable(
    config: SubscriptionConfig.fromEnvironment,
    buildEnvironment: BuildEnvironment.current,
    accessMode: RuntimeGate.accessMode,
  );

  /// Returns whether the current build has a configured IAP verification path.
  @visibleForTesting
  static bool isPurchaseFlowAvailable({
    required SubscriptionConfig config,
    required BuildEnvironment buildEnvironment,
    required RuntimeAccessMode accessMode,
  }) {
    return buildEnvironment == BuildEnvironment.production &&
        accessMode == RuntimeAccessMode.normal &&
        config.isConfigured;
  }

  Future<void> init() => SubscriptionService.init();

  Future<void> buySelectedProduct(SubscriptionProductKind kind) {
    return SubscriptionService.buySelectedProduct(kind);
  }

  Future<SubscriptionRestoreOutcome> restorePurchases() =>
      SubscriptionService.restorePurchases();

  Future<bool> openPrivacyPolicy() =>
      SupportFeedbackService.openPrivacyPolicy();

  Future<bool> openTermsOfService() =>
      SupportFeedbackService.openTermsOfService();
}
