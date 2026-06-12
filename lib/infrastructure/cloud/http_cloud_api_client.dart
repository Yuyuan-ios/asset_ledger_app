import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'api_client.dart';

/// 真实 HTTP 的 [CloudApiClient] 实现。
///
/// 与 NoOpCloudApiClient 的「禁止静默 no-op」纪律对应:本类要求显式注入
/// 非空 baseUrl 与 token 提供者,未配置后端时不允许被构造——composition
/// root 应在配置缺失时干脆不装配云功能,而不是装一个假的。
class HttpCloudApiClient implements CloudApiClient {
  static const bool _isProduction = bool.fromEnvironment('dart.vm.product');

  HttpCloudApiClient({
    required String baseUrl,
    required Future<String?> Function() accessTokenProvider,
    Duration timeout = const Duration(seconds: 30),
    HttpClient? httpClient,
  }) : _baseUrl = baseUrl.trim(),
       _accessTokenProvider = accessTokenProvider,
       _timeout = timeout,
       _httpClient = httpClient ?? HttpClient() {
    if (!_isAllowedBaseUrl(_baseUrl)) {
      throw ArgumentError.value(
        baseUrl,
        'baseUrl',
        'HttpCloudApiClient 需要显式的 HTTPS 后端地址;仅开发/测试 localhost 可使用 HTTP。',
      );
    }
  }

  final String _baseUrl;
  final Future<String?> Function() _accessTokenProvider;
  final Duration _timeout;
  final HttpClient _httpClient;

  static bool _isAllowedBaseUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;
    if (uri.scheme == 'https') return true;
    return !_isProduction && uri.scheme == 'http' && _isLocalHost(uri.host);
  }

  static bool _isLocalHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized == '::1';
  }

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    final uri = Uri.parse('$_baseUrl${request.path}');
    try {
      final httpRequest = await _httpClient
          .openUrl(request.method, uri)
          .timeout(_timeout);
      final token = await _accessTokenProvider();
      if (token != null && token.isNotEmpty) {
        httpRequest.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $token',
        );
      }
      request.headers.forEach(httpRequest.headers.set);
      final body = request.bodyJson;
      if (body != null) {
        httpRequest.headers.contentType = ContentType.json;
        httpRequest.add(utf8.encode(body));
      }
      final httpResponse = await httpRequest.close().timeout(_timeout);
      final responseBody = await httpResponse
          .transform(utf8.decoder)
          .join()
          .timeout(_timeout);
      return ApiResponse(
        statusCode: httpResponse.statusCode,
        bodyJson: responseBody.isEmpty ? null : responseBody,
        error: httpResponse.statusCode >= 400
            ? ApiError(
                code: 'http_${httpResponse.statusCode}',
                message: 'cloud request failed (${httpResponse.statusCode})',
                retryable: httpResponse.statusCode >= 500,
              )
            : null,
      );
    } on TimeoutException {
      return const ApiResponse(
        statusCode: 0,
        error: ApiError(
          code: 'timeout',
          message: 'cloud request timed out',
          retryable: true,
        ),
      );
    } on IOException catch (error) {
      return ApiResponse(
        statusCode: 0,
        error: ApiError(
          code: 'network_error',
          message: 'cloud request failed: $error',
          retryable: true,
        ),
      );
    }
  }
}
