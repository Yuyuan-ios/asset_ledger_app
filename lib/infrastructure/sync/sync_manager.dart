import '../cloud/api_client.dart';
import 'sync_repositories.dart';
import 'sync_state_repository.dart';

/// R5.21 抛出的 push gate 阻断异常。
///
/// `SyncManager.pushPending` 在检测到 `sync_state` 中 push gate 为非空
/// （restore 后未 reconcile）时抛出此异常，明确告知调用方推送被门控阻断，
/// 而不是发生网络/服务端错误。调用方应在完成 restore reconcile 后清除门控
/// 才能继续推送。
class SyncPushBlockedException implements Exception {
  const SyncPushBlockedException(this.reason);

  /// 当前 push gate 的原因，例如 [SyncStateRepository.gateRestorePending]。
  final String reason;

  @override
  String toString() => 'SyncPushBlockedException(reason: $reason)';
}

class SyncManager {
  const SyncManager({
    required SyncOutboxRepository outboxRepository,
    required CloudApiClient apiClient,
    SyncStateRepository syncStateRepository = const LocalSyncStateRepository(),
  }) : _outboxRepository = outboxRepository,
       _apiClient = apiClient,
       _syncStateRepository = syncStateRepository;

  final SyncOutboxRepository _outboxRepository;
  final CloudApiClient _apiClient;
  final SyncStateRepository _syncStateRepository;

  Future<int> pushPending({int limit = 50}) async {
    // R5.21 push gate：restore 后必须先 reconcile，才允许把本地 outbox 推到云端。
    // 在 listPending 与 CloudApiClient.send 之前短路，避免任何残留 pending 行
    // 在 gate 期间被读出/发送/标记。
    final gateReason = await _syncStateRepository.readPushGate();
    if (gateReason != null) {
      throw SyncPushBlockedException(gateReason);
    }

    final pending = await _outboxRepository.listPending(limit: limit);
    var pushed = 0;
    for (final entry in pending) {
      final response = await _apiClient.send(
        ApiRequest(
          method: 'POST',
          path: '/sync/outbox',
          bodyJson: entry.payloadJson,
          headers: {'x-payload-hash': entry.payloadHash},
        ),
      );
      if (response.isSuccess) pushed += 1;
    }
    return pushed;
  }
}
