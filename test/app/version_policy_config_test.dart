import 'package:asset_ledger/app/version_policy_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VersionPolicyConfig.resolve', () {
    test('absent version policy URL is unavailable', () {
      final config = VersionPolicyConfig.resolve(
        versionPolicyUrl: '',
        isProduction: false,
      );

      expect(config.isAvailable, isFalse);
      expect(config.uri, isNull);
      expect(config.disabledMessage, '版本策略暂未配置');
    });

    test('uses explicit https version policy URL', () {
      final config = VersionPolicyConfig.resolve(
        versionPolicyUrl: 'https://example.com/app/version-policy.json',
        isProduction: true,
      );

      expect(config.isAvailable, isTrue);
      expect(
        config.uri,
        Uri.parse('https://example.com/app/version-policy.json'),
      );
      expect(config.disabledMessage, isNull);
    });

    test('invalid URL is unavailable', () {
      final config = VersionPolicyConfig.resolve(
        versionPolicyUrl: 'not a url',
        isProduction: false,
      );

      expect(config.isAvailable, isFalse);
      expect(config.uri, isNull);
      expect(config.disabledMessage, contains('地址无效'));
    });

    test('production rejects http URL', () {
      final config = VersionPolicyConfig.resolve(
        versionPolicyUrl: 'http://example.com/app/version-policy.json',
        isProduction: true,
      );

      expect(config.isAvailable, isFalse);
      expect(config.disabledMessage, contains('地址无效'));
    });

    test('development allows localhost http URL', () {
      final config = VersionPolicyConfig.resolve(
        versionPolicyUrl: 'http://127.0.0.1:8080/app/version-policy.json',
        isProduction: false,
      );

      expect(config.isAvailable, isTrue);
      expect(
        config.uri,
        Uri.parse('http://127.0.0.1:8080/app/version-policy.json'),
      );
    });
  });
}
