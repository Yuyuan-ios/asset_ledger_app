import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../db/database.dart';
import '../models/backup_restore_result.dart';
import 'local_backup_export_service.dart';
import 'local_backup_import_preview_service.dart';

class LocalBackupRestoreService {
  const LocalBackupRestoreService({
    LocalBackupImportPreviewService previewService =
        const LocalBackupImportPreviewService(),
    Future<LocalBackupExportResult> Function()? exportBackup,
  }) : _previewService = previewService,
       _exportBackup = exportBackup;

  static const String _expectedAppName = '机账通';
  static const int _supportedExportFormatVersion = 1;

  static const List<String> _clearOrder = [
    'account_project_merge_members',
    'account_project_merge_groups',
    'timing_calculation_history',
    'project_device_rates',
    'account_payments',
    'maintenance_records',
    'fuel_logs',
    'timing_records',
    'devices',
  ];

  static const List<String> _insertOrder = [
    'devices',
    'timing_records',
    'timing_calculation_history',
    'account_project_merge_groups',
    'account_project_merge_members',
    'fuel_logs',
    'maintenance_records',
    'account_payments',
    'project_device_rates',
  ];

  static const Map<String, List<String>> _requiredColumns = {
    'devices': [
      'id',
      'name',
      'brand',
      'default_unit_price',
      'base_meter_hours',
      'is_active',
      'equipment_type',
    ],
    'timing_records': [
      'id',
      'device_id',
      'start_date',
      'type',
      'start_meter',
      'end_meter',
      'hours',
      'income',
    ],
    'fuel_logs': ['id', 'device_id', 'date', 'liters', 'cost'],
    'maintenance_records': ['id', 'device_id', 'ymd', 'item', 'amount'],
    'account_payments': ['id', 'project_key', 'ymd', 'amount'],
    'project_device_rates': ['project_key', 'device_id', 'is_breaking', 'rate'],
    'timing_calculation_history': [
      'id',
      'timing_record_id',
      'created_at',
      'expression',
      'result',
      'ticket_count',
    ],
    'account_project_merge_groups': [
      'id',
      'contact',
      'created_at',
      'is_active',
      'source_type',
    ],
    'account_project_merge_members': [
      'id',
      'group_id',
      'project_key',
      'contact',
      'site',
      'sort_order',
      'created_at',
      'is_active',
    ],
  };

  static const Set<String> _optionalTables = {
    'timing_calculation_history',
    'account_project_merge_groups',
    'account_project_merge_members',
  };

  final LocalBackupImportPreviewService _previewService;
  final Future<LocalBackupExportResult> Function()? _exportBackup;

  Future<BackupRestoreResult> restoreFromJsonString(String rawJson) async {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) {
        return BackupRestoreResult.failure(
          message: '这不是有效的机账通备份文件',
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
        message: '这不是有效的机账通备份文件',
        errorCode: 'invalid_json',
      );
    }
  }

  Future<BackupRestoreResult> restoreFromDecodedJson(
    Map<String, dynamic> backupJson,
  ) async {
    final validation = _validateBackupJson(backupJson);
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

        for (final tableName in _clearOrder) {
          batch.delete(tableName);
        }

        for (final tableName in _insertOrder) {
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

  _RestoreValidation _validateBackupJson(Map<String, dynamic> backupJson) {
    final preview = _previewService.previewFromDecodedJson(backupJson);
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

    if (meta['app_name'] != _expectedAppName) {
      return _RestoreValidation.failure(
        BackupRestoreResult.failure(
          message: '这不是有效的机账通备份文件',
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

    if (exportFormatVersion != _supportedExportFormatVersion) {
      return _RestoreValidation.failure(
        BackupRestoreResult.failure(
          message: '当前版本暂不支持该备份格式',
          errorCode: 'unsupported_export_format_version',
        ),
      );
    }

    final rowsByTable = <String, List<Map<String, Object?>>>{};
    final restoredCounts = <String, int>{};

    for (final tableName in _insertOrder) {
      final rows = data[tableName];
      if (rows == null) {
        if (_optionalTables.contains(tableName)) {
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

        final normalizedRow = _normalizeRow(tableName, row);
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

    return _RestoreValidation.success(
      rowsByTable: rowsByTable,
      restoredCounts: restoredCounts,
    );
  }

  static Map<String, Object?> _normalizeRow(String tableName, Map row) {
    final normalized = <String, Object?>{};
    for (final entry in row.entries) {
      final key = entry.key;
      if (key is String) {
        normalized[key] = entry.value;
      }
    }
    if (tableName == 'account_payments') {
      normalized['source_type'] ??= 'manual';
      normalized.putIfAbsent('merge_group_id', () => null);
      normalized.putIfAbsent('merge_batch_id', () => null);
      normalized.putIfAbsent('merge_batch_total_amount', () => null);
      normalized.putIfAbsent('merge_batch_note', () => null);
      normalized.putIfAbsent('created_at', () => null);
    }
    return normalized;
  }

  static String? _firstMissingColumn(
    String tableName,
    Map<String, Object?> row,
  ) {
    final requiredColumns = _requiredColumns[tableName] ?? const <String>[];
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
      case 'timing_records':
        return _validateTimingRow(row);
      case 'fuel_logs':
        return _validateFuelRow(row);
      case 'maintenance_records':
        return _validateMaintenanceRow(row);
      case 'account_payments':
        return _validateAccountPaymentRow(row);
      case 'project_device_rates':
        return _validateProjectDeviceRateRow(row);
      case 'timing_calculation_history':
        return _validateTimingCalculationHistoryRow(row);
      case 'account_project_merge_groups':
        return _validateAccountProjectMergeGroupRow(row);
      case 'account_project_merge_members':
        return _validateAccountProjectMergeMemberRow(row);
      default:
        return 'unknown_table_$tableName';
    }
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
    if (!_isInt(row['is_active'])) return 'invalid_devices_is_active';
    if (!_isNullableString(row['custom_avatar_path'])) {
      return 'invalid_devices_custom_avatar_path';
    }
    if (!_isString(row['equipment_type'])) {
      return 'invalid_devices_equipment_type';
    }
    return null;
  }

  static String? _validateTimingRow(Map<String, Object?> row) {
    if (!_isNullableInt(row['id'])) return 'invalid_timing_records_id';
    if (!_isInt(row['device_id'])) return 'invalid_timing_records_device_id';
    if (!_isInt(row['start_date'])) {
      return 'invalid_timing_records_start_date';
    }
    if (!_isNullableString(row['contact'])) {
      return 'invalid_timing_records_contact';
    }
    if (!_isNullableString(row['site'])) return 'invalid_timing_records_site';
    if (!_isString(row['type'])) return 'invalid_timing_records_type';
    if (!_isNumber(row['start_meter'])) {
      return 'invalid_timing_records_start_meter';
    }
    if (!_isNumber(row['end_meter'])) return 'invalid_timing_records_end_meter';
    if (!_isNumber(row['hours'])) return 'invalid_timing_records_hours';
    if (!_isNumber(row['income'])) return 'invalid_timing_records_income';
    if (!_isNullableInt(row['exclude_from_fuel_eff'])) {
      return 'invalid_timing_records_exclude_from_fuel_eff';
    }
    if (!_isNullableInt(row['is_breaking'])) {
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
    if (!_isString(row['project_key'])) {
      return 'invalid_account_payments_project_key';
    }
    if (!_isInt(row['ymd'])) return 'invalid_account_payments_ymd';
    if (!_isNumber(row['amount'])) return 'invalid_account_payments_amount';
    if (!_isNullableString(row['note'])) return 'invalid_account_payments_note';
    if (!_isString(row['source_type'])) {
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
    if (!_isNullableString(row['merge_batch_note'])) {
      return 'invalid_account_payments_merge_batch_note';
    }
    if (!_isNullableString(row['created_at'])) {
      return 'invalid_account_payments_created_at';
    }
    return null;
  }

  static String? _validateProjectDeviceRateRow(Map<String, Object?> row) {
    if (!_isString(row['project_key'])) {
      return 'invalid_project_device_rates_project_key';
    }
    if (!_isInt(row['device_id'])) {
      return 'invalid_project_device_rates_device_id';
    }
    if (!_isInt(row['is_breaking'])) {
      return 'invalid_project_device_rates_is_breaking';
    }
    if (!_isNumber(row['rate'])) return 'invalid_project_device_rates_rate';
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
    if (!_isInt(row['is_active'])) {
      return 'invalid_account_project_merge_groups_is_active';
    }
    if (!_isNullableString(row['dissolved_at'])) {
      return 'invalid_account_project_merge_groups_dissolved_at';
    }
    if (!_isString(row['source_type'])) {
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
    if (!_isInt(row['is_active'])) {
      return 'invalid_account_project_merge_members_is_active';
    }
    return null;
  }

  static int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static bool _isString(Object? value) => value is String;

  static bool _isNullableString(Object? value) =>
      value == null || value is String;

  static bool _isInt(Object? value) => value is int;

  static bool _isNullableInt(Object? value) => value == null || value is int;

  static bool _isNumber(Object? value) => value is num;

  static bool _isNullableNumber(Object? value) => value == null || value is num;
}

class _RestoreValidation {
  const _RestoreValidation._({
    required this.success,
    this.failure,
    this.rowsByTable = const {},
    this.restoredCounts = const {},
  });

  factory _RestoreValidation.success({
    required Map<String, List<Map<String, Object?>>> rowsByTable,
    required Map<String, int> restoredCounts,
  }) {
    return _RestoreValidation._(
      success: true,
      rowsByTable: rowsByTable,
      restoredCounts: restoredCounts,
    );
  }

  factory _RestoreValidation.failure(BackupRestoreResult result) {
    return _RestoreValidation._(success: false, failure: result);
  }

  final bool success;
  final BackupRestoreResult? failure;
  final Map<String, List<Map<String, Object?>>> rowsByTable;
  final Map<String, int> restoredCounts;
}
