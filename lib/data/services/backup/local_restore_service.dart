part of '../local_backup_restore_service.dart';

class LocalRestoreService {
  const LocalRestoreService({
    required LocalBackupImportPreviewService previewService,
    Future<LocalBackupExportResult> Function()? exportBackup,
  }) : _previewService = previewService,
       _exportBackup = exportBackup;

  final LocalBackupImportPreviewService _previewService;
  final Future<LocalBackupExportResult> Function()? _exportBackup;

  Future<BackupRestoreResult> restoreFromJsonString(String rawJson) async {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) {
        return BackupRestoreResult.failure(
          message: '这不是有效的 FleetLedger 备份文件',
          errorCode: 'invalid_root',
        );
      }
      return restoreFromDecodedJson(decoded);
    } on FormatException {
      return BackupRestoreResult.failure(
        message: '备份文件不是有效的 JSON，请重新选择',
        errorCode: 'invalid_json',
      );
    } catch (_) {
      return BackupRestoreResult.failure(
        message: '这不是有效的 FleetLedger 备份文件',
        errorCode: 'invalid_json',
      );
    }
  }

  Future<BackupRestoreResult> restoreFromDecodedJson(
    Map<String, dynamic> backupJson,
  ) async {
    final validation = _BackupRestoreValidator.validate(
      backupJson,
      previewService: _previewService,
    );
    if (!validation.success) return validation.failure!;

    final autoBackupResult =
        await (_exportBackup ??
            LocalBackupExportService.exportPreRestoreJsonBackup)();
    if (!autoBackupResult.success) {
      return BackupRestoreResult.failure(
        message: '恢复前自动备份失败，已终止恢复，当前数据未被修改。',
        errorCode: 'auto_backup_failed',
      );
    }

    final autoBackupPath = autoBackupResult.filePath ?? '';

    try {
      await AppDatabase.inTransaction<void>((txn) async {
        final batch = txn.batch();

        for (final tableName in BackupRestoreTables.clearOrder) {
          batch.delete(tableName);
        }

        for (final tableName in BackupRestoreTables.insertOrder) {
          final rows = validation.rowsByTable[tableName]!;
          for (final row in rows) {
            batch.insert(
              tableName,
              row,
              conflictAlgorithm: ConflictAlgorithm.abort,
            );
          }
        }

        await batch.commit(noResult: true);
      });

      return BackupRestoreResult.success(
        autoBackupPath: autoBackupPath,
        restoredCounts: validation.restoredCounts,
      );
    } catch (_) {
      return BackupRestoreResult.failure(
        message: '恢复失败，数据库已回滚，当前数据保持恢复前状态。',
        errorCode: 'transaction_failed',
        autoBackupPath: autoBackupPath,
      );
    }
  }
}
