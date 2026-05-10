class SubscriptionConfig {
  const SubscriptionConfig({
    required this.appleVerificationBaseUrl,
    this.verifyPurchasePath = '/iap/apple/verify-purchase',
    this.currentEntitlementPath = '/iap/apple/current-entitlement',
    this.requestTimeout = const Duration(seconds: 10),
  });

  static const SubscriptionConfig fromEnvironment = SubscriptionConfig(
    appleVerificationBaseUrl: String.fromEnvironment(
      'APPLE_IAP_VERIFICATION_BASE_URL',
    ),
    verifyPurchasePath: String.fromEnvironment(
      'APPLE_IAP_VERIFY_PURCHASE_PATH',
      defaultValue: '/iap/apple/verify-purchase',
    ),
    currentEntitlementPath: String.fromEnvironment(
      'APPLE_IAP_CURRENT_ENTITLEMENT_PATH',
      defaultValue: '/iap/apple/current-entitlement',
    ),
    requestTimeout: Duration(
      seconds: int.fromEnvironment(
        'APPLE_IAP_REQUEST_TIMEOUT_SECONDS',
        defaultValue: 10,
      ),
    ),
  );

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
