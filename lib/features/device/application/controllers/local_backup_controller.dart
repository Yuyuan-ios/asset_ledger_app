import 'dart:ui';

import '../../domain/entities/local_backup_entities.dart';
import '../../domain/repositories/local_backup_repository.dart';

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

  String? restoreBlockReason(BackupPreview preview) {
    final schemaVersion = preview.schemaVersion;
    if (schemaVersion == null) return '备份文件格式不完整，暂不能恢复。';
    if (schemaVersion < _repository.currentSchemaVersion) {
      return '当前版本暂不支持恢复旧版备份，请使用相同版本导出的备份。';
    }
    if (schemaVersion > _repository.currentSchemaVersion) {
      return '备份文件版本较新，请升级 App 后再试。';
    }
    return null;
  }

  String formatBackupTimeForDisplay(DateTime value) {
    return _repository.formatBackupTimeForDisplay(value);
  }
}
