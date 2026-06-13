import 'dart:convert';

import 'api_client.dart';
import 'cloud_backup_cipher.dart';

/// 经 [CloudApiClient] 拉取账号绑定备份密钥的 [CloudBackupKeyProvider]。
///
/// 调用 `GET /v1/account/backup-key`(随业务鉴权头),解析 `{"backup_secret": …}`。
/// 成功后在内存缓存(同一进程内只取一次;密钥稳定,换机重登会得到同一值)。
/// 任何失败(未登录 401 / 未配置 503 / 网络错误 / 畸形响应)一律返回 null →
/// 加密不可用;生产口径下 [CloudBackupService.requireEncryption] 会据此拒绝上传
/// 明文(合规兜底),绝不静默降级。
class HttpCloudBackupKeyProvider implements CloudBackupKeyProvider {
  HttpCloudBackupKeyProvider(this._client);

  final CloudApiClient _client;

  static const String _path = '/v1/account/backup-key';

  String? _cached;

  @override
  Future<String?> accountSecret() async {
    final cached = _cached;
    if (cached != null && cached.isNotEmpty) return cached;

    final ApiResponse response;
    try {
      response = await _client.send(
        const ApiRequest(method: 'GET', path: _path),
      );
    } catch (_) {
      return null;
    }
    if (!response.isSuccess) return null;

    final raw = response.bodyJson;
    if (raw == null || raw.trim().isEmpty) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, Object?>) return null;
    final secret = decoded['backup_secret'];
    if (secret is! String || secret.isEmpty) return null;

    _cached = secret;
    return secret;
  }

  /// 退出登录/切换账号时清除缓存(下次重新拉取)。
  void invalidate() => _cached = null;
}
