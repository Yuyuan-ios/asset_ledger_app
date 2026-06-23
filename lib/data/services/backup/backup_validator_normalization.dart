part of '../local_backup_restore_service.dart';

Map<String, Object?> _normalizeRow(
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
      // Track A / A4-3：旧备份缺单价 fen 时按 legacy REAL 回填；
      // 插入新 schema 前移除已删除的 REAL 单价列。
      normalized['default_unit_price_fen'] ??= _fenFromYuan(
        normalized['default_unit_price'],
      );
      normalized['breaking_unit_price_fen'] ??= _fenFromYuan(
        normalized['breaking_unit_price'],
      );
      normalized.putIfAbsent('lifecycle_initial_cost_fen', () => null);
      normalized.putIfAbsent('lifecycle_estimated_residual_fen', () => null);
      normalized.remove('default_unit_price');
      normalized.remove('breaking_unit_price');
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
      // Track A / A4-7：旧备份缺 income_fen 时按 legacy REAL income
      // 回填；插入新 schema 前移除已删除的 REAL income 列。
      normalized['income_fen'] ??= _fenFromYuan(normalized['income']);
      normalized.remove('income');
      // S2/v33：旧备份缺 unit/quantity_scaled 时按 type/hours 回填镜像；
      // rent 行 quantity 保持 null（租期计量语义未定），已有非 NULL 不覆盖。
      normalized['unit'] ??= normalized['type'] == 'rent' ? 'RENT' : 'HOUR';
      if (normalized['type'] != 'rent') {
        normalized['quantity_scaled'] ??= _quantityScaledFromHours(
          normalized['hours'],
        );
      } else {
        normalized.putIfAbsent('quantity_scaled', () => null);
      }
      break;
    case 'account_payments':
      if (allowLegacyProjectIdentity) {
        normalized['project_id'] ??= _legacyProjectIdFromKey(
          normalized['project_key'],
        );
      }
      normalized['source_type'] ??= 'manual';
      // Track A / A4-6：旧备份缺 fen 时按 legacy REAL 回填；插入新
      // schema 前移除已删除的 REAL 金额列。
      normalized['amount_fen'] ??= _fenFromYuan(normalized['amount']);
      normalized.putIfAbsent('merge_group_id', () => null);
      normalized.putIfAbsent('merge_batch_id', () => null);
      normalized['merge_batch_total_amount_fen'] ??= _fenFromYuan(
        normalized['merge_batch_total_amount'],
      );
      normalized.remove('amount');
      normalized.remove('merge_batch_total_amount');
      normalized.putIfAbsent('merge_batch_note', () => null);
      normalized.putIfAbsent('created_at', () => null);
      break;
    case 'fuel_logs':
      // Track A / A4-1：旧备份缺 cost_fen 时按 legacy REAL cost 回填；
      // 插入新 schema 前移除已删除的 REAL cost 列。
      normalized['cost_fen'] ??= _fenFromYuan(normalized['cost']);
      normalized.remove('cost');
      break;
    case 'maintenance_records':
      // Track A / A4-2：旧备份缺 amount_fen 时按 legacy REAL amount 回填；
      // 插入新 schema 前移除已删除的 REAL amount 列。
      normalized['amount_fen'] ??= _fenFromYuan(normalized['amount']);
      normalized.remove('amount');
      break;
    case 'project_device_rates':
      if (allowLegacyProjectIdentity) {
        normalized['project_id'] ??= _legacyProjectIdFromKey(
          normalized['project_key'],
        );
      }
      normalized['is_breaking'] ??= 0;
      // Track A / A4-4：旧备份缺 rate_fen 时按 legacy REAL rate 回填；
      // 插入新 schema 前移除已删除的 REAL rate 列。
      normalized['rate_fen'] ??= _fenFromYuan(normalized['rate']);
      normalized.remove('rate');
      break;
    case 'project_write_offs':
      // Track A / A4-5：旧备份缺 amount_fen 时按 legacy REAL amount 回填；
      // 插入新 schema 前移除已删除的 REAL amount 列。
      normalized['amount_fen'] ??= _fenFromYuan(normalized['amount']);
      normalized.remove('amount');
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
      normalized.putIfAbsent('customer_unit_price_fen', () => null);
      normalized['project_received_fen'] ??= 0;
      normalized.putIfAbsent('linked_project_id', () => null);
      normalized['record_kind'] ??= 'hours';
      normalized['status'] ??= 'active';
      normalized.putIfAbsent('note', () => null);
      break;
  }
  return normalized;
}

String? _legacyProjectIdFromKey(Object? value) {
  final projectKey = value is String ? value : '';
  if (projectKey.trim().isEmpty) return null;
  final parsed = ProjectKey.fromKey(projectKey);
  return Project.legacy(
    contact: parsed.contact,
    site: parsed.site,
    timestamp: BackupRestoreTables.legacyProjectTimestamp,
  ).id;
}

int? _fenFromYuan(Object? value) {
  if (value == null) return null;
  if (value is num) return (value * 100).round();
  return null;
}

int? _quantityScaledFromHours(Object? hours) {
  if (hours is num) return (hours * 1000).round();
  return null;
}
