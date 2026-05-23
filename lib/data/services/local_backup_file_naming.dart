enum LocalBackupFileKind { manual, preRestore, legacy, unknown }

class LocalBackupFileNaming {
  const LocalBackupFileNaming._();

  static final RegExp _manualPattern = RegExp(
    r'^(?:FleetLedger|机账通)_手动备份_(\d{4})-(\d{2})-(\d{2})_(\d{2})(\d{2})(\d{2})\.json$',
  );
  static final RegExp _preRestorePattern = RegExp(
    r'^(?:FleetLedger|机账通)_恢复前备份_(\d{4})-(\d{2})-(\d{2})_(\d{2})(\d{2})(\d{2})\.json$',
  );
  static final RegExp _legacyPattern = RegExp(
    r'^asset_ledger_backup_(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})\.json$',
  );

  static String buildManualBackupFileName(DateTime time) {
    return 'FleetLedger_手动备份_${_compactDate(time)}_${_compactTime(time)}.json';
  }

  static String buildPreRestoreBackupFileName(DateTime time) {
    return 'FleetLedger_恢复前备份_${_compactDate(time)}_${_compactTime(time)}.json';
  }

  static LocalBackupFileKind detectBackupFileKind(String fileName) {
    if (_manualPattern.hasMatch(fileName)) return LocalBackupFileKind.manual;
    if (_preRestorePattern.hasMatch(fileName)) {
      return LocalBackupFileKind.preRestore;
    }
    if (_legacyPattern.hasMatch(fileName)) return LocalBackupFileKind.legacy;
    return LocalBackupFileKind.unknown;
  }

  static DateTime? parseBackupFileTime(String fileName) {
    final match =
        _manualPattern.firstMatch(fileName) ??
        _preRestorePattern.firstMatch(fileName) ??
        _legacyPattern.firstMatch(fileName);
    if (match == null) return null;

    final year = int.tryParse(match.group(1) ?? '');
    final month = int.tryParse(match.group(2) ?? '');
    final day = int.tryParse(match.group(3) ?? '');
    final hour = int.tryParse(match.group(4) ?? '');
    final minute = int.tryParse(match.group(5) ?? '');
    final second = int.tryParse(match.group(6) ?? '');
    if (year == null ||
        month == null ||
        day == null ||
        hour == null ||
        minute == null ||
        second == null) {
      return null;
    }

    return DateTime(year, month, day, hour, minute, second);
  }

  static String formatBackupTimeForDisplay(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final second = time.second.toString().padLeft(2, '0');
    return '${time.year}年${time.month}月${time.day}日 $hour:$minute:$second';
  }

  static String _compactDate(DateTime time) {
    final year = time.year.toString().padLeft(4, '0');
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static String _compactTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final second = time.second.toString().padLeft(2, '0');
    return '$hour$minute$second';
  }
}
