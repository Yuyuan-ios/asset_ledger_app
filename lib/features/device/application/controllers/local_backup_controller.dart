import 'dart:ui';

import '../../../../data/db/database.dart';
import '../../../../data/services/local_backup_export_service.dart';
import '../../../../data/services/local_backup_file_naming.dart';
import '../../../../data/services/local_backup_import_preview_service.dart';
import '../../../../data/services/local_backup_restore_service.dart';
import '../../../../data/services/local_backup_share_service.dart';
import '../../domain/entities/local_backup_entities.dart';

class LocalBackupController {
  const LocalBackupController();

  Future<LocalBackupExportResult> exportJsonBackup({
    LocalBackupExportKind kind = LocalBackupExportKind.manual,
  }) {
    return LocalBackupExportService.exportJsonBackup(kind: kind);
  }

  Future<void> shareBackupFile({
    required String filePath,
    Rect? sharePositionOrigin,
  }) {
    return const LocalBackupShareService().shareBackupFile(
      filePath: filePath,
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  Future<List<LocalBackupFile>> listLocalBackups() {
    return const LocalBackupImportPreviewService().listLocalBackups();
  }

  Future<BackupPreviewLoadResult> pickAndPreviewBackupWithJson() {
    return const LocalBackupImportPreviewService()
        .pickAndPreviewBackupWithJson();
  }

  Future<BackupPreviewLoadResult> previewLocalBackupFile(
    LocalBackupFile backup,
  ) {
    return const LocalBackupImportPreviewService().previewLocalBackupFile(
      backup,
    );
  }

  Future<BackupRestoreResult> restoreFromDecodedJson(
    Map<String, dynamic> backupJson,
  ) {
    return const LocalBackupRestoreService().restoreFromDecodedJson(backupJson);
  }

  String? restoreBlockReason(BackupPreview preview) {
    final schemaVersion = preview.schemaVersion;
    if (schemaVersion == null) return '备份文件格式不完整，暂不能恢复。';
    if (schemaVersion < AppDatabase.schemaVersion) {
      return '当前版本暂不支持恢复旧版备份，请使用相同版本导出的备份。';
    }
    if (schemaVersion > AppDatabase.schemaVersion) {
      return '备份文件版本较新，请升级 App 后再试。';
    }
    return null;
  }

  String formatBackupTimeForDisplay(DateTime value) {
    return LocalBackupFileNaming.formatBackupTimeForDisplay(value);
  }
}
