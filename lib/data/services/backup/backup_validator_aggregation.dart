part of '../local_backup_restore_service.dart';

const String _externalWorkRecordsTable = 'external_work_records';
const String _externalImportBatchesTable = 'external_import_batches';

List<BackupRestoreWarning> _detachOrphanExternalWorkLinks(
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

List<Map<String, Object?>> _deriveLegacyProjectRows(
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

String? _validateProjectReferences(
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
