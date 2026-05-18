import 'dart:ui';

import '../entities/local_backup_entities.dart';

abstract class LocalBackupRepository {
  int get currentSchemaVersion;

  Future<LocalBackupExportResult> exportJsonBackup({
    LocalBackupExportKind kind = LocalBackupExportKind.manual,
  });

  Future<void> shareBackupFile({
    required String filePath,
    Rect? sharePositionOrigin,
  });

  Future<List<LocalBackupFile>> listLocalBackups();

  Future<BackupPreviewLoadResult> pickAndPreviewBackupWithJson();

  Future<BackupPreviewLoadResult> previewLocalBackupFile(
    LocalBackupFile backup,
  );

  Future<BackupRestoreResult> restoreFromDecodedJson(
    Map<String, dynamic> backupJson,
  );

  String formatBackupTimeForDisplay(DateTime value);
}
