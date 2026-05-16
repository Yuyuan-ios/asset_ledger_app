class BackupPreview {
  const BackupPreview({
    required this.isValid,
    this.isCancelled = false,
    this.errorMessage,
    this.warningMessage,
    this.appName,
    this.appVersion,
    this.backupVersion,
    this.schemaVersion,
    this.exportedAt,
    this.deviceCount = 0,
    this.timingRecordCount = 0,
    this.fuelRecordCount = 0,
    this.maintenanceRecordCount = 0,
    this.incomeRecordCount = 0,
    this.projectCount = 0,
    this.accountCount = 0,
    this.tableCounts = const {},
  });

  const BackupPreview.valid({
    this.warningMessage,
    this.appName,
    this.appVersion,
    this.backupVersion,
    this.schemaVersion,
    this.exportedAt,
    this.deviceCount = 0,
    this.timingRecordCount = 0,
    this.fuelRecordCount = 0,
    this.maintenanceRecordCount = 0,
    this.incomeRecordCount = 0,
    this.projectCount = 0,
    this.accountCount = 0,
    this.tableCounts = const {},
  }) : isValid = true,
       isCancelled = false,
       errorMessage = null;

  const BackupPreview.invalid(String message)
    : isValid = false,
      isCancelled = false,
      errorMessage = message,
      warningMessage = null,
      appName = null,
      appVersion = null,
      backupVersion = null,
      schemaVersion = null,
      exportedAt = null,
      deviceCount = 0,
      timingRecordCount = 0,
      fuelRecordCount = 0,
      maintenanceRecordCount = 0,
      incomeRecordCount = 0,
      projectCount = 0,
      accountCount = 0,
      tableCounts = const {};

  const BackupPreview.cancelled()
    : isValid = false,
      isCancelled = true,
      errorMessage = null,
      warningMessage = null,
      appName = null,
      appVersion = null,
      backupVersion = null,
      schemaVersion = null,
      exportedAt = null,
      deviceCount = 0,
      timingRecordCount = 0,
      fuelRecordCount = 0,
      maintenanceRecordCount = 0,
      incomeRecordCount = 0,
      projectCount = 0,
      accountCount = 0,
      tableCounts = const {};

  final bool isValid;
  final bool isCancelled;
  final String? errorMessage;
  final String? warningMessage;
  final String? appName;
  final String? appVersion;
  final String? backupVersion;
  final int? schemaVersion;
  final DateTime? exportedAt;
  final int deviceCount;
  final int timingRecordCount;
  final int fuelRecordCount;
  final int maintenanceRecordCount;
  final int incomeRecordCount;
  final int projectCount;
  final int accountCount;
  final Map<String, int> tableCounts;

  BackupPreview copyWith({DateTime? exportedAt}) {
    return BackupPreview(
      isValid: isValid,
      isCancelled: isCancelled,
      errorMessage: errorMessage,
      warningMessage: warningMessage,
      appName: appName,
      appVersion: appVersion,
      backupVersion: backupVersion,
      schemaVersion: schemaVersion,
      exportedAt: exportedAt ?? this.exportedAt,
      deviceCount: deviceCount,
      timingRecordCount: timingRecordCount,
      fuelRecordCount: fuelRecordCount,
      maintenanceRecordCount: maintenanceRecordCount,
      incomeRecordCount: incomeRecordCount,
      projectCount: projectCount,
      accountCount: accountCount,
      tableCounts: tableCounts,
    );
  }
}

class BackupPreviewLoadResult {
  const BackupPreviewLoadResult({required this.preview, this.decodedJson});

  final BackupPreview preview;
  final Map<String, dynamic>? decodedJson;
}
