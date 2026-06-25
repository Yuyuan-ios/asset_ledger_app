import 'dart:ui';

import '../../domain/entities/local_backup_entities.dart';
import '../../domain/repositories/local_backup_repository.dart';

/// 恢复被阻断的原因 code；用户可见文案由 view 层映射 AppLocalizations。
enum RestoreBlockReason { incompleteFormat, olderUnsupported, newerVersion }

class LocalBackupController {
  const LocalBackupController(this._repository);

  final LocalBackupRepository _repository;

  Future<LocalBackupExportResult> exportJsonBackup({
    LocalBackupExportKind kind = LocalBackupExportKind.manual,
  }) {
    return _repository.exportJsonBackup(kind: kind);
  }

  Future<void> shareBackupFile({
    required String filePath,
    Rect? sharePositionOrigin,
  }) {
    return _repository.shareBackupFile(
      filePath: filePath,
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  Future<List<LocalBackupFile>> listLocalBackups() {
    return _repository.listLocalBackups();
  }

  Future<BackupPreviewLoadResult> pickAndPreviewBackupWithJson() {
    return _repository.pickAndPreviewBackupWithJson();
  }

  Future<BackupPreviewLoadResult> previewLocalBackupFile(
    LocalBackupFile backup,
  ) {
    return _repository.previewLocalBackupFile(backup);
  }

  Future<BackupRestoreResult> restoreFromDecodedJson(
    Map<String, dynamic> backupJson,
  ) {
    return _repository.restoreFromDecodedJson(backupJson);
  }

  RestoreBlockReason? restoreBlockReason(BackupPreview preview) {
    final schemaVersion = preview.schemaVersion;
    if (schemaVersion == null) return RestoreBlockReason.incompleteFormat;
    if (schemaVersion < _repository.currentSchemaVersion) {
      return RestoreBlockReason.olderUnsupported;
    }
    if (schemaVersion > _repository.currentSchemaVersion) {
      return RestoreBlockReason.newerVersion;
    }
    return null;
  }

  String formatBackupTimeForDisplay(DateTime value) {
    return _repository.formatBackupTimeForDisplay(value);
  }
}
