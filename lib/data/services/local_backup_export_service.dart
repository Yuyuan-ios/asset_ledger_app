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

  static const int _exportFormatVersion = 1;
  static const String _appName = '机账通';
  static const String _appVersion = 'unknown';
  static const String _backupDirName = 'backups';

  static Future<LocalBackupExportResult> exportJsonBackup() async {
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
      ]);

      final devices = results[0].cast<dynamic>();
      final timingRecords = results[1].cast<dynamic>();
      final fuelLogs = results[2].cast<dynamic>();
      final maintenanceRecords = results[3].cast<dynamic>();
      final accountPayments = results[4].cast<dynamic>();
      final projectDeviceRates = results[5].cast<dynamic>();

      final exportedAt = DateTime.now().toUtc();

      final data = <String, Object?>{
        'devices': devices.map((item) => item.toMap()).toList(growable: false),
        'timing_records': timingRecords
            .map((item) => item.toMap())
            .toList(growable: false),
        'fuel_logs': fuelLogs.map((item) => item.toMap()).toList(growable: false),
        'maintenance_records': maintenanceRecords
            .map((item) => item.toMap())
            .toList(growable: false),
        'account_payments': accountPayments
            .map((item) => item.toMap())
            .toList(growable: false),
        'project_device_rates': projectDeviceRates
            .map((item) => item.toMap())
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
          },
        },
        'data': data,
      };

      final backupDir = await _ensureBackupDirectory();
      final fileName = _buildFileName(exportedAt.toLocal());
      final filePath = p.join(backupDir.path, fileName);
      final file = File(filePath);
      final jsonText = const JsonEncoder.withIndent('  ').convert(payload);

      await file.writeAsString(jsonText);

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

  static Future<Directory> _ensureBackupDirectory() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(documentsDir.path, _backupDirName));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  static String _buildFileName(DateTime dateTime) {
    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');
    return 'asset_ledger_backup_$year$month${day}_$hour$minute$second.json';
  }

  static String _buildExportId(DateTime exportedAt) {
    return 'backup_${exportedAt.microsecondsSinceEpoch}';
  }
}
