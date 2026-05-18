import 'dart:ui';

import '../../../data/db/database.dart';
import '../../../data/services/local_backup_export_service.dart';
import '../../../data/services/local_backup_file_naming.dart';
import '../../../data/services/local_backup_import_preview_service.dart';
import '../../../data/services/local_backup_restore_service.dart';
import '../../../data/services/local_backup_share_service.dart';
import '../../../features/device/domain/entities/local_backup_entities.dart';
import '../../../features/device/domain/repositories/local_backup_repository.dart';

class LocalBackupDataRepository implements LocalBackupRepository {
  const LocalBackupDataRepository();

  @override
  int get currentSchemaVersion => AppDatabase.schemaVersion;

  @override
  Future<LocalBackupExportResult> exportJsonBackup({
    LocalBackupExportKind kind = LocalBackupExportKind.manual,
  }) {
    return LocalBackupExportService.exportJsonBackup(kind: kind);
  }

  @override
  Future<void> shareBackupFile({
    required String filePath,
    Rect? sharePositionOrigin,
  }) {
    return const LocalBackupShareService().shareBackupFile(
      filePath: filePath,
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  @override
  Future<List<LocalBackupFile>> listLocalBackups() {
    return const LocalBackupImportPreviewService().listLocalBackups();
  }

  @override
  Future<BackupPreviewLoadResult> pickAndPreviewBackupWithJson() {
    return const LocalBackupImportPreviewService()
        .pickAndPreviewBackupWithJson();
  }

  @override
  Future<BackupPreviewLoadResult> previewLocalBackupFile(
    LocalBackupFile backup,
  ) {
    return const LocalBackupImportPreviewService().previewLocalBackupFile(
      backup,
    );
  }

  @override
  Future<BackupRestoreResult> restoreFromDecodedJson(
    Map<String, dynamic> backupJson,
  ) {
    return const LocalBackupRestoreService().restoreFromDecodedJson(backupJson);
  }

  @override
  String formatBackupTimeForDisplay(DateTime value) {
    return LocalBackupFileNaming.formatBackupTimeForDisplay(value);
  }
}
