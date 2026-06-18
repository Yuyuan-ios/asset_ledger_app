import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/version_policy_source.dart';

class HttpVersionPolicySource implements VersionPolicySource {
  static const bool _isProduction = bool.fromEnvironment('dart.vm.product');

  HttpVersionPolicySource({
    required Uri uri,
    Duration timeout = const Duration(seconds: 10),
    HttpClient? httpClient,
  }) : _uri = uri,
       _timeout = timeout,
       _httpClient = httpClient ?? HttpClient() {
    if (!_isAllowedUri(uri)) {
      throw ArgumentError.value(
        uri,
        'uri',
        'Version policy source requires an explicit HTTPS URL; '
            'only localhost may use HTTP outside production.',
      );
    }
    if (!timeout.isPositive) {
      throw ArgumentError.value(
        timeout,
        'timeout',
        'Version policy HTTP timeout must be positive.',
      );
    }
  }

  final Uri _uri;
  final Duration _timeout;
  final HttpClient _httpClient;

  @override
  Future<String> fetchPolicyJson() async {
    final request = await _httpClient.openUrl('GET', _uri).timeout(_timeout);
    request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);

    final response = await request.close().timeout(_timeout);
    final body = await response
        .transform(utf8.decoder)
        .join()
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'version policy request failed (${response.statusCode})',
        uri: _uri,
      );
    }

    return body;
  }

  static bool _isAllowedUri(Uri uri) {
    if (!uri.hasScheme || uri.host.isEmpty) return false;
    if (uri.scheme == 'https') return true;
    return !_isProduction && uri.scheme == 'http' && _isLocalHost(uri.host);
  }

  static bool _isLocalHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized == '::1';
  }
}

extension on Duration {
  bool get isPositive => this > Duration.zero;
}
