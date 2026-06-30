import '../../core/config/subscription_config.dart';
import '../../core/config/app_environment.dart';
import 'http_apple_subscription_verification_repository.dart';
import 'runtime_unlocked_subscription_verification_repository.dart';
import 'subscription_login_token_provider.dart';
import 'subscription_verification_repository.dart';

SubscriptionVerificationRepository
createDefaultSubscriptionVerificationRepository({SubscriptionConfig? config}) {
  if (RuntimeGate.shouldBypassIap) {
    return const RuntimeUnlockedSubscriptionVerificationRepository();
  }

  final resolvedConfig = config ?? SubscriptionConfig.fromEnvironment;
  if (!resolvedConfig.isConfigured) {
    return const PendingServerSubscriptionVerificationRepository();
  }

  return HttpAppleSubscriptionVerificationRepository(
    config: resolvedConfig,
    accessTokenProvider: () =>
        const SharedPreferencesSubscriptionLoginTokenProvider().call(),
  );
}
