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
  HttpCloudApiClient({
    required String baseUrl,
    required Future<String?> Function() accessTokenProvider,
    Duration timeout = const Duration(seconds: 30),
    HttpClient? httpClient,
  }) : _baseUrl = baseUrl.trim(),
       _accessTokenProvider = accessTokenProvider,
       _timeout = timeout,
       _httpClient = httpClient ?? HttpClient() {
    if (_baseUrl.isEmpty || !_baseUrl.startsWith('https://')) {
      throw ArgumentError.value(
        baseUrl,
        'baseUrl',
        'HttpCloudApiClient 需要显式的 https 后端地址;未配置后端时不要构造本类。',
      );
    }
  }

  final String _baseUrl;
  final Future<String?> Function() _accessTokenProvider;
  final Duration _timeout;
  final HttpClient _httpClient;

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    final uri = Uri.parse('$_baseUrl${request.path}');
    try {
      final httpRequest = await _httpClient
          .openUrl(request.method, uri)
          .timeout(_timeout);
      final token = await _accessTokenProvider();
      if (token != null && token.isNotEmpty) {
        httpRequest.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
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
