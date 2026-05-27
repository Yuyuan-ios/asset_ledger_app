part of '../local_backup_restore_service.dart';

class BackupRestoreTables {
  const BackupRestoreTables._();

  static const String expectedAppName = 'FleetLedger';
  static const Set<String> legacyAppNames = {'机账通'};
  static const int supportedExportFormatVersion = 2;

  static bool isSupportedAppName(Object? appName) {
    return appName == expectedAppName || legacyAppNames.contains(appName);
  }

  // 清表顺序：外协子表 → 外协批次表 → ... → projects；
  // 关键约束：external_work_records 通过 linked_project_id REFERENCES projects(id) 反向依赖
  // projects；在删 projects 前必须先清空 external_work_records 这条引用，避免被 FK
  // RESTRICT 阻断恢复。
  static const List<String> clearOrder = [
    'external_work_records',
    'external_import_batches',
    'account_project_merge_members',
    'account_project_merge_groups',
    'timing_calculation_history',
    'project_device_rates',
    'project_write_offs',
    'account_payments',
    'maintenance_records',
    'fuel_logs',
    'timing_records',
    'devices',
    'projects',
  ];

  // 插表顺序：父表先于子表；external_work_records 同时依赖 external_import_batches
  // 与 projects（linked_project_id 可空），因此放在两者之后。
  static const List<String> insertOrder = [
    'projects',
    'devices',
    'timing_records',
    'timing_calculation_history',
    'account_project_merge_groups',
    'account_project_merge_members',
    'fuel_logs',
    'maintenance_records',
    'account_payments',
    'project_write_offs',
    'project_device_rates',
    'external_import_batches',
    'external_work_records',
  ];

  static const Map<String, List<String>> requiredColumns = {
    'projects': ['id', 'contact', 'site', 'created_at', 'updated_at'],
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
      'project_id',
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
    'account_payments': ['id', 'project_id', 'project_key', 'ymd', 'amount'],
    'project_write_offs': [
      'id',
      'project_id',
      'amount',
      'reason',
      'write_off_date',
      'created_at',
      'updated_at',
    ],
    'project_device_rates': [
      'project_id',
      'project_key',
      'device_id',
      'is_breaking',
      'rate',
    ],
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
      'project_id',
      'project_key',
      'contact',
      'site',
      'sort_order',
      'created_at',
      'is_active',
    ],
    'external_import_batches': [
      'id',
      'source_share_id',
      'source_display_name',
      'imported_at',
      'created_at',
      'updated_at',
    ],
    'external_work_records': [
      'id',
      'import_batch_id',
      'source_share_id',
      'source_record_uuid',
      'source_installation_uuid',
      'origin_fingerprint',
      'collaborator_name',
      'contact_snapshot',
      'site_snapshot',
      'work_date',
      'hours_milli',
      'amount_fen',
      'created_at',
      'updated_at',
    ],
  };

  static const Set<String> optionalTables = {
    'timing_calculation_history',
    'account_project_merge_groups',
    'account_project_merge_members',
    'project_write_offs',
    'external_import_batches',
    'external_work_records',
  };

  static final String legacyProjectTimestamp = DateTime(
    1970,
  ).toUtc().toIso8601String();
}
