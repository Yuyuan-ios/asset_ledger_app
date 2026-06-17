import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../../infrastructure/cloud/cloud_backup_cipher.dart';
import '../../../infrastructure/cloud/cloud_backup_gateway.dart';
import '../../../infrastructure/sync/sync_state_repository.dart';
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
    CloudBackupKeyProvider? keyProvider,
    bool requireEncryption = false,
    SyncStateRepository syncStateRepository = const LocalSyncStateRepository(),
  }) : _gateway = gateway,
       _exportBackup =
           exportBackup ?? LocalBackupExportService.exportJsonBackup,
       _restoreService = restoreService ?? LocalBackupRestoreService(),
       _currentDbSchemaVersion =
           currentDbSchemaVersion ?? AppDatabase.schemaVersion,
       _now = now ?? DateTime.now,
       _keyProvider = keyProvider,
       _requireEncryption = requireEncryption,
       _syncStateRepository = syncStateRepository;

  final CloudBackupGateway _gateway;
  final Future<LocalBackupExportResult> Function() _exportBackup;
  final LocalBackupRestoreService _restoreService;
  final int _currentDbSchemaVersion;
  final DateTime Function() _now;

  /// 账号绑定密钥来源;null = 未配置加密(明文,向后兼容/dev/测试)。
  final CloudBackupKeyProvider? _keyProvider;

  /// 生产口径:要求加密但密钥不可用时**拒绝上传明文**(不静默降级)。
  final bool _requireEncryption;
  final SyncStateRepository _syncStateRepository;

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
    final plaintextJson = await File(filePath).readAsString();
    if (utf8.encode(plaintextJson).length >
        CloudBackupEnvelope.maxPayloadBytes) {
      return const CloudBackupUploadResult(
        success: false,
        errorCode: 'payload_too_large',
        errorMessage: '备份内容超出云端上限',
      );
    }
    final syncCursorWatermark = await _syncStateRepository.readPullCursor();

    // 账号绑定客户端加密:有密钥则上传前加密(OSS 只存密文);密钥不可用时,
    // 生产口径拒绝上传明文,dev/未配置加密则明文(向后兼容)。
    final CloudBackupEnvelope envelope;
    final secret = await _keyProvider?.accountSecret();
    if (secret != null && secret.isNotEmpty) {
      final encrypted = await CloudBackupCipher.encrypt(
        plaintext: plaintextJson,
        accountSecret: secret,
      );
      if (utf8.encode(encrypted.cipherTextBase64).length >
          CloudBackupEnvelope.maxPayloadBytes) {
        return const CloudBackupUploadResult(
          success: false,
          errorCode: 'payload_too_large',
          errorMessage: '备份内容超出云端上限',
        );
      }
      envelope = CloudBackupEnvelope(
        formatVersion: CloudBackupEnvelope.supportedFormatVersion,
        createdAtIso: _now().toUtc().toIso8601String(),
        dbSchemaVersion: _currentDbSchemaVersion,
        payloadSha256: payloadSha256(encrypted.cipherTextBase64),
        payloadBytes: utf8.encode(encrypted.cipherTextBase64).length,
        payloadJson: encrypted.cipherTextBase64,
        payloadEncoding: CloudBackupEnvelope.encodingAesGcm,
        syncCursorWatermark: syncCursorWatermark,
        encryption: CloudBackupEncryptionMeta(
          algo: CloudBackupCipher.algoName,
          kdf: CloudBackupCipher.kdfName,
          saltBase64: encrypted.saltBase64,
          nonceBase64: encrypted.nonceBase64,
          keyId: encrypted.keyId,
          plaintextSha256: encrypted.plaintextSha256,
          plaintextBytes: encrypted.plaintextBytes,
        ),
      );
    } else if (_requireEncryption) {
      return const CloudBackupUploadResult(
        success: false,
        errorCode: 'encryption_key_unavailable',
        errorMessage: '账号密钥不可用，已取消上传以避免明文备份',
      );
    } else {
      envelope = CloudBackupEnvelope(
        formatVersion: CloudBackupEnvelope.supportedFormatVersion,
        createdAtIso: _now().toUtc().toIso8601String(),
        dbSchemaVersion: _currentDbSchemaVersion,
        payloadSha256: payloadSha256(plaintextJson),
        payloadBytes: utf8.encode(plaintextJson).length,
        payloadJson: plaintextJson,
        syncCursorWatermark: syncCursorWatermark,
      );
    }
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
    // 传输级完整性:线上传输体(明文或密文 base64)的 sha256。
    if (payloadSha256(envelope.payloadJson) !=
        envelope.payloadSha256.toLowerCase()) {
      return BackupRestoreResult.failure(
        message: '云端备份完整性校验失败（payload_sha256 不匹配）',
        errorCode: 'payload_hash_mismatch',
      );
    }
    if (envelope.dbSchemaVersion > _currentDbSchemaVersion) {
      return BackupRestoreResult.failure(
        message: '云端备份来自更新版本的应用（schema v${envelope.dbSchemaVersion}），请先升级后再恢复',
        errorCode: 'newer_schema_version',
      );
    }

    // 加密备份:账号密钥解密 → 明文 sha256 二次校验 → 交既有 restore 流程。
    final String plaintextJson;
    if (envelope.isEncrypted) {
      final meta = envelope.encryption!;
      final secret = await _keyProvider?.accountSecret();
      if (secret == null || secret.isEmpty) {
        return BackupRestoreResult.failure(
          message: '此备份已加密，但当前账号密钥不可用，请重新登录后再恢复',
          errorCode: 'encryption_key_unavailable',
        );
      }
      if (CloudBackupCipher.keyIdFor(secret) != meta.keyId) {
        return BackupRestoreResult.failure(
          message: '此备份属于其他账号，当前账号无法解密',
          errorCode: 'wrong_account',
        );
      }
      try {
        plaintextJson = await CloudBackupCipher.decrypt(
          cipherTextBase64: envelope.payloadJson,
          saltBase64: meta.saltBase64,
          nonceBase64: meta.nonceBase64,
          expectedPlaintextSha256: meta.plaintextSha256,
          accountSecret: secret,
        );
      } on CloudBackupCipherException catch (error) {
        return BackupRestoreResult.failure(
          message: '云端备份解密失败：${error.message}',
          errorCode: error.code,
        );
      }
    } else {
      plaintextJson = envelope.payloadJson;
    }

    final result = await _restoreService.restoreFromJsonString(plaintextJson);
    if (!result.success) return result;

    final syncCursorWatermark = envelope.syncCursorWatermark;
    if (syncCursorWatermark == null) return result;

    try {
      await _syncStateRepository.writePullCursor(syncCursorWatermark);
    } catch (_) {
      return BackupRestoreResult.failure(
        message: '云端备份已恢复，但同步游标写入失败，请稍后重试恢复或重新同步。',
        errorCode: 'sync_cursor_watermark_write_failed',
        autoBackupPath: result.autoBackupPath,
      );
    }
    return result;
  }

  /// payload 的 sha256(对备份 JSON 原文 UTF-8 字节,十六进制小写)。
  static String payloadSha256(String payloadJson) {
    return sha256.convert(utf8.encode(payloadJson)).toString();
  }
}
