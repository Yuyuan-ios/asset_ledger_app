part of '../local_backup_restore_service.dart';

class _BackupEnvelope {
  const _BackupEnvelope({required this.meta, required this.data});

  final Map<String, dynamic> meta;
  final Map<String, dynamic> data;
}

class _BackupEnvelopeValidation {
  const _BackupEnvelopeValidation.success(_BackupEnvelope this.envelope)
    : failure = null;

  const _BackupEnvelopeValidation.failure(_RestoreValidation this.failure)
    : envelope = null;

  final _BackupEnvelope? envelope;
  final _RestoreValidation? failure;
}

_BackupEnvelopeValidation _validateBackupEnvelope(
  Map<String, dynamic> backupJson, {
  required LocalBackupImportPreviewService previewService,
}) {
  final preview = previewService.previewFromDecodedJson(backupJson);
  if (!preview.isValid) {
    return _BackupEnvelopeValidation.failure(
      _RestoreValidation.failure(
        BackupRestoreResult.failure(
          message: preview.errorMessage ?? '备份文件格式不完整',
          errorCode: 'preview_validation_failed',
        ),
      ),
    );
  }

  final meta = backupJson['meta'];
  final data = backupJson['data'];

  if (meta is! Map<String, dynamic>) {
    return _BackupEnvelopeValidation.failure(
      _RestoreValidation.failure(
        BackupRestoreResult.failure(
          message: '备份文件格式不完整：缺少 meta',
          errorCode: 'missing_meta',
        ),
      ),
    );
  }

  if (data is! Map<String, dynamic>) {
    return _BackupEnvelopeValidation.failure(
      _RestoreValidation.failure(
        BackupRestoreResult.failure(
          message: '备份文件格式不完整：缺少 data',
          errorCode: 'missing_data',
        ),
      ),
    );
  }

  if (!BackupRestoreTables.isSupportedAppName(meta['app_name'])) {
    return _BackupEnvelopeValidation.failure(
      _RestoreValidation.failure(
        BackupRestoreResult.failure(
          message: '这不是有效的 FleetLedger 备份文件',
          errorCode: 'app_name_mismatch',
        ),
      ),
    );
  }

  final schemaVersion = _readInt(meta['schema_version']);
  if (schemaVersion == null) {
    return _BackupEnvelopeValidation.failure(
      _RestoreValidation.failure(
        BackupRestoreResult.failure(
          message: '备份文件格式不完整：缺少数据库版本',
          errorCode: 'missing_schema_version',
        ),
      ),
    );
  }

  if (schemaVersion > AppDatabase.schemaVersion) {
    return _BackupEnvelopeValidation.failure(
      _RestoreValidation.failure(
        BackupRestoreResult.failure(
          message: '备份文件版本较新，请升级 App 后再试',
          errorCode: 'schema_version_newer',
        ),
      ),
    );
  }

  final exportFormatVersion = _readInt(meta['export_format_version']);
  if (exportFormatVersion == null) {
    return _BackupEnvelopeValidation.failure(
      _RestoreValidation.failure(
        BackupRestoreResult.failure(
          message: '备份文件格式不完整：缺少备份版本',
          errorCode: 'missing_export_format_version',
        ),
      ),
    );
  }

  if (exportFormatVersion < 1 ||
      exportFormatVersion > BackupRestoreTables.supportedExportFormatVersion) {
    return _BackupEnvelopeValidation.failure(
      _RestoreValidation.failure(
        BackupRestoreResult.failure(
          message: '当前版本暂不支持该备份格式',
          errorCode: 'unsupported_export_format_version',
        ),
      ),
    );
  }

  return _BackupEnvelopeValidation.success(
    _BackupEnvelope(meta: meta, data: data),
  );
}

int? _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
