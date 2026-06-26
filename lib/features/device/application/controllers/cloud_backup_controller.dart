import '../../../../data/models/backup_restore_result.dart';
import '../../../../data/services/backup/cloud_backup_service.dart';
import '../../../../infrastructure/cloud/cloud_backup_gateway.dart';

/// 云端备份失败的结果 code（application 层常量）。用户可见文案不在本层产出：
/// `errorMessage` / `message` 仅承载 server 下发文案或留空，由 view 层据 code
/// 映射 AppLocalizations（参照 [SupportEntryOutcome] 的 code→l10n 模式）。
const cloudBackupRequiresMaxCode = 'cloud_backup_requires_max';
const cloudBackupNotConfiguredCode = 'cloud_backup_not_configured';

bool _denyCloudBackupByDefault() => false;

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
    required bool Function() canUseCloudBackup,
    this.availability = const CloudBackupAvailability.available(),
  }) : _service = service,
       _canUseCloudBackup = canUseCloudBackup;

  CloudBackupController.unavailable(String? message)
    : _service = null,
      availability = CloudBackupAvailability.unavailable(message),
      _canUseCloudBackup = _denyCloudBackupByDefault;

  final CloudBackupService? _service;
  final bool Function() _canUseCloudBackup;
  final CloudBackupAvailability availability;

  bool get isAvailable => availability.isAvailable;

  /// server 下发的不可用文案（nullable）。view 层据此显示，缺省时兜底为
  /// 本地化的 `deviceCloudBackupNotConfigured`。
  String? get serverUnavailableMessage => availability.message;

  Future<CloudBackupUploadResult> uploadCurrent() {
    final service = _service;
    if (service == null || !availability.isAvailable) {
      return Future.value(
        CloudBackupUploadResult(
          success: false,
          errorCode: cloudBackupNotConfiguredCode,
          errorMessage: availability.message,
        ),
      );
    }
    if (!_canUseCloudBackup()) {
      return Future.value(
        CloudBackupUploadResult(
          success: false,
          errorCode: cloudBackupRequiresMaxCode,
          errorMessage: null,
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
        errorCode: cloudBackupNotConfiguredCode,
        errorMessage: availability.message,
      );
    }
    if (!_canUseCloudBackup()) {
      return CloudBackupListResult(
        success: false,
        errorCode: cloudBackupRequiresMaxCode,
        errorMessage: null,
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
          // message 非空字段：not-configured 承载 server 文案(缺省留空),
          // errorCode 权威,view 据 code 兜底本地化文案。
          message: availability.message ?? '',
          errorCode: cloudBackupNotConfiguredCode,
        ),
      );
    }
    if (!_canUseCloudBackup()) {
      return Future.value(
        BackupRestoreResult.failure(
          // requires-max 不带文案,errorCode 权威。
          message: '',
          errorCode: cloudBackupRequiresMaxCode,
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
