import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../../infrastructure/cloud/cloud_backup_gateway.dart';
import '../../db/database.dart';
import '../../models/backup_restore_result.dart';
import '../local_backup_export_service.dart';
import '../local_backup_restore_service.dart';

class CloudBackupUploadResult {
  const CloudBackupUploadResult({
    required this.success,
    this.backupId,
    this.payloadBytes = 0,
    this.errorCode,
    this.errorMessage,
  });

  final bool success;
  final String? backupId;
  final int payloadBytes;
  final String? errorCode;
  final String? errorMessage;
}

/// 云端备份服务（S5 前半件:整库备份上云/取回,非逐实体同步）。
///
/// 口径:
/// - 上传 = 复用 LocalBackupExportService 的整库 JSON 导出,封 sha256
///   包络后经 [CloudBackupGateway] 送达用户账号空间;
/// - 恢复 = 下载包络 → 完整性/版本/大小防御 → 交回
///   LocalBackupRestoreService 走既有「先本地预备份 → 校验 → 事务化
///   全有或全无」流程,云数据不直写权威表(§6.4)。
class CloudBackupService {
  CloudBackupService({
    required CloudBackupGateway gateway,
    Future<LocalBackupExportResult> Function()? exportBackup,
    LocalBackupRestoreService? restoreService,
    int? currentDbSchemaVersion,
    DateTime Function()? now,
  }) : _gateway = gateway,
       _exportBackup = exportBackup ?? LocalBackupExportService.exportJsonBackup,
       _restoreService = restoreService ?? LocalBackupRestoreService(),
       _currentDbSchemaVersion =
           currentDbSchemaVersion ?? AppDatabase.schemaVersion,
       _now = now ?? DateTime.now;

  final CloudBackupGateway _gateway;
  final Future<LocalBackupExportResult> Function() _exportBackup;
  final LocalBackupRestoreService _restoreService;
  final int _currentDbSchemaVersion;
  final DateTime Function() _now;

  /// 导出当前全库并上传。失败返回带码结果,不抛异常(供 UI 友好提示)。
  Future<CloudBackupUploadResult> uploadCurrent() async {
    final export = await _exportBackup();
    final filePath = export.filePath;
    if (!export.success || filePath == null) {
      return const CloudBackupUploadResult(
        success: false,
        errorCode: 'export_failed',
        errorMessage: '本地备份导出失败,已取消上传',
      );
    }
    final payloadJson = await File(filePath).readAsString();
    if (payloadJson.length > CloudBackupEnvelope.maxPayloadBytes) {
      return const CloudBackupUploadResult(
        success: false,
        errorCode: 'payload_too_large',
        errorMessage: '备份内容超出云端上限',
      );
    }
    final envelope = CloudBackupEnvelope(
      formatVersion: CloudBackupEnvelope.supportedFormatVersion,
      createdAtIso: _now().toUtc().toIso8601String(),
      dbSchemaVersion: _currentDbSchemaVersion,
      payloadSha256: payloadSha256(payloadJson),
      payloadBytes: utf8.encode(payloadJson).length,
      payloadJson: payloadJson,
    );
    try {
      final backupId = await _gateway.upload(envelope);
      return CloudBackupUploadResult(
        success: true,
        backupId: backupId,
        payloadBytes: envelope.payloadBytes,
      );
    } on CloudBackupGatewayException catch (error) {
      return CloudBackupUploadResult(
        success: false,
        errorCode: error.code,
        errorMessage: error.message,
      );
    }
  }

  Future<List<CloudBackupMetadata>> listRemote() => _gateway.list();

  /// 下载并恢复指定云备份。
  ///
  /// 防御顺序:sha256 完整性 → schema 版本(云包来自更新版本的库时拒绝,
  /// 防止新 schema 数据降级灌入旧 App)→ 交给既有 restore 校验/事务流程。
  Future<BackupRestoreResult> restoreFromCloud(String backupId) async {
    final CloudBackupEnvelope envelope;
    try {
      envelope = await _gateway.download(backupId);
    } on CloudBackupGatewayException catch (error) {
      return BackupRestoreResult.failure(
        message: '云端备份下载失败：${error.message}',
        errorCode: error.code,
      );
    }
    if (payloadSha256(envelope.payloadJson) !=
        envelope.payloadSha256.toLowerCase()) {
      return BackupRestoreResult.failure(
        message: '云端备份完整性校验失败（payload_sha256 不匹配）',
        errorCode: 'payload_hash_mismatch',
      );
    }
    if (envelope.dbSchemaVersion > _currentDbSchemaVersion) {
      return BackupRestoreResult.failure(
        message:
            '云端备份来自更新版本的应用（schema v${envelope.dbSchemaVersion}），请先升级后再恢复',
        errorCode: 'newer_schema_version',
      );
    }
    return _restoreService.restoreFromJsonString(envelope.payloadJson);
  }

  /// payload 的 sha256(对备份 JSON 原文 UTF-8 字节,十六进制小写)。
  static String payloadSha256(String payloadJson) {
    return sha256.convert(utf8.encode(payloadJson)).toString();
  }
}
