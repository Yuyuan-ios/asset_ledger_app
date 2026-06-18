class VersionPolicyConfig {
  VersionPolicyConfig._();

  static const String _versionPolicyUrl = String.fromEnvironment(
    'FLEET_LEDGER_VERSION_POLICY_URL',
  );

  static const bool _isProduction = bool.fromEnvironment('dart.vm.product');

  static VersionPolicyEndpointConfig get current {
    return resolve(
      versionPolicyUrl: _versionPolicyUrl,
      isProduction: _isProduction,
    );
  }

  static VersionPolicyEndpointConfig resolve({
    required String versionPolicyUrl,
    required bool isProduction,
  }) {
    final normalized = versionPolicyUrl.trim();
    if (normalized.isEmpty) {
      return const VersionPolicyEndpointConfig.unavailable('版本策略暂未配置');
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return const VersionPolicyEndpointConfig.unavailable(
        '版本策略地址无效，请检查 FLEET_LEDGER_VERSION_POLICY_URL。',
      );
    }

    if (!_isAllowedPolicyUri(uri, isProduction: isProduction)) {
      return const VersionPolicyEndpointConfig.unavailable(
        '版本策略地址无效，请检查 FLEET_LEDGER_VERSION_POLICY_URL。',
      );
    }

    return VersionPolicyEndpointConfig.available(uri: uri);
  }

  static bool _isAllowedPolicyUri(Uri uri, {required bool isProduction}) {
    if (uri.scheme == 'https') return true;
    if (!isProduction && uri.scheme == 'http' && _isLocalHost(uri.host)) {
      return true;
    }
    return false;
  }

  static bool _isLocalHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized == '::1';
  }
}

class VersionPolicyEndpointConfig {
  const VersionPolicyEndpointConfig.available({required this.uri})
    : disabledMessage = null;

  const VersionPolicyEndpointConfig.unavailable(this.disabledMessage)
    : uri = null;

  final Uri? uri;
  final String? disabledMessage;

  bool get isAvailable => uri != null && disabledMessage == null;
}
