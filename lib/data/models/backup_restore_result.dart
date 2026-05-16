class BackupRestoreResult {
  const BackupRestoreResult._({
    required this.success,
    required this.message,
    this.errorCode,
    this.autoBackupPath,
    this.restoredCounts = const {},
  });

  factory BackupRestoreResult.success({
    required String autoBackupPath,
    required Map<String, int> restoredCounts,
  }) {
    return BackupRestoreResult._(
      success: true,
      message: '恢复完成',
      autoBackupPath: autoBackupPath,
      restoredCounts: Map.unmodifiable(restoredCounts),
    );
  }

  factory BackupRestoreResult.failure({
    required String message,
    String? errorCode,
    String? autoBackupPath,
  }) {
    return BackupRestoreResult._(
      success: false,
      message: message,
      errorCode: errorCode,
      autoBackupPath: autoBackupPath,
    );
  }

  final bool success;
  final String message;
  final String? errorCode;
  final String? autoBackupPath;
  final Map<String, int> restoredCounts;
}
