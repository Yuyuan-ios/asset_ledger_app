import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../db/database.dart';
import '../models/backup_preview.dart';
import 'local_backup_file_naming.dart';

class LocalBackupFile {
  const LocalBackupFile({
    required this.name,
    required this.path,
    required this.size,
    required this.modifiedAt,
    required this.kind,
    this.backupTime,
  });

  final String name;
  final String path;
  final int size;
  final DateTime modifiedAt;
  final LocalBackupFileKind kind;
  final DateTime? backupTime;
}

class LocalBackupImportPreviewService {
  const LocalBackupImportPreviewService();

  static const int _maxPreviewFileBytes = 20 * 1024 * 1024;
  static const String _expectedAppName = '机账通';
  static const String _backupDirName = 'backups';

  static const List<String> _requiredTables = [
    'devices',
    'timing_records',
    'fuel_logs',
    'maintenance_records',
    'account_payments',
    'project_device_rates',
  ];

  static const List<String> _optionalTables = [
    'timing_calculation_history',
    'account_project_merge_groups',
    'account_project_merge_members',
  ];

  Future<BackupPreview> pickAndPreviewBackup() async {
    final result = await pickAndPreviewBackupWithJson();
    return result.preview;
  }

  Future<List<LocalBackupFile>> listLocalBackups() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(documentsDir.path, _backupDirName));
    if (!await backupDir.exists()) return const [];

    final backups = <LocalBackupFile>[];
    await for (final entity in backupDir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!name.toLowerCase().endsWith('.json')) continue;
      final kind = LocalBackupFileNaming.detectBackupFileKind(name);
      if (kind == LocalBackupFileKind.unknown) continue;

      try {
        final stat = await entity.stat();
        final backupTime = LocalBackupFileNaming.parseBackupFileTime(name);
        backups.add(
          LocalBackupFile(
            name: name,
            path: entity.path,
            size: stat.size,
            modifiedAt: stat.modified,
            kind: kind,
            backupTime: backupTime,
          ),
        );
      } catch (_) {
        // Skip unreadable entries; the preview step will surface read errors.
      }
    }

    backups.sort((a, b) {
      final aTime = a.backupTime ?? a.modifiedAt;
      final bTime = b.backupTime ?? b.modifiedAt;
      return bTime.compareTo(aTime);
    });
    return backups;
  }

  Future<BackupPreviewLoadResult> previewLocalBackupFile(
    LocalBackupFile backup,
  ) async {
    try {
      if (backup.size > _maxPreviewFileBytes) {
        return const BackupPreviewLoadResult(
          preview: BackupPreview.invalid('备份文件过大，当前版本暂不支持预览'),
        );
      }

      final rawJson = await File(backup.path).readAsString();
      final result = previewLoadResultFromJsonString(rawJson);
      final fallbackTime = backup.backupTime;
      if (fallbackTime == null || result.preview.exportedAt != null) {
        return result;
      }
      return BackupPreviewLoadResult(
        preview: result.preview.copyWith(exportedAt: fallbackTime),
        decodedJson: result.decodedJson,
      );
    } catch (_) {
      return const BackupPreviewLoadResult(
        preview: BackupPreview.invalid('无法读取该文件，请重新选择'),
      );
    }
  }

  Future<BackupPreviewLoadResult> pickAndPreviewBackupWithJson() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return const BackupPreviewLoadResult(
          preview: BackupPreview.cancelled(),
        );
      }

      final selectedFile = result.files.single;
      if (!selectedFile.name.toLowerCase().endsWith('.json')) {
        return const BackupPreviewLoadResult(
          preview: BackupPreview.invalid('请选择 JSON 格式的机账通备份文件'),
        );
      }

      final length = selectedFile.size;
      if (length > _maxPreviewFileBytes) {
        return const BackupPreviewLoadResult(
          preview: BackupPreview.invalid('备份文件过大，当前版本暂不支持预览'),
        );
      }

      final bytes = selectedFile.bytes;
      final rawJson = bytes == null
          ? await _readJsonFromPath(selectedFile.path)
          : utf8.decode(bytes);
      return previewLoadResultFromJsonString(rawJson);
    } catch (_) {
      return const BackupPreviewLoadResult(
        preview: BackupPreview.invalid('无法读取该文件，请重新选择'),
      );
    }
  }

  Future<String> _readJsonFromPath(String? path) async {
    if (path == null || path.trim().isEmpty) {
      throw const FileSystemException('Selected file path is unavailable.');
    }
    return File(path).readAsString();
  }

  BackupPreview previewFromJsonString(String rawJson) {
    return previewLoadResultFromJsonString(rawJson).preview;
  }

  BackupPreviewLoadResult previewLoadResultFromJsonString(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) {
        return const BackupPreviewLoadResult(
          preview: BackupPreview.invalid('这不是有效的机账通备份文件'),
        );
      }
      return BackupPreviewLoadResult(
        preview: previewFromDecodedJson(decoded),
        decodedJson: decoded,
      );
    } on FormatException {
      return const BackupPreviewLoadResult(
        preview: BackupPreview.invalid('备份文件不是有效的 JSON，请重新选择'),
      );
    } catch (_) {
      return const BackupPreviewLoadResult(
        preview: BackupPreview.invalid('这不是有效的机账通备份文件'),
      );
    }
  }

  BackupPreview previewFromDecodedJson(Map<String, dynamic> json) {
    final meta = json['meta'];
    final data = json['data'];

    if (meta is! Map<String, dynamic> || data is! Map<String, dynamic>) {
      return const BackupPreview.invalid('备份文件格式不完整');
    }

    final appName = meta['app_name'] as String?;
    if (appName != _expectedAppName) {
      return const BackupPreview.invalid('这不是有效的机账通备份文件');
    }

    final schemaVersion = _readInt(meta['schema_version']);
    if (schemaVersion == null) {
      return const BackupPreview.invalid('备份文件格式不完整：缺少数据库版本');
    }

    if (schemaVersion > AppDatabase.schemaVersion) {
      return const BackupPreview.invalid('备份文件版本较新，请升级 App 后再试');
    }

    final exportFormatVersion = _readInt(meta['export_format_version']);
    if (exportFormatVersion == null) {
      return const BackupPreview.invalid('备份文件格式不完整：缺少备份版本');
    }

    final tableCounts = <String, int>{};
    for (final tableName in _requiredTables) {
      final rows = data[tableName];
      if (rows == null) {
        return const BackupPreview.invalid('备份文件格式不完整：缺少业务数据');
      }
      if (rows is! List) {
        return const BackupPreview.invalid('备份数据结构异常');
      }
      tableCounts[tableName] = rows.length;
    }

    for (final tableName in _optionalTables) {
      final rows = data[tableName];
      if (rows == null) {
        tableCounts[tableName] = 0;
        continue;
      }
      if (rows is! List) {
        return const BackupPreview.invalid('备份数据结构异常');
      }
      tableCounts[tableName] = rows.length;
    }

    final timingRecords = data['timing_records'] as List;
    final accountPayments = data['account_payments'] as List;
    final projectDeviceRates = data['project_device_rates'] as List;
    final exportedAt = _readDateTime(meta['exported_at']);
    final projectKeys = <String>{};
    final accountNames = <String>{};

    for (final row in timingRecords.whereType<Map<String, dynamic>>()) {
      final contact = (row['contact'] as String?)?.trim() ?? '';
      final site = (row['site'] as String?)?.trim() ?? '';
      if (contact.isNotEmpty) accountNames.add(contact);
      if (contact.isNotEmpty || site.isNotEmpty) {
        projectKeys.add('$contact||$site');
      }
    }

    for (final row in accountPayments.whereType<Map<String, dynamic>>()) {
      _addProjectKey(row['project_key'], projectKeys, accountNames);
    }

    for (final row in projectDeviceRates.whereType<Map<String, dynamic>>()) {
      _addProjectKey(row['project_key'], projectKeys, accountNames);
    }

    final mergeMembers = data['account_project_merge_members'];
    if (mergeMembers is List) {
      for (final row in mergeMembers.whereType<Map<String, dynamic>>()) {
        _addProjectKey(row['project_key'], projectKeys, accountNames);
      }
    }

    final warningMessage = schemaVersion < AppDatabase.schemaVersion
        ? '备份版本较旧，恢复前可能需要兼容处理。'
        : null;

    return BackupPreview.valid(
      warningMessage: warningMessage,
      appName: appName,
      appVersion: meta['app_version'] as String?,
      backupVersion: exportFormatVersion.toString(),
      schemaVersion: schemaVersion,
      exportedAt: exportedAt,
      deviceCount: tableCounts['devices'] ?? 0,
      timingRecordCount: tableCounts['timing_records'] ?? 0,
      fuelRecordCount: tableCounts['fuel_logs'] ?? 0,
      maintenanceRecordCount: tableCounts['maintenance_records'] ?? 0,
      incomeRecordCount: tableCounts['account_payments'] ?? 0,
      projectCount: projectKeys.length,
      accountCount: accountNames.length,
      tableCounts: tableCounts,
    );
  }

  static int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static DateTime? _readDateTime(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }

  static void _addProjectKey(
    Object? value,
    Set<String> projectKeys,
    Set<String> accountNames,
  ) {
    final projectKey = (value as String?)?.trim() ?? '';
    if (projectKey.isEmpty) return;

    projectKeys.add(projectKey);
    final separatorIndex = projectKey.indexOf('||');
    final contact = separatorIndex >= 0
        ? projectKey.substring(0, separatorIndex).trim()
        : projectKey;
    if (contact.isNotEmpty) accountNames.add(contact);
  }
}
