import '../../../../data/models/backup_restore_result.dart';
import '../../../../data/services/backup/cloud_backup_service.dart';
import '../../../../infrastructure/cloud/cloud_backup_gateway.dart';

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
  }) : _service = service;

  CloudBackupController.unavailable(String message)
    : _service = null,
      availability = CloudBackupAvailability.unavailable(message);

  final CloudBackupService? _service;
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
