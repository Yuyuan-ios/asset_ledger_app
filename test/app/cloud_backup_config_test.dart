import 'package:asset_ledger/app/cloud_backup_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CloudBackupConfig.resolve', () {
    test('uses explicit cloud backup endpoint when configured', () {
      final config = CloudBackupConfig.resolve(
        cloudBackupBaseUrl: 'https://backup.example.com/',
        apiBaseUrl: 'https://api.example.com',
        isProduction: true,
      );

      expect(config.isAvailable, isTrue);
      expect(config.baseUrl, 'https://backup.example.com');
      expect(config.usesBusinessApiFallback, isFalse);
    });

    test('production without cloud backup endpoint fails closed', () {
      final config = CloudBackupConfig.resolve(
        cloudBackupBaseUrl: '',
        apiBaseUrl: 'https://api.example.com',
        isProduction: true,
      );

      expect(config.isAvailable, isFalse);
      expect(config.disabledMessage, '云端备份服务暂未配置');
    });

    test('development may fall back to business api endpoint', () {
      final config = CloudBackupConfig.resolve(
        cloudBackupBaseUrl: '',
        apiBaseUrl: 'https://api.example.com/fleet-ledger',
        isProduction: false,
      );

      expect(config.isAvailable, isTrue);
      expect(config.baseUrl, 'https://api.example.com/fleet-ledger');
      expect(config.usesBusinessApiFallback, isTrue);
    });

    test('production rejects http endpoint', () {
      final config = CloudBackupConfig.resolve(
        cloudBackupBaseUrl: 'http://backup.example.com',
        apiBaseUrl: 'https://api.example.com',
        isProduction: true,
      );

      expect(config.isAvailable, isFalse);
      expect(config.disabledMessage, contains('地址无效'));
    });

    test('development allows localhost http endpoint', () {
      final config = CloudBackupConfig.resolve(
        cloudBackupBaseUrl: 'http://127.0.0.1:8080',
        apiBaseUrl: 'https://api.example.com',
        isProduction: false,
      );

      expect(config.isAvailable, isTrue);
      expect(config.baseUrl, 'http://127.0.0.1:8080');
    });
  });
}
