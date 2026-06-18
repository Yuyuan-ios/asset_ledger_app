import '../../../../data/models/backup_restore_result.dart';
import '../../../../data/services/backup/cloud_backup_service.dart';
import '../../../../infrastructure/cloud/cloud_backup_gateway.dart';

const _cloudBackupRequiresProCode = 'cloud_backup_requires_pro';
const _defaultEntitlementRequiredMessage = '云端备份是 Pro 功能，请升级后再使用。';

bool _allowCloudBackupByDefault() => true;

class CloudBackupListResult {
  const CloudBackupListResult({
    required this.success,
    this.backups = const <CloudBackupMetadata>[],
    this.errorCode,
    this.errorMessage,
  });

  final bool success;
  final List<CloudBackupMetadata> backups;
  final String? errorCode;
  final String? errorMessage;
}

class CloudBackupAvailability {
  const CloudBackupAvailability.available({
    this.usesBusinessApiFallback = false,
  }) : isAvailable = true,
       message = null;

  const CloudBackupAvailability.unavailable(this.message)
    : isAvailable = false,
      usesBusinessApiFallback = false;

  final bool isAvailable;
  final String? message;
  final bool usesBusinessApiFallback;
}

class CloudBackupController {
  const CloudBackupController({
    required CloudBackupService service,
    this.availability = const CloudBackupAvailability.available(),
    bool Function() allowsCloudBackup = _allowCloudBackupByDefault,
    String entitlementRequiredMessage = _defaultEntitlementRequiredMessage,
  }) : _service = service,
       _allowsCloudBackup = allowsCloudBackup,
       _entitlementRequiredMessage = entitlementRequiredMessage;

  CloudBackupController.unavailable(String message)
    : _service = null,
      availability = CloudBackupAvailability.unavailable(message),
      _allowsCloudBackup = _allowCloudBackupByDefault,
      _entitlementRequiredMessage = _defaultEntitlementRequiredMessage;

  final CloudBackupService? _service;
  final bool Function() _allowsCloudBackup;
  final String _entitlementRequiredMessage;
  final CloudBackupAvailability availability;

  bool get isAvailable => availability.isAvailable;

  String get unavailableMessage => availability.message ?? '云端备份服务暂未配置';

  Future<CloudBackupUploadResult> uploadCurrent() {
    final service = _service;
    if (service == null || !availability.isAvailable) {
      return Future.value(
        CloudBackupUploadResult(
          success: false,
          errorCode: 'cloud_backup_not_configured',
          errorMessage: unavailableMessage,
        ),
      );
    }
    if (!_allowsCloudBackup()) {
      return Future.value(
        CloudBackupUploadResult(
          success: false,
          errorCode: _cloudBackupRequiresProCode,
          errorMessage: _entitlementRequiredMessage,
        ),
      );
    }
    return service.uploadCurrent();
  }

  Future<CloudBackupListResult> listRemote() async {
    final service = _service;
    if (service == null || !availability.isAvailable) {
      return CloudBackupListResult(
        success: false,
        errorCode: 'cloud_backup_not_configured',
        errorMessage: unavailableMessage,
      );
    }
    if (!_allowsCloudBackup()) {
      return CloudBackupListResult(
        success: false,
        errorCode: _cloudBackupRequiresProCode,
        errorMessage: _entitlementRequiredMessage,
      );
    }
    try {
      return CloudBackupListResult(
        success: true,
        backups: await service.listRemote(),
      );
    } on CloudBackupGatewayException catch (error) {
      return CloudBackupListResult(
        success: false,
        errorCode: error.code,
        errorMessage: error.message,
      );
    }
  }

  Future<BackupRestoreResult> restoreFromCloud(String backupId) {
    final service = _service;
    if (service == null || !availability.isAvailable) {
      return Future.value(
        BackupRestoreResult.failure(
          message: unavailableMessage,
          errorCode: 'cloud_backup_not_configured',
        ),
      );
    }
    if (!_allowsCloudBackup()) {
      return Future.value(
        BackupRestoreResult.failure(
          message: _entitlementRequiredMessage,
          errorCode: _cloudBackupRequiresProCode,
        ),
      );
    }
    return service.restoreFromCloud(backupId);
  }

  String formatRemoteTimeForDisplay(String createdAtIso) {
    final parsed = DateTime.tryParse(createdAtIso);
    if (parsed == null) return createdAtIso;
    final local = parsed.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  String formatPayloadSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}
