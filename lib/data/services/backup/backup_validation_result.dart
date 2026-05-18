part of '../local_backup_restore_service.dart';

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
