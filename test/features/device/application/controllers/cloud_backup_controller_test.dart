import 'package:asset_ledger/features/device/application/controllers/cloud_backup_controller.dart';
import 'package:asset_ledger/data/services/backup/cloud_backup_service.dart';
import 'package:asset_ledger/infrastructure/cloud/cloud_backup_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'unavailable controller fails closed without calling a gateway',
    () async {
      // server 下发文案透传(nullable)；errorCode 权威，文案由 view 层映射。
      final controller = CloudBackupController.unavailable('server is down');

      final upload = await controller.uploadCurrent();
      final list = await controller.listRemote();
      final restore = await controller.restoreFromCloud('backup-1');

      expect(controller.isAvailable, isFalse);
      expect(controller.serverUnavailableMessage, 'server is down');
      expect(upload.success, isFalse);
      expect(upload.errorCode, cloudBackupNotConfiguredCode);
      expect(upload.errorMessage, 'server is down');
      expect(list.success, isFalse);
      expect(list.errorCode, cloudBackupNotConfiguredCode);
      expect(list.errorMessage, 'server is down');
      expect(restore.success, isFalse);
      expect(restore.errorCode, cloudBackupNotConfiguredCode);
      expect(restore.message, 'server is down');
    },
  );

  test(
    'unavailable controller with no server message leaves text empty',
    () async {
      final controller = CloudBackupController.unavailable(null);

      final upload = await controller.uploadCurrent();
      final restore = await controller.restoreFromCloud('backup-1');

      expect(controller.serverUnavailableMessage, isNull);
      expect(upload.errorCode, cloudBackupNotConfiguredCode);
      expect(upload.errorMessage, isNull);
      expect(restore.errorCode, cloudBackupNotConfiguredCode);
      expect(restore.message, isEmpty);
    },
  );

  test('max entitlement gate fails closed before calling a gateway', () async {
    final controller = CloudBackupController(
      service: CloudBackupService(gateway: _FailingGateway()),
      canUseCloudBackup: () => false,
    );

    final upload = await controller.uploadCurrent();
    final list = await controller.listRemote();
    final restore = await controller.restoreFromCloud('backup-1');

    // requires-max 不带文案：errorCode 权威，文案由 view 层映射 l10n。
    expect(upload.success, isFalse);
    expect(upload.errorCode, cloudBackupRequiresMaxCode);
    expect(upload.errorMessage, isNull);
    expect(list.success, isFalse);
    expect(list.errorCode, cloudBackupRequiresMaxCode);
    expect(list.errorMessage, isNull);
    expect(restore.success, isFalse);
    expect(restore.errorCode, cloudBackupRequiresMaxCode);
    expect(restore.message, isEmpty);
  });

  test('listRemote maps gateway failures to result objects', () async {
    final controller = CloudBackupController(
      service: CloudBackupService(gateway: _FailingGateway()),
      canUseCloudBackup: () => true,
    );

    final result = await controller.listRemote();

    expect(result.success, isFalse);
    expect(result.errorCode, 'http_503');
    expect(result.errorMessage, 'service unavailable');
  });

  test('max entitlement allows restore to reach the gateway', () async {
    final controller = CloudBackupController(
      service: CloudBackupService(gateway: _FailingGateway()),
      canUseCloudBackup: () => true,
    );

    final result = await controller.restoreFromCloud('backup-1');

    expect(result.success, isFalse);
    expect(result.errorCode, 'http_503');
    expect(result.message, contains('service unavailable'));
  });

  test('formats remote metadata for account center display', () {
    final controller = CloudBackupController(
      service: CloudBackupService(gateway: _FailingGateway()),
      canUseCloudBackup: () => true,
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
