enum BackupRestoreWarningCode {
  /// 外协记录的 linked_project_id 在恢复包项目表中找不到，已保留外协但解除关联。
  externalWorkLinkedProjectMissing,
}

class BackupRestoreWarning {
  const BackupRestoreWarning({
    required this.code,
    required this.message,
    this.context = const {},
  });

  final BackupRestoreWarningCode code;
  final String message;
  final Map<String, Object?> context;
}

class BackupRestoreResult {
  const BackupRestoreResult._({
    required this.success,
    required this.message,
    this.errorCode,
    this.autoBackupPath,
    this.restoredCounts = const {},
    this.warnings = const [],
  });

  factory BackupRestoreResult.success({
    required String autoBackupPath,
    required Map<String, int> restoredCounts,
    List<BackupRestoreWarning> warnings = const [],
  }) {
    return BackupRestoreResult._(
      success: true,
      message: '恢复完成',
      autoBackupPath: autoBackupPath,
      restoredCounts: Map.unmodifiable(restoredCounts),
      warnings: List.unmodifiable(warnings),
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
  final List<BackupRestoreWarning> warnings;
}
