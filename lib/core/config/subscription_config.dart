import 'app_environment.dart';

class SubscriptionConfig {
  const SubscriptionConfig({
    required this.appleVerificationBaseUrl,
    this.verifyPurchasePath = '/iap/apple/verify-purchase',
    this.currentEntitlementPath = '/iap/apple/current-entitlement',
    this.requestTimeout = const Duration(seconds: 10),
  });

  /// Production IAP verification backend.
  ///
  /// Keep this default in sync with `dart_defines/production.json` so a manual
  /// Xcode Archive or local release build cannot silently fall back to the
  /// pending server-verification repository and disable purchases. Debug/test
  /// builds keep the old fail-closed default to avoid accidental network calls.
  static const String defaultAppleVerificationBaseUrl =
      'https://api.yuyuan.net.cn/fleet-ledger';

  static const String _configuredAppleVerificationBaseUrl =
      String.fromEnvironment('APPLE_IAP_VERIFICATION_BASE_URL');

  static const String _verifyPurchasePath = String.fromEnvironment(
    'APPLE_IAP_VERIFY_PURCHASE_PATH',
    defaultValue: '/iap/apple/verify-purchase',
  );

  static const String _currentEntitlementPath = String.fromEnvironment(
    'APPLE_IAP_CURRENT_ENTITLEMENT_PATH',
    defaultValue: '/iap/apple/current-entitlement',
  );

  static const int _requestTimeoutSeconds = int.fromEnvironment(
    'APPLE_IAP_REQUEST_TIMEOUT_SECONDS',
    defaultValue: 10,
  );

  static SubscriptionConfig get fromEnvironment {
    final configured = _configuredAppleVerificationBaseUrl.trim();
    return SubscriptionConfig(
      appleVerificationBaseUrl: configured.isNotEmpty
          ? configured
          : RuntimeGate.isProductionBuild
          ? defaultAppleVerificationBaseUrl
          : '',
      verifyPurchasePath: _verifyPurchasePath,
      currentEntitlementPath: _currentEntitlementPath,
      requestTimeout: const Duration(seconds: _requestTimeoutSeconds),
    );
  }

  final String appleVerificationBaseUrl;
  final String verifyPurchasePath;
  final String currentEntitlementPath;
  final Duration requestTimeout;

  bool get isConfigured => appleVerificationBaseUrl.trim().isNotEmpty;

  Uri? uriFor(String path) {
    final baseUrl = appleVerificationBaseUrl.trim();
    if (baseUrl.isEmpty) return null;

    final base = Uri.tryParse(baseUrl);
    if (base == null || !base.hasScheme || base.host.isEmpty) return null;

    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    final basePath = base.path.endsWith('/')
        ? base.path
        : base.path.isEmpty
        ? '/'
        : '${base.path}/';

    return base.replace(path: '$basePath$normalizedPath');
  }
}
