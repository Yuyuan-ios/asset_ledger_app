import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/measure/measure_unit.dart';
import '../../infrastructure/sync/sync_state_repository.dart';
import '../db/database.dart';
import '../models/account_payment.dart';
import '../models/backup_restore_result.dart';
import '../models/project.dart';
import '../models/project_key.dart';
import '../models/project_write_off.dart';
import '../models/timing_record.dart';
import 'local_backup_export_service.dart';
import 'local_backup_import_preview_service.dart';

part 'backup/backup_tables.dart';
part 'backup/backup_validation_result.dart';
part 'backup/backup_validator.dart';
part 'backup/backup_validator_schema.dart';
part 'backup/backup_validator_rows.dart';
part 'backup/backup_validator_normalization.dart';
part 'backup/backup_validator_aggregation.dart';
part 'backup/local_restore_service.dart';

class LocalBackupRestoreService {
  const LocalBackupRestoreService({
    LocalBackupImportPreviewService previewService =
        const LocalBackupImportPreviewService(),
    Future<LocalBackupExportResult> Function()? exportBackup,
  }) : _previewService = previewService,
       _exportBackup = exportBackup;

  final LocalBackupImportPreviewService _previewService;
  final Future<LocalBackupExportResult> Function()? _exportBackup;

  Future<BackupRestoreResult> restoreFromJsonString(String rawJson) {
    return _restoreService.restoreFromJsonString(rawJson);
  }

  Future<BackupRestoreResult> restoreFromDecodedJson(
    Map<String, dynamic> backupJson,
  ) {
    return _restoreService.restoreFromDecodedJson(backupJson);
  }

  LocalRestoreService get _restoreService {
    return LocalRestoreService(
      previewService: _previewService,
      exportBackup: _exportBackup,
    );
  }
}
