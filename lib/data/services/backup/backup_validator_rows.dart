part of '../local_backup_restore_service.dart';

String? _firstMissingColumn(String tableName, Map<String, Object?> row) {
  final requiredColumns =
      BackupRestoreTables.requiredColumns[tableName] ?? const <String>[];
  for (final column in requiredColumns) {
    if (!row.containsKey(column)) return column;
  }
  return null;
}

String? _validateColumnTypes(String tableName, Map<String, Object?> row) {
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

String? _validateExternalImportBatchRow(Map<String, Object?> row) {
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

String? _validateExternalWorkRecordRow(Map<String, Object?> row) {
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

String? _validateDevicesRow(Map<String, Object?> row) {
  if (!_isNullableInt(row['id'])) return 'invalid_devices_id';
  if (!_isString(row['name'])) return 'invalid_devices_name';
  if (!_isString(row['brand'])) return 'invalid_devices_brand';
  if (!_isNullableString(row['model'])) return 'invalid_devices_model';
  if (!_isInt(row['default_unit_price_fen'])) {
    return 'invalid_devices_default_unit_price_fen';
  }
  if (!_isNullableInt(row['breaking_unit_price_fen'])) {
    return 'invalid_devices_breaking_unit_price_fen';
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
  if (!_isNullableInt(row['lifecycle_initial_cost_fen'])) {
    return 'invalid_devices_lifecycle_initial_cost_fen';
  }
  if (!_isNullableInt(row['lifecycle_estimated_residual_fen'])) {
    return 'invalid_devices_lifecycle_estimated_residual_fen';
  }
  return null;
}

String? _validateProjectRow(Map<String, Object?> row) {
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

String? _validateTimingRow(Map<String, Object?> row) {
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
  if (!_isNonNegativeInt(row['income_fen'])) {
    return 'invalid_timing_records_income_fen';
  }
  final unit = row['unit'];
  if (unit != null &&
      (unit is! String || MeasureUnitCodec.tryFromDbValue(unit) == null)) {
    return 'invalid_timing_records_unit';
  }
  if (!_isNullableInt(row['quantity_scaled'])) {
    return 'invalid_timing_records_quantity_scaled';
  }
  if (!_isNullableInt(row['allocation_cutoff_date'])) {
    return 'invalid_timing_records_allocation_cutoff_date';
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

String? _validateFuelRow(Map<String, Object?> row) {
  if (!_isNullableInt(row['id'])) return 'invalid_fuel_logs_id';
  if (!_isInt(row['device_id'])) return 'invalid_fuel_logs_device_id';
  if (!_isInt(row['date'])) return 'invalid_fuel_logs_date';
  if (!_isNullableString(row['supplier'])) {
    return 'invalid_fuel_logs_supplier';
  }
  if (!_isNumber(row['liters'])) return 'invalid_fuel_logs_liters';
  if (!_isInt(row['cost_fen'])) return 'invalid_fuel_logs_cost_fen';
  return null;
}

String? _validateMaintenanceRow(Map<String, Object?> row) {
  if (!_isNullableInt(row['id'])) return 'invalid_maintenance_records_id';
  if (!_isNullableInt(row['device_id'])) {
    return 'invalid_maintenance_records_device_id';
  }
  if (!_isInt(row['ymd'])) return 'invalid_maintenance_records_ymd';
  if (!_isString(row['item'])) return 'invalid_maintenance_records_item';
  if (!_isInt(row['amount_fen'])) {
    return 'invalid_maintenance_records_amount_fen';
  }
  if (!_isNullableString(row['note'])) {
    return 'invalid_maintenance_records_note';
  }
  return null;
}

String? _validateAccountPaymentRow(Map<String, Object?> row) {
  if (!_isNullableInt(row['id'])) return 'invalid_account_payments_id';
  if (!_isNonEmptyString(row['project_id'])) {
    return 'invalid_account_payments_project_id';
  }
  if (!_isString(row['project_key'])) {
    return 'invalid_account_payments_project_key';
  }
  if (!_isInt(row['ymd'])) return 'invalid_account_payments_ymd';
  if (!_isNonNegativeInt(row['amount_fen'])) {
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
  if (!_isNullableNonNegativeInt(row['merge_batch_total_amount_fen'])) {
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

String? _validateProjectDeviceRateRow(Map<String, Object?> row) {
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
  if (!_isInt(row['rate_fen'])) {
    return 'invalid_project_device_rates_rate_fen';
  }
  return null;
}

String? _validateProjectWriteOffRow(Map<String, Object?> row) {
  if (!_isNonEmptyString(row['id'])) return 'invalid_project_write_offs_id';
  if (!_isNonEmptyString(row['project_id'])) {
    return 'invalid_project_write_offs_project_id';
  }
  if (!_isNonNegativeInt(row['amount_fen'])) {
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

String? _validateTimingCalculationHistoryRow(Map<String, Object?> row) {
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

String? _validateAccountProjectMergeGroupRow(Map<String, Object?> row) {
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

String? _validateAccountProjectMergeMemberRow(Map<String, Object?> row) {
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

bool _isString(Object? value) => value is String;

bool _isNonEmptyString(Object? value) =>
    value is String && value.trim().isNotEmpty;

bool _isNullableString(Object? value) => value == null || value is String;

bool _isInt(Object? value) => value is int;

bool _isNullableInt(Object? value) => value == null || value is int;

bool _isNonNegativeInt(Object? value) => value is int && value >= 0;

bool _isNullableNonNegativeInt(Object? value) =>
    value == null || (value is int && value >= 0);

bool _isBooleanInt(Object? value) => value == 0 || value == 1;

bool _isNullableBooleanInt(Object? value) =>
    value == null || _isBooleanInt(value);

bool _isNumber(Object? value) => value is num;
