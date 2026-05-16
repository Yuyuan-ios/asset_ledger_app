import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../db/database.dart';
import '../repositories/account_payment_repository.dart';
import '../repositories/device_repository.dart';
import '../repositories/fuel_repository.dart';
import '../repositories/maintenance_repository.dart';
import '../repositories/project_rate_repository.dart';
import '../repositories/timing_repository.dart';
import 'local_backup_file_naming.dart';

enum LocalBackupExportKind { manual, preRestore }

class LocalBackupExportResult {
  const LocalBackupExportResult({
    required this.success,
    this.filePath,
    this.fileName,
    this.errorMessage,
  });

  final bool success;
  final String? filePath;
  final String? fileName;
  final String? errorMessage;
}

class LocalBackupExportService {
  const LocalBackupExportService._();

  static const String _calculationHistoryTable = 'timing_calculation_history';
  static const String _mergeGroupsTable = 'account_project_merge_groups';
  static const String _mergeMembersTable = 'account_project_merge_members';
  static const int _exportFormatVersion = 1;
  static const String _appName = '机账通';
  static const String _appVersion = 'unknown';
  static const String _backupDirName = 'backups';
  static const int _maxPreRestoreBackups = 3;

  static Future<LocalBackupExportResult> exportJsonBackup({
    LocalBackupExportKind kind = LocalBackupExportKind.manual,
  }) async {
    try {
      final deviceRepository = SqfliteDeviceRepository();
      final timingRepository = SqfliteTimingRepository();
      final fuelRepository = SqfliteFuelRepository();
      final maintenanceRepository = SqfliteMaintenanceRepository();
      final accountPaymentRepository = SqfliteAccountPaymentRepository();
      final projectRateRepository = SqfliteProjectRateRepository();

      final results = await Future.wait([
        deviceRepository.listAll(),
        timingRepository.listAll(),
        fuelRepository.listAll(),
        maintenanceRepository.listAll(),
        accountPaymentRepository.listAll(),
        projectRateRepository.listAll(),
        _listTimingCalculationHistoryRows(),
        _listMergeGroupRows(),
        _listMergeMemberRows(),
      ]);

      final devices = results[0].cast<dynamic>();
      final timingRecords = results[1].cast<dynamic>();
      final fuelLogs = results[2].cast<dynamic>();
      final maintenanceRecords = results[3].cast<dynamic>();
      final accountPayments = results[4].cast<dynamic>();
      final projectDeviceRates = results[5].cast<dynamic>();
      final timingCalculationHistoryRows = results[6]
          .cast<Map<String, Object?>>();
      final mergeGroupRows = results[7].cast<Map<String, Object?>>();
      final mergeMemberRows = results[8].cast<Map<String, Object?>>();

      final exportedAt = DateTime.now().toUtc();

      final data = <String, Object?>{
        'devices': devices.map((item) => item.toMap()).toList(growable: false),
        'timing_records': timingRecords
            .map((item) => item.toMap())
            .toList(growable: false),
        'fuel_logs': fuelLogs
            .map((item) => item.toMap())
            .toList(growable: false),
        'maintenance_records': maintenanceRecords
            .map((item) => item.toMap())
            .toList(growable: false),
        'account_payments': accountPayments
            .map((item) => item.toMap())
            .toList(growable: false),
        'project_device_rates': projectDeviceRates
            .map((item) => item.toMap())
            .toList(growable: false),
        _calculationHistoryTable: timingCalculationHistoryRows
            .map((row) => Map<String, Object?>.from(row))
            .toList(growable: false),
        _mergeGroupsTable: mergeGroupRows
            .map((row) => Map<String, Object?>.from(row))
            .toList(growable: false),
        _mergeMembersTable: mergeMemberRows
            .map((row) => Map<String, Object?>.from(row))
            .toList(growable: false),
      };

      final payload = <String, Object?>{
        'meta': <String, Object?>{
          'export_format_version': _exportFormatVersion,
          'schema_version': AppDatabase.schemaVersion,
          'exported_at': exportedAt.toIso8601String(),
          'platform': Platform.operatingSystem,
          'app_version': _appVersion,
          'app_name': _appName,
          'note': 'This backup contains business data only.',
          'warnings': const [
            'custom_avatar_path values are exported as paths only; avatar files are not included.',
          ],
          'export_id': _buildExportId(exportedAt),
        },
        'summary': <String, Object?>{
          'table_counts': <String, int>{
            'devices': devices.length,
            'timing_records': timingRecords.length,
            'fuel_logs': fuelLogs.length,
            'maintenance_records': maintenanceRecords.length,
            'account_payments': accountPayments.length,
            'project_device_rates': projectDeviceRates.length,
            _calculationHistoryTable: timingCalculationHistoryRows.length,
            _mergeGroupsTable: mergeGroupRows.length,
            _mergeMembersTable: mergeMemberRows.length,
          },
        },
        'data': data,
      };

      final backupDir = await _ensureBackupDirectory();
      final fileName = _buildFileName(exportedAt.toLocal(), kind: kind);
      final filePath = p.join(backupDir.path, fileName);
      final file = File(filePath);
      final jsonText = const JsonEncoder.withIndent('  ').convert(payload);

      await file.writeAsString(jsonText);
      if (kind == LocalBackupExportKind.preRestore) {
        await _cleanupOldPreRestoreBackups(backupDir);
      }

      return LocalBackupExportResult(
        success: true,
        filePath: filePath,
        fileName: fileName,
      );
    } catch (error) {
      return LocalBackupExportResult(
        success: false,
        errorMessage: error.toString(),
      );
    }
  }

  static Future<LocalBackupExportResult> exportPreRestoreJsonBackup() {
    return exportJsonBackup(kind: LocalBackupExportKind.preRestore);
  }

  static Future<List<Map<String, Object?>>>
  _listTimingCalculationHistoryRows() async {
    final db = await AppDatabase.database;
    return db.query(_calculationHistoryTable, orderBy: 'created_at DESC');
  }

  static Future<List<Map<String, Object?>>> _listMergeGroupRows() async {
    final db = await AppDatabase.database;
    return db.query(_mergeGroupsTable, orderBy: 'created_at ASC, id ASC');
  }

  static Future<List<Map<String, Object?>>> _listMergeMemberRows() async {
    final db = await AppDatabase.database;
    return db.query(
      _mergeMembersTable,
      orderBy: 'group_id ASC, sort_order ASC, id ASC',
    );
  }

  static Future<Directory> _ensureBackupDirectory() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(documentsDir.path, _backupDirName));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  static String _buildFileName(
    DateTime dateTime, {
    required LocalBackupExportKind kind,
  }) {
    switch (kind) {
      case LocalBackupExportKind.manual:
        return LocalBackupFileNaming.buildManualBackupFileName(dateTime);
      case LocalBackupExportKind.preRestore:
        return LocalBackupFileNaming.buildPreRestoreBackupFileName(dateTime);
    }
  }

  static Future<void> _cleanupOldPreRestoreBackups(Directory backupDir) async {
    try {
      final preRestoreFiles = <({File file, DateTime time})>[];
      await for (final entity in backupDir.list(followLinks: false)) {
        if (entity is! File) continue;
        final fileName = p.basename(entity.path);
        if (LocalBackupFileNaming.detectBackupFileKind(fileName) !=
            LocalBackupFileKind.preRestore) {
          continue;
        }
        final time = LocalBackupFileNaming.parseBackupFileTime(fileName);
        if (time == null) continue;
        preRestoreFiles.add((file: entity, time: time));
      }

      preRestoreFiles.sort((a, b) => b.time.compareTo(a.time));
      for (final oldBackup in preRestoreFiles.skip(_maxPreRestoreBackups)) {
        try {
          await oldBackup.file.delete();
        } catch (_) {
          // Cleanup is best-effort; a failed delete must not block restore.
        }
      }
    } catch (_) {
      // Cleanup is best-effort; a failed directory scan must not block restore.
    }
  }

  static String _buildExportId(DateTime exportedAt) {
    return 'backup_${exportedAt.microsecondsSinceEpoch}';
  }
}
