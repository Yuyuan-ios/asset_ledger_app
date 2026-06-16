part of '../local_backup_restore_service.dart';

class LocalRestoreService {
  const LocalRestoreService({
    required LocalBackupImportPreviewService previewService,
    Future<LocalBackupExportResult> Function()? exportBackup,
    SyncStateRepository syncStateRepository = const LocalSyncStateRepository(),
  }) : _previewService = previewService,
       _exportBackup = exportBackup,
       _syncStateRepository = syncStateRepository;

  final LocalBackupImportPreviewService _previewService;
  final Future<LocalBackupExportResult> Function()? _exportBackup;
  final SyncStateRepository _syncStateRepository;

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

        // R5.21 restore reconcile：在同一事务里把同步状态清空并打上
        // push gate=restore-pending。三件事与业务恢复同时提交或同时回滚，
        // 避免「业务表已 restore 但 sync_outbox 仍残留旧 pending 行」
        // 在未来 Cloud push 接通时把残留 outbox 静默推到云端。
        await txn.delete('sync_outbox');
        await txn.delete('entity_sync_meta');
        await txn.delete('sync_conflicts');
        await _syncStateRepository.markPushGateRestorePendingWithExecutor(txn);
      });

      return BackupRestoreResult.success(
        autoBackupPath: autoBackupPath,
        restoredCounts: validation.restoredCounts,
        warnings: validation.warnings,
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
