part of '../local_backup_restore_service.dart';

class _BackupRestoreValidator {
  const _BackupRestoreValidator._();

  static _RestoreValidation validate(
    Map<String, dynamic> backupJson, {
    required LocalBackupImportPreviewService previewService,
  }) {
    final envelopeValidation = _validateBackupEnvelope(
      backupJson,
      previewService: previewService,
    );
    final envelopeFailure = envelopeValidation.failure;
    if (envelopeFailure != null) return envelopeFailure;

    final data = envelopeValidation.envelope!.data;

    final rowsByTable = <String, List<Map<String, Object?>>>{};
    final restoredCounts = <String, int>{};
    final hasProjectsTable = data['projects'] is List;

    for (final tableName in BackupRestoreTables.insertOrder) {
      final rows = data[tableName];
      if (rows == null) {
        if (tableName == 'projects' && !hasProjectsTable) {
          rowsByTable[tableName] = const <Map<String, Object?>>[];
          restoredCounts[tableName] = 0;
          continue;
        }
        if (BackupRestoreTables.optionalTables.contains(tableName)) {
          rowsByTable[tableName] = const <Map<String, Object?>>[];
          restoredCounts[tableName] = 0;
          continue;
        }
        return _RestoreValidation.failure(
          BackupRestoreResult.failure(
            message: '备份文件格式不完整：缺少业务数据',
            errorCode: 'missing_table_$tableName',
          ),
        );
      }

      if (rows is! List) {
        return _RestoreValidation.failure(
          BackupRestoreResult.failure(
            message: '备份数据结构异常，无法恢复',
            errorCode: 'invalid_table_$tableName',
          ),
        );
      }

      final normalizedRows = <Map<String, Object?>>[];
      for (var index = 0; index < rows.length; index += 1) {
        final row = rows[index];
        if (row is! Map) {
          return _RestoreValidation.failure(
            BackupRestoreResult.failure(
              message: '备份数据结构异常，无法恢复',
              errorCode: 'invalid_row_${tableName}_$index',
            ),
          );
        }

        final normalizedRow = _normalizeRow(
          tableName,
          row,
          allowLegacyProjectIdentity: !hasProjectsTable,
        );
        final missingColumn = _firstMissingColumn(tableName, normalizedRow);
        if (missingColumn != null) {
          return _RestoreValidation.failure(
            BackupRestoreResult.failure(
              message: '备份文件格式不完整：$tableName 缺少 $missingColumn',
              errorCode: 'missing_column_${tableName}_$missingColumn',
            ),
          );
        }

        final typeError = _validateColumnTypes(tableName, normalizedRow);
        if (typeError != null) {
          return _RestoreValidation.failure(
            BackupRestoreResult.failure(
              message: '备份数据结构异常，无法恢复',
              errorCode: typeError,
            ),
          );
        }

        normalizedRows.add(normalizedRow);
      }

      rowsByTable[tableName] = normalizedRows;
      restoredCounts[tableName] = normalizedRows.length;
    }

    if (!hasProjectsTable) {
      final projectRows = _deriveLegacyProjectRows(rowsByTable);
      rowsByTable['projects'] = projectRows;
      restoredCounts['projects'] = projectRows.length;
    }

    final referenceError = _validateProjectReferences(rowsByTable);
    if (referenceError != null) {
      return _RestoreValidation.failure(
        BackupRestoreResult.failure(
          message: '备份数据存在无效项目关联，无法恢复',
          errorCode: referenceError,
        ),
      );
    }

    // external_work_records.linked_project_id 在恢复包项目表中找不到时：
    // 保留外协记录但解除关联，不阻止整体恢复，并把信息以 warning 形式上报。
    final warnings = _detachOrphanExternalWorkLinks(rowsByTable);

    return _RestoreValidation.success(
      rowsByTable: rowsByTable,
      restoredCounts: restoredCounts,
      warnings: warnings,
    );
  }
}
