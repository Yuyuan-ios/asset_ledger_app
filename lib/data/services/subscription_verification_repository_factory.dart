import '../../core/config/subscription_config.dart';
import 'http_apple_subscription_verification_repository.dart';
import 'local_test_subscription_verification_repository.dart';
import 'subscription_verification_repository.dart';

/// Enables local entitlement verification for TestFlight / sandbox IAP smoke tests.
/// Do not enable this flag for production builds.
/// Production builds must use server-side App Store receipt / transaction verification.
const bool kUseLocalIapVerification = bool.fromEnvironment(
  'USE_LOCAL_IAP_VERIFICATION',
  defaultValue: false,
);

SubscriptionVerificationRepository
createDefaultSubscriptionVerificationRepository({
  SubscriptionConfig config = SubscriptionConfig.fromEnvironment,
}) {
  if (kUseLocalIapVerification) {
    return const LocalTestSubscriptionVerificationRepository();
  }

  if (!config.isConfigured) {
    return const PendingServerSubscriptionVerificationRepository();
  }

  return HttpAppleSubscriptionVerificationRepository(config: config);
}
