import 'dart:convert';
import 'dart:io';

import 'package:asset_ledger/app/phone_verification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sendCode surfaces user-facing backend messages', () async {
    final error = await _captureSendCodeError(<String, Object?>{
      'ok': false,
      'error': '请输入有效的中国大陆手机号',
    });

    expect(error, '请输入有效的中国大陆手机号');
  });

  test('sendCode maps backend throttle code', () async {
    final error = await _captureSendCodeError(<String, Object?>{
      'ok': false,
      'error': 'too_many_requests',
    });

    expect(error, '验证码发送过于频繁，请稍后再试');
  });

  test('verifyCode maps known backend codes', () async {
    final result = await _withJsonServer(
      <String, Object?>{'ok': false, 'error': 'sms_code_expired_or_missing'},
      (service) =>
          service.verifyCode(phoneNumber: '13800138000', code: '123456'),
    );

    expect(result.success, isFalse);
    expect(result.message, '请先获取验证码');
  });

  test('verifyCode keeps default message for unknown machine codes', () async {
    final result = await _withJsonServer(
      <String, Object?>{'ok': false, 'error': 'backend_internal_error'},
      (service) =>
          service.verifyCode(phoneNumber: '13800138000', code: '123456'),
    );

    expect(result.success, isFalse);
    expect(result.message, '验证码不正确或已过期');
  });
}

Future<String> _captureSendCodeError(Map<String, Object?> response) async {
  try {
    await _withJsonServer(
      response,
      (service) => service.sendCode('13800138000'),
    );
  } on PhoneVerificationException catch (error) {
    return error.message;
  }
  fail('Expected PhoneVerificationException');
}

Future<T> _withJsonServer<T>(
  Map<String, Object?> response,
  Future<T> Function(HttpPhoneVerificationService service) run,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(response));
    await request.response.close();
  });

  try {
    final service = HttpPhoneVerificationService(
      baseUrl: 'http://${server.address.host}:${server.port}',
      timeout: const Duration(seconds: 1),
    );
    return await run(service);
  } finally {
    await server.close(force: true);
  }
}
