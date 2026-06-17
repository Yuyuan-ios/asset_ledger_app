import 'dart:convert';
import 'dart:io';

import 'package:asset_ledger/app/sync_transport_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production defines intentionally omit sync transport endpoint', () {
    final file = File('dart_defines/production.json');
    final decoded = jsonDecode(file.readAsStringSync());

    expect(decoded, isA<Map<String, Object?>>());
    expect(
      (decoded as Map<String, Object?>).containsKey(
        'FLEET_LEDGER_SYNC_BASE_URL',
      ),
      isFalse,
      reason: 'B7 deployment fills the real sync URL and retires readiness.',
    );
  });

  group('SyncTransportConfig.resolve', () {
    test('unset sync endpoint is unavailable in development', () {
      final config = SyncTransportConfig.resolve(
        syncBaseUrl: '',
        isProduction: false,
      );

      expect(config.isAvailable, isFalse);
      expect(config.disabledMessage, '同步服务暂未配置');
      expect(config.baseUrl, isNull);
    });

    test('unset sync endpoint is unavailable in production', () {
      final config = SyncTransportConfig.resolve(
        syncBaseUrl: '',
        isProduction: true,
      );

      expect(config.isAvailable, isFalse);
      expect(config.disabledMessage, '同步服务暂未配置');
      expect(config.baseUrl, isNull);
    });

    test('uses explicit https endpoint when configured', () {
      final config = SyncTransportConfig.resolve(
        syncBaseUrl: 'https://sync.example.com/',
        isProduction: true,
      );

      expect(config.isAvailable, isTrue);
      expect(config.baseUrl, 'https://sync.example.com');
      expect(config.disabledMessage, isNull);
    });

    test('production rejects http endpoint', () {
      final config = SyncTransportConfig.resolve(
        syncBaseUrl: 'http://sync.example.com',
        isProduction: true,
      );

      expect(config.isAvailable, isFalse);
      expect(config.disabledMessage, contains('地址无效'));
    });

    test('development allows localhost http endpoint', () {
      final config = SyncTransportConfig.resolve(
        syncBaseUrl: 'http://127.0.0.1:8080/',
        isProduction: false,
      );

      expect(config.isAvailable, isTrue);
      expect(config.baseUrl, 'http://127.0.0.1:8080');
    });

    test('development rejects non-localhost http endpoint', () {
      final config = SyncTransportConfig.resolve(
        syncBaseUrl: 'http://sync.example.com',
        isProduction: false,
      );

      expect(config.isAvailable, isFalse);
      expect(config.disabledMessage, contains('地址无效'));
    });
  });
}
