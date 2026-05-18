import '../cloud/api_client.dart';
import 'sync_repositories.dart';

class SyncManager {
  const SyncManager({
    required SyncOutboxRepository outboxRepository,
    required CloudApiClient apiClient,
  }) : _outboxRepository = outboxRepository,
       _apiClient = apiClient;

  final SyncOutboxRepository _outboxRepository;
  final CloudApiClient _apiClient;

  Future<int> pushPending({int limit = 50}) async {
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
