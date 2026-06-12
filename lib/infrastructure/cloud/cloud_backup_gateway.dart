import 'dart:convert';

import 'api_client.dart';

/// 云端备份包络（整库 JSON 备份的传输封装）。
///
/// 纲要 §6.4 口径:外部数据一律防御式解析;下载侧必须校验
/// format_version / payload_sha256 / 大小上限后才允许进入 restore。
/// 备份是用户**自己的全量数据归档**(随账号空间存储),与 .jztshare
/// 分享包不同,不适用「不打包本机标识」的分享隐私白名单。
class CloudBackupEnvelope {
  const CloudBackupEnvelope({
    required this.formatVersion,
    required this.createdAtIso,
    required this.dbSchemaVersion,
    required this.payloadSha256,
    required this.payloadBytes,
    required this.payloadJson,
  });

  static const int supportedFormatVersion = 1;
  static const String kindValue = 'cloud_backup';

  /// 单个云备份包络允许的最大 payload 字节数（防御超大下载）。
  static const int maxPayloadBytes = 64 * 1024 * 1024;

  final int formatVersion;
  final String createdAtIso;
  final int dbSchemaVersion;
  final String payloadSha256;
  final int payloadBytes;

  /// 本地备份 JSON 原文（LocalBackupExportService 的输出,作为不透明文本
  /// 传输;恢复时交回 LocalBackupRestoreService 走既有校验/事务流程）。
  final String payloadJson;

  Map<String, Object?> toJson() {
    return {
      'kind': kindValue,
      'format_version': formatVersion,
      'created_at': createdAtIso,
      'db_schema_version': dbSchemaVersion,
      'payload_sha256': payloadSha256,
      'payload_bytes': payloadBytes,
      'payload_json': payloadJson,
    };
  }

  String encode() => jsonEncode(toJson());
}

/// 云端备份的远端元数据（列表项,不含 payload）。
class CloudBackupMetadata {
  const CloudBackupMetadata({
    required this.backupId,
    required this.createdAtIso,
    required this.dbSchemaVersion,
    required this.payloadBytes,
  });

  final String backupId;
  final String createdAtIso;
  final int dbSchemaVersion;
  final int payloadBytes;
}

class CloudBackupGatewayException implements Exception {
  const CloudBackupGatewayException(this.code, this.message, {
    this.retryable = false,
  });

  final String code;
  final String message;
  final bool retryable;

  @override
  String toString() => 'CloudBackupGatewayException($code): $message';
}

/// 云端备份传输网关。实现方负责把包络送达/取回用户账号空间。
abstract class CloudBackupGateway {
  Future<String> upload(CloudBackupEnvelope envelope);

  Future<List<CloudBackupMetadata>> list();

  Future<CloudBackupEnvelope> download(String backupId);
}

/// 经 [CloudApiClient] 的 HTTP 网关实现。
///
/// 路径约定:POST /v1/backups(body=包络 JSON,响应 {"backup_id": ...});
/// GET /v1/backups(响应 {"backups": [元数据]});GET /v1/backups/{id}
/// (响应包络 JSON)。鉴权/域名由注入的 [CloudApiClient] 负责。
class HttpCloudBackupGateway implements CloudBackupGateway {
  const HttpCloudBackupGateway(this._client);

  final CloudApiClient _client;

  static const String _basePath = '/v1/backups';

  @override
  Future<String> upload(CloudBackupEnvelope envelope) async {
    final response = await _client.send(
      ApiRequest(
        method: 'POST',
        path: _basePath,
        headers: const {'content-type': 'application/json'},
        bodyJson: envelope.encode(),
      ),
    );
    final body = _requireSuccess(response, 'upload');
    final backupId = body['backup_id'] ?? body['id'];
    if (backupId is! String || backupId.trim().isEmpty) {
      throw const CloudBackupGatewayException(
        'invalid_response',
        'upload response is missing backup_id',
      );
    }
    return backupId;
  }

  @override
  Future<List<CloudBackupMetadata>> list() async {
    final response = await _client.send(
      const ApiRequest(method: 'GET', path: _basePath),
    );
    final body = _requireSuccess(response, 'list');
    final rawList = body['backups'];
    if (rawList is! List) {
      throw const CloudBackupGatewayException(
        'invalid_response',
        'list response is missing backups array',
      );
    }
    final result = <CloudBackupMetadata>[];
    for (final raw in rawList) {
      if (raw is! Map<String, Object?>) continue;
      final id = raw['backup_id'] ?? raw['id'];
      final createdAt = raw['created_at'];
      if (id is! String || id.trim().isEmpty || createdAt is! String) {
        continue; // 防御:跳过畸形条目,不让单条坏数据炸掉整个列表。
      }
      result.add(
        CloudBackupMetadata(
          backupId: id,
          createdAtIso: createdAt,
          dbSchemaVersion: (raw['db_schema_version'] as num?)?.toInt() ?? 0,
          payloadBytes: (raw['payload_bytes'] as num?)?.toInt() ?? 0,
        ),
      );
    }
    return result;
  }

  @override
  Future<CloudBackupEnvelope> download(String backupId) async {
    final encodedId = Uri.encodeComponent(backupId);
    final response = await _client.send(
      ApiRequest(method: 'GET', path: '$_basePath/$encodedId'),
    );
    final body = _requireSuccess(response, 'download');
    return decodeEnvelope(body);
  }

  /// 防御式解析下载包络:字段缺失/类型不符/超大 payload 一律抛带码异常。
  /// [maxPayloadBytes] 仅供测试注入小上限,生产恒用默认值。
  static CloudBackupEnvelope decodeEnvelope(
    Map<String, Object?> body, {
    int maxPayloadBytes = CloudBackupEnvelope.maxPayloadBytes,
  }) {
    final formatVersion = body['format_version'];
    if (formatVersion is! int ||
        formatVersion != CloudBackupEnvelope.supportedFormatVersion) {
      throw CloudBackupGatewayException(
        'unsupported_format_version',
        'cloud backup format_version $formatVersion is not supported',
      );
    }
    final payloadJson = body['payload_json'];
    final payloadSha256 = body['payload_sha256'];
    final createdAt = body['created_at'];
    final dbSchemaVersion = body['db_schema_version'];
    if (payloadJson is! String ||
        payloadJson.isEmpty ||
        payloadSha256 is! String ||
        createdAt is! String ||
        dbSchemaVersion is! int) {
      throw const CloudBackupGatewayException(
        'invalid_envelope',
        'cloud backup envelope is missing required fields',
      );
    }
    if (payloadJson.length > maxPayloadBytes) {
      throw const CloudBackupGatewayException(
        'payload_too_large',
        'cloud backup payload exceeds the maximum allowed size',
      );
    }
    return CloudBackupEnvelope(
      formatVersion: formatVersion,
      createdAtIso: createdAt,
      dbSchemaVersion: dbSchemaVersion,
      payloadSha256: payloadSha256,
      payloadBytes: (body['payload_bytes'] as num?)?.toInt() ?? 0,
      payloadJson: payloadJson,
    );
  }

  Map<String, Object?> _requireSuccess(ApiResponse response, String action) {
    if (!response.isSuccess) {
      final error = response.error;
      throw CloudBackupGatewayException(
        error?.code ?? 'http_${response.statusCode}',
        error?.message ?? 'cloud backup $action failed',
        retryable: error?.retryable ?? response.statusCode >= 500,
      );
    }
    final raw = response.bodyJson;
    if (raw == null || raw.trim().isEmpty) {
      throw CloudBackupGatewayException(
        'empty_response',
        'cloud backup $action returned an empty body',
      );
    }
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw CloudBackupGatewayException(
        'invalid_json',
        'cloud backup $action returned malformed JSON',
      );
    }
    if (decoded is! Map<String, Object?>) {
      throw CloudBackupGatewayException(
        'invalid_json',
        'cloud backup $action response must be a JSON object',
      );
    }
    return decoded;
  }
}
