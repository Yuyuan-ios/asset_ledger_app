import '../../core/config/subscription_config.dart';
import 'http_apple_subscription_verification_repository.dart';
import 'subscription_verification_repository.dart';

SubscriptionVerificationRepository
createDefaultSubscriptionVerificationRepository({
  SubscriptionConfig config = SubscriptionConfig.fromEnvironment,
}) {
  if (!config.isConfigured) {
    return const PendingServerSubscriptionVerificationRepository();
  }

  return HttpAppleSubscriptionVerificationRepository(config: config);
}
