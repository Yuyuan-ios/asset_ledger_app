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
      // v35：旧备份缺单价 fen 镜像时按 REAL 回填；breaking 为 null 保持 null。
      normalized['default_unit_price_fen'] ??= _fenFromYuan(
        normalized['default_unit_price'],
      );
      normalized['breaking_unit_price_fen'] ??= _fenFromYuan(
        normalized['breaking_unit_price'],
      );
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
      // v35：旧备份缺 rate_fen 时按 REAL rate 回填。
      normalized['rate_fen'] ??= _fenFromYuan(normalized['rate']);
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
