part of '../local_backup_restore_service.dart';

class _BackupRestoreValidator {
  const _BackupRestoreValidator._();

  static const String _externalWorkRecordsTable = 'external_work_records';
  static const String _externalImportBatchesTable = 'external_import_batches';

  static _RestoreValidation validate(
    Map<String, dynamic> backupJson, {
    required LocalBackupImportPreviewService previewService,
  }) {
    final preview = previewService.previewFromDecodedJson(backupJson);
    if (!preview.isValid) {
      return _RestoreValidation.failure(
        BackupRestoreResult.failure(
          message: preview.errorMessage ?? '备份文件格式不完整',
          errorCode: 'preview_validation_failed',
        ),
      );
    }

    final meta = backupJson['meta'];
    final data = backupJson['data'];

    if (meta is! Map<String, dynamic>) {
      return _RestoreValidation.failure(
        BackupRestoreResult.failure(
          message: '备份文件格式不完整：缺少 meta',
          errorCode: 'missing_meta',
        ),
      );
    }

    if (data is! Map<String, dynamic>) {
      return _RestoreValidation.failure(
        BackupRestoreResult.failure(
          message: '备份文件格式不完整：缺少 data',
          errorCode: 'missing_data',
        ),
      );
    }

    if (!BackupRestoreTables.isSupportedAppName(meta['app_name'])) {
      return _RestoreValidation.failure(
        BackupRestoreResult.failure(
          message: '这不是有效的 FleetLedger 备份文件',
          errorCode: 'app_name_mismatch',
        ),
      );
    }

    final schemaVersion = _readInt(meta['schema_version']);
    if (schemaVersion == null) {
      return _RestoreValidation.failure(
        BackupRestoreResult.failure(
          message: '备份文件格式不完整：缺少数据库版本',
          errorCode: 'missing_schema_version',
        ),
      );
    }

    if (schemaVersion > AppDatabase.schemaVersion) {
      return _RestoreValidation.failure(
        BackupRestoreResult.failure(
          message: '备份文件版本较新，请升级 App 后再试',
          errorCode: 'schema_version_newer',
        ),
      );
    }

    final exportFormatVersion = _readInt(meta['export_format_version']);
    if (exportFormatVersion == null) {
      return _RestoreValidation.failure(
        BackupRestoreResult.failure(
          message: '备份文件格式不完整：缺少备份版本',
          errorCode: 'missing_export_format_version',
        ),
      );
    }

    if (exportFormatVersion < 1 ||
        exportFormatVersion >
            BackupRestoreTables.supportedExportFormatVersion) {
      return _RestoreValidation.failure(
        BackupRestoreResult.failure(
          message: '当前版本暂不支持该备份格式',
          errorCode: 'unsupported_export_format_version',
        ),
      );
    }

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

    // 外协 linked_project_id 在恢复包项目表中找不到时：保留外协记录但解除关联，
    // 不阻止整体恢复，并把信息以 warning 形式上报。
    final warnings = _detachOrphanExternalWorkLinks(rowsByTable);

    return _RestoreValidation.success(
      rowsByTable: rowsByTable,
      restoredCounts: restoredCounts,
      warnings: warnings,
    );
  }

  static List<BackupRestoreWarning> _detachOrphanExternalWorkLinks(
    Map<String, List<Map<String, Object?>>> rowsByTable,
  ) {
    final externalRows = rowsByTable[_externalWorkRecordsTable];
    if (externalRows == null || externalRows.isEmpty) return const [];

    final projectIds = <String>{
      for (final row in rowsByTable['projects'] ?? const [])
        if (row['id'] is String) row['id'] as String,
    };

    final detachedIds = <String>[];
    for (var index = 0; index < externalRows.length; index += 1) {
      final row = externalRows[index];
      final linked = row['linked_project_id'];
      if (linked is! String) continue;
      if (linked.trim().isEmpty) continue;
      if (projectIds.contains(linked)) continue;

      final detached = Map<String, Object?>.from(row);
      detached['linked_project_id'] = null;
      externalRows[index] = detached;
      detachedIds.add((row['id'] as String?) ?? '');
    }

    if (detachedIds.isEmpty) return const [];

    return [
      BackupRestoreWarning(
        code: BackupRestoreWarningCode.externalWorkLinkedProjectMissing,
        message: '部分外协记录已恢复为未关联状态（关联项目不在备份中）',
        context: {
          'detached_count': detachedIds.length,
          'external_work_record_ids': List<String>.unmodifiable(detachedIds),
        },
      ),
    ];
  }

  static Map<String, Object?> _normalizeRow(
    String tableName,
    Map row, {
    required bool allowLegacyProjectIdentity,
  }) {
    final normalized = <String, Object?>{};
    for (final entry in row.entries) {
      final key = entry.key;
      if (key is String) {
        normalized[key] = entry.value;
      }
    }
    switch (tableName) {
      case 'projects':
        final contact = (normalized['contact'] as String?) ?? '';
        final site = (normalized['site'] as String?) ?? '';
        normalized['legacy_project_key'] ??= ProjectKey.buildKey(
          contact: contact,
          site: site,
        );
        break;
      case 'devices':
        normalized['equipment_type'] ??= 'excavator';
        break;
      case 'timing_records':
        normalized['contact'] ??= '';
        normalized['site'] ??= '';
        if (allowLegacyProjectIdentity) {
          normalized['project_id'] ??= Project.legacy(
            contact: normalized['contact'] as String,
            site: normalized['site'] as String,
            timestamp: BackupRestoreTables.legacyProjectTimestamp,
          ).id;
        }
        // R5.26-B3：旧备份缺 income_fen 时按 income 回填整数分镜像，避免回灌出
        // NULL income_fen；已有非 NULL income_fen 不被覆盖。
        normalized['income_fen'] ??= _fenFromYuan(normalized['income']);
        break;
      case 'account_payments':
        if (allowLegacyProjectIdentity) {
          normalized['project_id'] ??= _legacyProjectIdFromKey(
            normalized['project_key'],
          );
        }
        normalized['source_type'] ??= 'manual';
        normalized['amount_fen'] ??= _fenFromYuan(normalized['amount']);
        normalized.putIfAbsent('merge_group_id', () => null);
        normalized.putIfAbsent('merge_batch_id', () => null);
        normalized.putIfAbsent('merge_batch_total_amount', () => null);
        normalized['merge_batch_total_amount_fen'] ??= _fenFromYuan(
          normalized['merge_batch_total_amount'],
        );
        normalized.putIfAbsent('merge_batch_note', () => null);
        normalized.putIfAbsent('created_at', () => null);
        break;
      case 'project_device_rates':
        if (allowLegacyProjectIdentity) {
          normalized['project_id'] ??= _legacyProjectIdFromKey(
            normalized['project_key'],
          );
        }
        normalized['is_breaking'] ??= 0;
        break;
      case 'project_write_offs':
        normalized['amount_fen'] ??= _fenFromYuan(normalized['amount']);
        normalized.putIfAbsent('note', () => null);
        break;
      case 'account_project_merge_members':
        if (allowLegacyProjectIdentity) {
          normalized['project_id'] ??= _legacyProjectIdFromKey(
            normalized['project_key'],
          );
        }
        break;
      case _externalImportBatchesTable:
        normalized['record_count'] ??= 0;
        normalized['total_hours_milli'] ??= 0;
        normalized['total_amount_fen'] ??= 0;
        normalized['site_summary'] ??= '';
        normalized['status'] ??= 'active';
        break;
      case _externalWorkRecordsTable:
        normalized.putIfAbsent('equipment_brand', () => null);
        normalized.putIfAbsent('equipment_model', () => null);
        normalized.putIfAbsent('equipment_type', () => null);
        normalized.putIfAbsent('source_unit_price_fen', () => null);
        normalized.putIfAbsent('local_unit_price_fen', () => null);
        normalized['project_received_fen'] ??= 0;
        normalized.putIfAbsent('linked_project_id', () => null);
        normalized['record_kind'] ??= 'hours';
        normalized['status'] ??= 'active';
        normalized.putIfAbsent('note', () => null);
        break;
    }
    return normalized;
  }

  static String? _firstMissingColumn(
    String tableName,
    Map<String, Object?> row,
  ) {
    final requiredColumns =
        BackupRestoreTables.requiredColumns[tableName] ?? const <String>[];
    for (final column in requiredColumns) {
      if (!row.containsKey(column)) return column;
    }
    return null;
  }

  static String? _validateColumnTypes(
    String tableName,
    Map<String, Object?> row,
  ) {
    switch (tableName) {
      case 'devices':
        return _validateDevicesRow(row);
      case 'projects':
        return _validateProjectRow(row);
      case 'timing_records':
        return _validateTimingRow(row);
      case 'fuel_logs':
        return _validateFuelRow(row);
      case 'maintenance_records':
        return _validateMaintenanceRow(row);
      case 'account_payments':
        return _validateAccountPaymentRow(row);
      case 'project_write_offs':
        return _validateProjectWriteOffRow(row);
      case 'project_device_rates':
        return _validateProjectDeviceRateRow(row);
      case 'timing_calculation_history':
        return _validateTimingCalculationHistoryRow(row);
      case 'account_project_merge_groups':
        return _validateAccountProjectMergeGroupRow(row);
      case 'account_project_merge_members':
        return _validateAccountProjectMergeMemberRow(row);
      case _externalImportBatchesTable:
        return _validateExternalImportBatchRow(row);
      case _externalWorkRecordsTable:
        return _validateExternalWorkRecordRow(row);
      default:
        return 'unknown_table_$tableName';
    }
  }

  static String? _validateExternalImportBatchRow(Map<String, Object?> row) {
    if (!_isNonEmptyString(row['id'])) {
      return 'invalid_external_import_batches_id';
    }
    if (!_isNonEmptyString(row['source_share_id'])) {
      return 'invalid_external_import_batches_source_share_id';
    }
    if (!_isString(row['source_display_name'])) {
      return 'invalid_external_import_batches_source_display_name';
    }
    if (!_isNullableNonNegativeInt(row['record_count'])) {
      return 'invalid_external_import_batches_record_count';
    }
    if (!_isNullableNonNegativeInt(row['total_hours_milli'])) {
      return 'invalid_external_import_batches_total_hours_milli';
    }
    if (!_isNullableNonNegativeInt(row['total_amount_fen'])) {
      return 'invalid_external_import_batches_total_amount_fen';
    }
    if (!_isNullableString(row['site_summary'])) {
      return 'invalid_external_import_batches_site_summary';
    }
    if (!_isNonEmptyString(row['imported_at'])) {
      return 'invalid_external_import_batches_imported_at';
    }
    if (!_isNullableString(row['status'])) {
      return 'invalid_external_import_batches_status';
    }
    if (!_isNonEmptyString(row['created_at'])) {
      return 'invalid_external_import_batches_created_at';
    }
    if (!_isNonEmptyString(row['updated_at'])) {
      return 'invalid_external_import_batches_updated_at';
    }
    return null;
  }

  static String? _validateExternalWorkRecordRow(Map<String, Object?> row) {
    if (!_isNonEmptyString(row['id'])) {
      return 'invalid_external_work_records_id';
    }
    if (!_isNonEmptyString(row['import_batch_id'])) {
      return 'invalid_external_work_records_import_batch_id';
    }
    if (!_isNonEmptyString(row['source_share_id'])) {
      return 'invalid_external_work_records_source_share_id';
    }
    if (!_isNonEmptyString(row['source_record_uuid'])) {
      return 'invalid_external_work_records_source_record_uuid';
    }
    if (!_isNonEmptyString(row['source_installation_uuid'])) {
      return 'invalid_external_work_records_source_installation_uuid';
    }
    if (!_isNonEmptyString(row['origin_fingerprint'])) {
      return 'invalid_external_work_records_origin_fingerprint';
    }
    if (!_isString(row['collaborator_name'])) {
      return 'invalid_external_work_records_collaborator_name';
    }
    if (!_isString(row['contact_snapshot'])) {
      return 'invalid_external_work_records_contact_snapshot';
    }
    if (!_isString(row['site_snapshot'])) {
      return 'invalid_external_work_records_site_snapshot';
    }
    if (!_isInt(row['work_date'])) {
      return 'invalid_external_work_records_work_date';
    }
    if (!_isNonNegativeInt(row['hours_milli'])) {
      return 'invalid_external_work_records_hours_milli';
    }
    if (!_isNullableNonNegativeInt(row['source_unit_price_fen'])) {
      return 'invalid_external_work_records_source_unit_price_fen';
    }
    if (!_isNullableNonNegativeInt(row['local_unit_price_fen'])) {
      return 'invalid_external_work_records_local_unit_price_fen';
    }
    if (!_isNonNegativeInt(row['amount_fen'])) {
      return 'invalid_external_work_records_amount_fen';
    }
    if (!_isNullableNonNegativeInt(row['project_received_fen'])) {
      return 'invalid_external_work_records_project_received_fen';
    }
    if (!_isNullableString(row['linked_project_id'])) {
      return 'invalid_external_work_records_linked_project_id';
    }
    if (!_isNullableString(row['record_kind'])) {
      return 'invalid_external_work_records_record_kind';
    }
    if (!_isNullableString(row['status'])) {
      return 'invalid_external_work_records_status';
    }
    if (!_isNonEmptyString(row['created_at'])) {
      return 'invalid_external_work_records_created_at';
    }
    if (!_isNonEmptyString(row['updated_at'])) {
      return 'invalid_external_work_records_updated_at';
    }
    return null;
  }

  static String? _validateDevicesRow(Map<String, Object?> row) {
    if (!_isNullableInt(row['id'])) return 'invalid_devices_id';
    if (!_isString(row['name'])) return 'invalid_devices_name';
    if (!_isString(row['brand'])) return 'invalid_devices_brand';
    if (!_isNullableString(row['model'])) return 'invalid_devices_model';
    if (!_isNumber(row['default_unit_price'])) {
      return 'invalid_devices_default_unit_price';
    }
    if (!_isNullableNumber(row['breaking_unit_price'])) {
      return 'invalid_devices_breaking_unit_price';
    }
    if (!_isNumber(row['base_meter_hours'])) {
      return 'invalid_devices_base_meter_hours';
    }
    if (!_isBooleanInt(row['is_active'])) return 'invalid_devices_is_active';
    if (!_isNullableString(row['custom_avatar_path'])) {
      return 'invalid_devices_custom_avatar_path';
    }
    if (!_isString(row['equipment_type'])) {
      return 'invalid_devices_equipment_type';
    }
    return null;
  }

  static String? _validateProjectRow(Map<String, Object?> row) {
    if (!_isNonEmptyString(row['id'])) return 'invalid_projects_id';
    if (!_isString(row['contact'])) return 'invalid_projects_contact';
    if (!_isString(row['site'])) return 'invalid_projects_site';
    if (!_isString(row['created_at'])) return 'invalid_projects_created_at';
    if (!_isString(row['updated_at'])) return 'invalid_projects_updated_at';
    if (!_isNullableString(row['legacy_project_key'])) {
      return 'invalid_projects_legacy_project_key';
    }
    return null;
  }

  static String? _validateTimingRow(Map<String, Object?> row) {
    if (!_isNullableInt(row['id'])) return 'invalid_timing_records_id';
    if (!_isNonEmptyString(row['project_id'])) {
      return 'invalid_timing_records_project_id';
    }
    if (!_isInt(row['device_id'])) return 'invalid_timing_records_device_id';
    if (!_isInt(row['start_date'])) {
      return 'invalid_timing_records_start_date';
    }
    if (!_isNullableString(row['contact'])) {
      return 'invalid_timing_records_contact';
    }
    if (!_isNullableString(row['site'])) return 'invalid_timing_records_site';
    final type = row['type'];
    if (type is! String) return 'invalid_timing_records_type';
    if (!TimingType.values.any((value) => value.name == type)) {
      return 'invalid_timing_records_type';
    }
    if (!_isNumber(row['start_meter'])) {
      return 'invalid_timing_records_start_meter';
    }
    if (!_isNumber(row['end_meter'])) return 'invalid_timing_records_end_meter';
    if (!_isNumber(row['hours'])) return 'invalid_timing_records_hours';
    if (!_isNumber(row['income'])) return 'invalid_timing_records_income';
    if (!_isNullableInt(row['income_fen'])) {
      return 'invalid_timing_records_income_fen';
    }
    if (!_isNullableInt(row['display_end_date'])) {
      return 'invalid_timing_records_display_end_date';
    }
    if (!_isNullableInt(row['exclude_from_fuel_eff'])) {
      return 'invalid_timing_records_exclude_from_fuel_eff';
    }
    if (!_isNullableBooleanInt(row['is_breaking'])) {
      return 'invalid_timing_records_is_breaking';
    }
    return null;
  }

  static String? _validateFuelRow(Map<String, Object?> row) {
    if (!_isNullableInt(row['id'])) return 'invalid_fuel_logs_id';
    if (!_isInt(row['device_id'])) return 'invalid_fuel_logs_device_id';
    if (!_isInt(row['date'])) return 'invalid_fuel_logs_date';
    if (!_isNullableString(row['supplier'])) {
      return 'invalid_fuel_logs_supplier';
    }
    if (!_isNumber(row['liters'])) return 'invalid_fuel_logs_liters';
    if (!_isNumber(row['cost'])) return 'invalid_fuel_logs_cost';
    return null;
  }

  static String? _validateMaintenanceRow(Map<String, Object?> row) {
    if (!_isNullableInt(row['id'])) return 'invalid_maintenance_records_id';
    if (!_isNullableInt(row['device_id'])) {
      return 'invalid_maintenance_records_device_id';
    }
    if (!_isInt(row['ymd'])) return 'invalid_maintenance_records_ymd';
    if (!_isString(row['item'])) return 'invalid_maintenance_records_item';
    if (!_isNumber(row['amount'])) return 'invalid_maintenance_records_amount';
    if (!_isNullableString(row['note'])) {
      return 'invalid_maintenance_records_note';
    }
    return null;
  }

  static String? _validateAccountPaymentRow(Map<String, Object?> row) {
    if (!_isNullableInt(row['id'])) return 'invalid_account_payments_id';
    if (!_isNonEmptyString(row['project_id'])) {
      return 'invalid_account_payments_project_id';
    }
    if (!_isString(row['project_key'])) {
      return 'invalid_account_payments_project_key';
    }
    if (!_isInt(row['ymd'])) return 'invalid_account_payments_ymd';
    if (!_isNumber(row['amount'])) return 'invalid_account_payments_amount';
    if (!_isNullableInt(row['amount_fen'])) {
      return 'invalid_account_payments_amount_fen';
    }
    if (!_isNullableString(row['note'])) return 'invalid_account_payments_note';
    if (!_isString(row['source_type'])) {
      return 'invalid_account_payments_source_type';
    }
    const sourceTypes = {
      AccountPayment.sourceTypeManual,
      AccountPayment.sourceTypeMergeAllocation,
    };
    if (!sourceTypes.contains(row['source_type'])) {
      return 'invalid_account_payments_source_type';
    }
    if (!_isNullableInt(row['merge_group_id'])) {
      return 'invalid_account_payments_merge_group_id';
    }
    if (!_isNullableString(row['merge_batch_id'])) {
      return 'invalid_account_payments_merge_batch_id';
    }
    if (!_isNullableNumber(row['merge_batch_total_amount'])) {
      return 'invalid_account_payments_merge_batch_total_amount';
    }
    if (!_isNullableInt(row['merge_batch_total_amount_fen'])) {
      return 'invalid_account_payments_merge_batch_total_amount_fen';
    }
    if (!_isNullableString(row['merge_batch_note'])) {
      return 'invalid_account_payments_merge_batch_note';
    }
    if (!_isNullableString(row['created_at'])) {
      return 'invalid_account_payments_created_at';
    }
    return null;
  }

  static String? _validateProjectDeviceRateRow(Map<String, Object?> row) {
    if (!_isNonEmptyString(row['project_id'])) {
      return 'invalid_project_device_rates_project_id';
    }
    if (!_isString(row['project_key'])) {
      return 'invalid_project_device_rates_project_key';
    }
    if (!_isInt(row['device_id'])) {
      return 'invalid_project_device_rates_device_id';
    }
    if (!_isBooleanInt(row['is_breaking'])) {
      return 'invalid_project_device_rates_is_breaking';
    }
    if (!_isNumber(row['rate'])) return 'invalid_project_device_rates_rate';
    return null;
  }

  static String? _validateProjectWriteOffRow(Map<String, Object?> row) {
    if (!_isNonEmptyString(row['id'])) return 'invalid_project_write_offs_id';
    if (!_isNonEmptyString(row['project_id'])) {
      return 'invalid_project_write_offs_project_id';
    }
    final amount = row['amount'];
    if (!_isNumber(amount) || (amount as num) <= 0) {
      return 'invalid_project_write_offs_amount';
    }
    if (!_isNullableInt(row['amount_fen'])) {
      return 'invalid_project_write_offs_amount_fen';
    }
    final reason = row['reason'];
    if (!_isNonEmptyString(reason)) {
      return 'invalid_project_write_offs_reason';
    }
    if (!ProjectWriteOffReasonX.isKnownDbValue(reason as String)) {
      return 'invalid_project_write_offs_reason';
    }
    if (!_isNullableString(row['note'])) {
      return 'invalid_project_write_offs_note';
    }
    if (!_isNonEmptyString(row['write_off_date'])) {
      return 'invalid_project_write_offs_write_off_date';
    }
    if (!_isNonEmptyString(row['created_at'])) {
      return 'invalid_project_write_offs_created_at';
    }
    if (!_isNonEmptyString(row['updated_at'])) {
      return 'invalid_project_write_offs_updated_at';
    }
    return null;
  }

  static String? _validateTimingCalculationHistoryRow(
    Map<String, Object?> row,
  ) {
    if (!_isString(row['id'])) return 'invalid_timing_calculation_history_id';
    if (!_isInt(row['timing_record_id'])) {
      return 'invalid_timing_calculation_history_timing_record_id';
    }
    if (!_isString(row['created_at'])) {
      return 'invalid_timing_calculation_history_created_at';
    }
    if (!_isString(row['expression'])) {
      return 'invalid_timing_calculation_history_expression';
    }
    if (!_isNumber(row['result'])) {
      return 'invalid_timing_calculation_history_result';
    }
    if (!_isInt(row['ticket_count'])) {
      return 'invalid_timing_calculation_history_ticket_count';
    }
    return null;
  }

  static String? _validateAccountProjectMergeGroupRow(
    Map<String, Object?> row,
  ) {
    if (!_isNullableInt(row['id'])) {
      return 'invalid_account_project_merge_groups_id';
    }
    if (!_isString(row['contact'])) {
      return 'invalid_account_project_merge_groups_contact';
    }
    if (!_isString(row['created_at'])) {
      return 'invalid_account_project_merge_groups_created_at';
    }
    if (!_isNullableString(row['updated_at'])) {
      return 'invalid_account_project_merge_groups_updated_at';
    }
    if (!_isBooleanInt(row['is_active'])) {
      return 'invalid_account_project_merge_groups_is_active';
    }
    if (!_isNullableString(row['dissolved_at'])) {
      return 'invalid_account_project_merge_groups_dissolved_at';
    }
    if (!_isString(row['source_type'])) {
      return 'invalid_account_project_merge_groups_source_type';
    }
    if (row['source_type'] != 'local') {
      return 'invalid_account_project_merge_groups_source_type';
    }
    return null;
  }

  static String? _validateAccountProjectMergeMemberRow(
    Map<String, Object?> row,
  ) {
    if (!_isNullableInt(row['id'])) {
      return 'invalid_account_project_merge_members_id';
    }
    if (!_isInt(row['group_id'])) {
      return 'invalid_account_project_merge_members_group_id';
    }
    if (!_isNonEmptyString(row['project_id'])) {
      return 'invalid_account_project_merge_members_project_id';
    }
    if (!_isString(row['project_key'])) {
      return 'invalid_account_project_merge_members_project_key';
    }
    if (!_isString(row['contact'])) {
      return 'invalid_account_project_merge_members_contact';
    }
    if (!_isString(row['site'])) {
      return 'invalid_account_project_merge_members_site';
    }
    if (!_isInt(row['sort_order'])) {
      return 'invalid_account_project_merge_members_sort_order';
    }
    if (!_isString(row['created_at'])) {
      return 'invalid_account_project_merge_members_created_at';
    }
    if (!_isBooleanInt(row['is_active'])) {
      return 'invalid_account_project_merge_members_is_active';
    }
    return null;
  }

  static List<Map<String, Object?>> _deriveLegacyProjectRows(
    Map<String, List<Map<String, Object?>>> rowsByTable,
  ) {
    final projectsById = <String, Map<String, Object?>>{};

    void addProject({
      required String projectId,
      required String contact,
      required String site,
      String? legacyProjectKey,
    }) {
      if (projectId.trim().isEmpty || projectsById.containsKey(projectId)) {
        return;
      }
      final key =
          legacyProjectKey ?? ProjectKey.buildKey(contact: contact, site: site);
      projectsById[projectId] = Project(
        id: projectId,
        contact: contact.trim(),
        site: site.trim(),
        createdAt: BackupRestoreTables.legacyProjectTimestamp,
        updatedAt: BackupRestoreTables.legacyProjectTimestamp,
        legacyProjectKey: key,
      ).toMap();
    }

    for (final row in rowsByTable['timing_records'] ?? const []) {
      final contact = (row['contact'] as String?) ?? '';
      final site = (row['site'] as String?) ?? '';
      addProject(
        projectId: row['project_id'] as String,
        contact: contact,
        site: site,
      );
    }

    for (final tableName in const [
      'account_payments',
      'project_device_rates',
      'project_write_offs',
      'account_project_merge_members',
    ]) {
      for (final row in rowsByTable[tableName] ?? const []) {
        final projectKey = (row['project_key'] as String?) ?? '';
        final parsed = ProjectKey.fromKey(projectKey);
        final contact = (row['contact'] as String?)?.trim().isNotEmpty == true
            ? row['contact'] as String
            : parsed.contact;
        final site = (row['site'] as String?)?.trim().isNotEmpty == true
            ? row['site'] as String
            : parsed.site;
        addProject(
          projectId: row['project_id'] as String,
          contact: contact,
          site: site,
          legacyProjectKey: projectKey,
        );
      }
    }

    return projectsById.values.toList(growable: false);
  }

  static String? _validateProjectReferences(
    Map<String, List<Map<String, Object?>>> rowsByTable,
  ) {
    final projectIds = <String>{
      for (final row in rowsByTable['projects'] ?? const [])
        if (row['id'] is String) row['id'] as String,
    };
    // 注意：external_work_records.linked_project_id 不在此处校验。
    // 该字段可空且按业务规则在缺失时改为 "解除关联 + warning"，
    // 走 _detachOrphanExternalWorkLinks 处理，不能在此触发整体失败。
    for (final tableName in const [
      'timing_records',
      'account_payments',
      'project_device_rates',
      'project_write_offs',
      'account_project_merge_members',
    ]) {
      for (final row in rowsByTable[tableName] ?? const []) {
        final projectId = row['project_id'];
        if (projectId is! String || !projectIds.contains(projectId)) {
          return 'orphan_project_id_$tableName';
        }
      }
    }
    return null;
  }

  static String? _legacyProjectIdFromKey(Object? value) {
    final projectKey = value is String ? value : '';
    if (projectKey.trim().isEmpty) return null;
    final parsed = ProjectKey.fromKey(projectKey);
    return Project.legacy(
      contact: parsed.contact,
      site: parsed.site,
      timestamp: BackupRestoreTables.legacyProjectTimestamp,
    ).id;
  }

  static int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static int? _fenFromYuan(Object? value) {
    if (value == null) return null;
    if (value is num) return (value * 100).round();
    return null;
  }

  static bool _isString(Object? value) => value is String;

  static bool _isNonEmptyString(Object? value) =>
      value is String && value.trim().isNotEmpty;

  static bool _isNullableString(Object? value) =>
      value == null || value is String;

  static bool _isInt(Object? value) => value is int;

  static bool _isNullableInt(Object? value) => value == null || value is int;

  static bool _isNonNegativeInt(Object? value) => value is int && value >= 0;

  static bool _isNullableNonNegativeInt(Object? value) =>
      value == null || (value is int && value >= 0);

  static bool _isBooleanInt(Object? value) => value == 0 || value == 1;

  static bool _isNullableBooleanInt(Object? value) =>
      value == null || _isBooleanInt(value);

  static bool _isNumber(Object? value) => value is num;

  static bool _isNullableNumber(Object? value) => value == null || value is num;
}
