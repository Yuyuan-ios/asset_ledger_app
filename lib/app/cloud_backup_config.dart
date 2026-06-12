import 'phone_verification_service.dart';

class CloudBackupConfig {
  CloudBackupConfig._();

  static const String _cloudBackupBaseUrl = String.fromEnvironment(
    'FLEET_LEDGER_CLOUD_BACKUP_BASE_URL',
  );

  static const String _apiBaseUrl = String.fromEnvironment(
    'FLEET_LEDGER_API_BASE_URL',
    defaultValue: HttpPhoneVerificationService.defaultBaseUrl,
  );

  static const bool _isProduction = bool.fromEnvironment('dart.vm.product');

  static CloudBackupEndpointConfig get current {
    return resolve(
      cloudBackupBaseUrl: _cloudBackupBaseUrl,
      apiBaseUrl: _apiBaseUrl,
      isProduction: _isProduction,
    );
  }

  static CloudBackupEndpointConfig resolve({
    required String cloudBackupBaseUrl,
    required String apiBaseUrl,
    required bool isProduction,
  }) {
    final explicitCloudUrl = _normalizeBaseUrl(cloudBackupBaseUrl);
    if (explicitCloudUrl != null) {
      if (!_isAllowedBaseUrl(explicitCloudUrl, isProduction: isProduction)) {
        return const CloudBackupEndpointConfig.unavailable(
          '云端备份服务地址无效，请检查 FLEET_LEDGER_CLOUD_BACKUP_BASE_URL。',
        );
      }
      return CloudBackupEndpointConfig.available(
        baseUrl: explicitCloudUrl,
        usesBusinessApiFallback: false,
      );
    }

    if (isProduction) {
      return const CloudBackupEndpointConfig.unavailable('云端备份服务暂未配置');
    }

    final fallbackUrl = _normalizeBaseUrl(apiBaseUrl);
    if (fallbackUrl == null ||
        !_isAllowedBaseUrl(fallbackUrl, isProduction: isProduction)) {
      return const CloudBackupEndpointConfig.unavailable(
        '云端备份服务地址无效，请检查开发环境 API 配置。',
      );
    }

    // Development/test fallback only. Release builds require the dedicated
    // FLEET_LEDGER_CLOUD_BACKUP_BASE_URL so cloud backup cannot look available
    // against an API host that may not implement /v1/backups.
    return CloudBackupEndpointConfig.available(
      baseUrl: fallbackUrl,
      usesBusinessApiFallback: true,
    );
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

class CloudBackupEndpointConfig {
  const CloudBackupEndpointConfig.available({
    required this.baseUrl,
    required this.usesBusinessApiFallback,
  }) : disabledMessage = null;

  const CloudBackupEndpointConfig.unavailable(this.disabledMessage)
    : baseUrl = null,
      usesBusinessApiFallback = false;

  final String? baseUrl;
  final String? disabledMessage;
  final bool usesBusinessApiFallback;

  bool get isAvailable => baseUrl != null && disabledMessage == null;
}
