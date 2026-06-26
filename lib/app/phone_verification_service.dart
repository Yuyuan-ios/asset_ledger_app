import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'app_review_demo_account.dart';

class PhoneVerificationSendResult {
  const PhoneVerificationSendResult({required this.message});

  final String message;
}

abstract class PhoneVerificationService {
  Future<PhoneVerificationSendResult> sendCode(String phoneNumber);

  Future<PhoneVerificationVerifyResult> verifyCode({
    required String phoneNumber,
    required String code,
  });
}

class PhoneVerificationVerifyResult {
  const PhoneVerificationVerifyResult({
    required this.success,
    this.token,
    this.expiresAt,
    this.message,
  });

  final bool success;
  final String? token;
  final int? expiresAt;
  final String? message;
}

class PhoneVerificationException implements Exception {
  const PhoneVerificationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AppReviewDemoPhoneVerificationService
    implements PhoneVerificationService {
  const AppReviewDemoPhoneVerificationService({required this.delegate});

  final PhoneVerificationService delegate;

  @override
  Future<PhoneVerificationSendResult> sendCode(String phoneNumber) {
    if (AppReviewDemoAccount.isDemoPhone(phoneNumber)) {
      return Future.value(const PhoneVerificationSendResult(message: '验证码已发送'));
    }
    return delegate.sendCode(phoneNumber);
  }

  @override
  Future<PhoneVerificationVerifyResult> verifyCode({
    required String phoneNumber,
    required String code,
  }) {
    final normalizedCode = code.trim();
    final isDemoPhone = AppReviewDemoAccount.isDemoPhone(phoneNumber);

    // App Review demo account only: 000000 is accepted for Apple's fixed
    // review phone number and must fail closed for every other phone number.
    if (isDemoPhone) {
      return Future.value(
        normalizedCode == AppReviewDemoAccount.verificationCode
            ? const PhoneVerificationVerifyResult(
                success: true,
                token: AppReviewDemoAccount.authToken,
                expiresAt: AppReviewDemoAccount.tokenExpiresAt,
              )
            : const PhoneVerificationVerifyResult(
                success: false,
                message: '验证码不正确或已过期',
              ),
      );
    }
    if (normalizedCode == AppReviewDemoAccount.verificationCode) {
      return Future.value(
        const PhoneVerificationVerifyResult(
          success: false,
          message: '验证码不正确或已过期',
        ),
      );
    }
    return delegate.verifyCode(phoneNumber: phoneNumber, code: code);
  }
}

class HttpPhoneVerificationService implements PhoneVerificationService {
  static const String defaultBaseUrl = 'https://api.yuyuan.net.cn/fleet-ledger';

  const HttpPhoneVerificationService({
    this.baseUrl = const String.fromEnvironment(
      'FLEET_LEDGER_API_BASE_URL',
      defaultValue: defaultBaseUrl,
    ),
    this.timeout = const Duration(seconds: 10),
  });

  final String baseUrl;
  final Duration timeout;

  @override
  Future<PhoneVerificationSendResult> sendCode(String phoneNumber) async {
    final body = await _postJson('/v1/auth/sms/request', <String, Object?>{
      'phone': phoneNumber,
    });
    final ok = body['ok'] == true;
    if (!ok) {
      throw PhoneVerificationException(
        _messageFromError(body['error']) ?? '验证码获取失败，请稍后重试',
      );
    }
    final seconds = body['expiresInSeconds'];
    final message = seconds is int && seconds > 0
        ? '验证码已发送，${(seconds / 60).round()} 分钟内有效。'
        : '验证码已发送';
    return PhoneVerificationSendResult(message: message);
  }

  @override
  Future<PhoneVerificationVerifyResult> verifyCode({
    required String phoneNumber,
    required String code,
  }) async {
    final body = await _postJson('/v1/auth/sms/verify', <String, Object?>{
      'phone': phoneNumber,
      'code': code,
    });
    final ok = body['ok'] == true;
    if (!ok) {
      return PhoneVerificationVerifyResult(
        success: false,
        message: _messageFromError(body['error']) ?? '验证码不正确或已过期',
      );
    }

    final token = body['token'];
    final expiresAt = body['expiresAt'];
    if (token is! String || token.isEmpty) {
      throw const PhoneVerificationException('登录响应无效，请稍后重试');
    }
    return PhoneVerificationVerifyResult(
      success: true,
      token: token,
      expiresAt: expiresAt is int ? expiresAt : null,
    );
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, Object?> payload,
  ) async {
    final uri = _resolve(path);
    final encoded = jsonEncode(payload);
    final client = HttpClient();
    client.connectionTimeout = timeout;
    try {
      final request = await client.postUrl(uri).timeout(timeout);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
      request.write(encoded);

      final response = await request.close().timeout(timeout);
      final responseBody = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);
      final decoded = responseBody.isEmpty ? null : jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw const PhoneVerificationException('服务响应格式无效，请稍后重试');
    } on PhoneVerificationException {
      rethrow;
    } on TimeoutException {
      throw const PhoneVerificationException('网络连接超时，请稍后重试');
    } on FormatException {
      throw const PhoneVerificationException('服务响应格式无效，请稍后重试');
    } on SocketException {
      throw const PhoneVerificationException('网络连接失败，请检查网络后重试');
    } finally {
      client.close(force: true);
    }
  }

  Uri _resolve(String path) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$normalizedBase$path');
  }

  String? _messageFromError(Object? error) {
    final code = error is String ? error.trim() : null;
    if (code == null || code.isEmpty) return null;
    return switch (code) {
      'invalid_phone' => '请输入有效的手机号',
      'too_many_requests' => '验证码发送过于频繁，请稍后再试',
      'sms_send_too_frequent' => '验证码发送过于频繁，请稍后再试',
      'dypns_access_key_not_configured' => '验证码服务暂未配置完成',
      'invalid_sms_code' => '验证码不正确或已过期',
      'sms_code_expired_or_missing' => '请先获取验证码',
      _ => _isUserFacingServerMessage(code) ? code : null,
    };
  }

  bool _isUserFacingServerMessage(String message) {
    return RegExp('[\u4e00-\u9fff]').hasMatch(message);
  }
}
