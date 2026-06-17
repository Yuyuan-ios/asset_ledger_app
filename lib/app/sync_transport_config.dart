class SyncTransportConfig {
  SyncTransportConfig._();

  static const String _syncBaseUrl = String.fromEnvironment(
    'FLEET_LEDGER_SYNC_BASE_URL',
  );

  static const bool _isProduction = bool.fromEnvironment('dart.vm.product');

  static SyncTransportEndpointConfig get current {
    return resolve(syncBaseUrl: _syncBaseUrl, isProduction: _isProduction);
  }

  static SyncTransportEndpointConfig resolve({
    required String syncBaseUrl,
    required bool isProduction,
  }) {
    final explicitSyncUrl = _normalizeBaseUrl(syncBaseUrl);
    if (explicitSyncUrl == null) {
      return const SyncTransportEndpointConfig.unavailable('同步服务暂未配置');
    }

    if (!_isAllowedBaseUrl(explicitSyncUrl, isProduction: isProduction)) {
      return const SyncTransportEndpointConfig.unavailable(
        '同步服务地址无效，请检查 FLEET_LEDGER_SYNC_BASE_URL。',
      );
    }

    return SyncTransportEndpointConfig.available(baseUrl: explicitSyncUrl);
  }

  static String? _normalizeBaseUrl(String value) {
    var normalized = value.trim();
    if (normalized.isEmpty) return null;
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  static bool _isAllowedBaseUrl(String value, {required bool isProduction}) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;
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

class SyncTransportEndpointConfig {
  const SyncTransportEndpointConfig.available({required this.baseUrl})
    : disabledMessage = null;

  const SyncTransportEndpointConfig.unavailable(this.disabledMessage)
    : baseUrl = null;

  final String? baseUrl;
  final String? disabledMessage;

  bool get isAvailable => baseUrl != null && disabledMessage == null;
}
