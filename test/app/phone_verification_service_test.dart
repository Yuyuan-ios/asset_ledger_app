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

  test(
    'review access service delegates review identifiers to real auth service',
    () async {
      final delegate = _RecordingPhoneVerificationService(
        verifyResult: const PhoneVerificationVerifyResult(
          success: true,
          token: 'delegate-auth-token',
        ),
      );
      final service = ReviewAccessPhoneVerificationService(delegate: delegate);

      final sendResult = await service.sendCode('review@example.com');
      final verifyResult = await service.verifyCode(
        phoneNumber: 'review@example.com',
        code: 'user-entered-value',
      );

      expect(sendResult.message, 'delegate sent');
      expect(verifyResult.success, isTrue);
      expect(verifyResult.token, 'delegate-auth-token');
      expect(delegate.sendCalls, 1);
      expect(delegate.sentIdentifier, 'review@example.com');
      expect(delegate.verifyCalls, 1);
      expect(delegate.verifiedIdentifier, 'review@example.com');
      expect(delegate.verifiedCode, 'user-entered-value');
    },
  );

  test(
    'review access service does not synthesize success when delegate fails',
    () async {
      final delegate = _RecordingPhoneVerificationService(
        verifyResult: const PhoneVerificationVerifyResult(success: false),
      );
      final service = ReviewAccessPhoneVerificationService(delegate: delegate);

      final result = await service.verifyCode(
        phoneNumber: 'review@example.com',
        code: 'user-entered-value',
      );

      expect(result.success, isFalse);
      expect(result.token, isNull);
      expect(delegate.verifyCalls, 1);
    },
  );
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

class _RecordingPhoneVerificationService implements PhoneVerificationService {
  _RecordingPhoneVerificationService({required this.verifyResult});

  final PhoneVerificationVerifyResult verifyResult;
  int sendCalls = 0;
  int verifyCalls = 0;
  String? sentIdentifier;
  String? verifiedIdentifier;
  String? verifiedCode;

  @override
  Future<PhoneVerificationSendResult> sendCode(String phoneNumber) async {
    sendCalls++;
    sentIdentifier = phoneNumber;
    return const PhoneVerificationSendResult(message: 'delegate sent');
  }

  @override
  Future<PhoneVerificationVerifyResult> verifyCode({
    required String phoneNumber,
    required String code,
  }) async {
    verifyCalls++;
    verifiedIdentifier = phoneNumber;
    verifiedCode = code;
    return verifyResult;
  }
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
