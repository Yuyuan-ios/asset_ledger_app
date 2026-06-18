import 'package:asset_ledger/features/device/application/controllers/cloud_backup_controller.dart';
import 'package:asset_ledger/data/services/backup/cloud_backup_service.dart';
import 'package:asset_ledger/infrastructure/cloud/cloud_backup_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'unavailable controller fails closed without calling a gateway',
    () async {
      final controller = CloudBackupController.unavailable('云端备份服务暂未配置');

      final upload = await controller.uploadCurrent();
      final list = await controller.listRemote();
      final restore = await controller.restoreFromCloud('backup-1');

      expect(controller.isAvailable, isFalse);
      expect(upload.success, isFalse);
      expect(upload.errorCode, 'cloud_backup_not_configured');
      expect(list.success, isFalse);
      expect(list.errorCode, 'cloud_backup_not_configured');
      expect(restore.success, isFalse);
      expect(restore.errorCode, 'cloud_backup_not_configured');
    },
  );

  test('pro entitlement gate fails closed before calling a gateway', () async {
    final controller = CloudBackupController(
      service: CloudBackupService(gateway: _FailingGateway()),
      allowsCloudBackup: () => false,
      entitlementRequiredMessage: '需要 Pro',
    );

    final upload = await controller.uploadCurrent();
    final list = await controller.listRemote();
    final restore = await controller.restoreFromCloud('backup-1');

    expect(upload.success, isFalse);
    expect(upload.errorCode, 'cloud_backup_requires_pro');
    expect(upload.errorMessage, '需要 Pro');
    expect(list.success, isFalse);
    expect(list.errorCode, 'cloud_backup_requires_pro');
    expect(list.errorMessage, '需要 Pro');
    expect(restore.success, isFalse);
    expect(restore.errorCode, 'cloud_backup_requires_pro');
    expect(restore.message, '需要 Pro');
  });

  test('listRemote maps gateway failures to result objects', () async {
    final controller = CloudBackupController(
      service: CloudBackupService(gateway: _FailingGateway()),
    );

    final result = await controller.listRemote();

    expect(result.success, isFalse);
    expect(result.errorCode, 'http_503');
    expect(result.errorMessage, 'service unavailable');
  });

  test('formats remote metadata for account center display', () {
    final controller = CloudBackupController(
      service: CloudBackupService(gateway: _FailingGateway()),
    );

    expect(controller.formatPayloadSize(512), '512 B');
    expect(controller.formatPayloadSize(2048), '2.0 KB');
    expect(controller.formatRemoteTimeForDisplay('not-a-date'), 'not-a-date');
  });
}

class _FailingGateway implements CloudBackupGateway {
  @override
  Future<String> upload(CloudBackupEnvelope envelope) {
    throw const CloudBackupGatewayException(
      'http_503',
      'service unavailable',
      retryable: true,
    );
  }

  @override
  Future<List<CloudBackupMetadata>> list() {
    throw const CloudBackupGatewayException(
      'http_503',
      'service unavailable',
      retryable: true,
    );
  }

  @override
  Future<CloudBackupEnvelope> download(String backupId) {
    throw const CloudBackupGatewayException(
      'http_503',
      'service unavailable',
      retryable: true,
    );
  }
}
