import 'package:flutter/foundation.dart';

import '../../../../core/config/subscription_config.dart';
import '../../../../data/services/support_feedback_service.dart';
import '../../../../data/services/subscription_service.dart';
import '../../../../data/services/subscription_verification_repository_factory.dart';

class SubscriptionController {
  const SubscriptionController();

  ValueListenable<SubscriptionSnapshot> get notifier =>
      SubscriptionService.notifier;

  SubscriptionSnapshot get snapshot => SubscriptionService.snapshot;

  bool get canUseCustomAvatar => SubscriptionService.canUseCustomAvatar;

  bool get canUsePurchaseFlow =>
      SubscriptionConfig.fromEnvironment.isConfigured ||
      kUseLocalIapVerification;

  Future<void> init() => SubscriptionService.init();

  Future<void> buySelectedProduct(SubscriptionProductKind kind) {
    return SubscriptionService.buySelectedProduct(kind);
  }

  Future<void> restorePurchases() => SubscriptionService.restorePurchases();

  Future<bool> openPrivacyPolicy() =>
      SupportFeedbackService.openPrivacyPolicy();

  Future<bool> openTermsOfService() =>
      SupportFeedbackService.openTermsOfService();
}
