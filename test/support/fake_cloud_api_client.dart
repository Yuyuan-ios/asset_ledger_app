import 'dart:convert';

import 'package:asset_ledger/infrastructure/cloud/api_client.dart';

/// R5.28 test-only functional fake cloud.
///
/// Unlike [NoOpCloudApiClient] (a throw-guarded dry-run double), this records
/// every [ApiRequest] it receives and returns configurable responses so a test
/// can drive the full push → ack / push → failure loop. It lives in test/ and
/// must never be referenced by lib/ production code.
class FakeCloudApiClient implements CloudApiClient {
  FakeCloudApiClient();

  /// Every request the SyncManager sent, in order. Tests assert method / path /
  /// headers / bodyJson against these.
  final List<ApiRequest> receivedRequests = <ApiRequest>[];

  /// Responses consumed in FIFO order before falling back to [_defaultResponse].
  /// Use [enqueueResponse] to script a first-fail-then-succeed sequence.
  final List<ApiResponse> _scriptedResponses = <ApiResponse>[];

  /// Returned once the scripted queue is exhausted. Defaults to a 200 ack.
  ApiResponse _defaultResponse = const ApiResponse(statusCode: 200);

  int get sendCount => receivedRequests.length;

  /// Set the steady-state response (e.g. switch to failure or back to success).
  void respondDefault(ApiResponse response) => _defaultResponse = response;

  /// Append a one-shot response consumed before the default (in order).
  void enqueueResponse(ApiResponse response) =>
      _scriptedResponses.add(response);

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    receivedRequests.add(request);
    if (_scriptedResponses.isNotEmpty) {
      return _scriptedResponses.removeAt(0);
    }
    if (_defaultResponse.isSuccess &&
        _defaultResponse.bodyJson == null &&
        request.method == 'POST' &&
        request.path == '/sync/changes') {
      return _acceptedSyncChangesResponse(request);
    }
    return _defaultResponse;
  }

  ApiResponse _acceptedSyncChangesResponse(ApiRequest request) {
    final decoded = jsonDecode(request.bodyJson ?? '{}');
    if (decoded is! Map || decoded['changes'] is! List) {
      return _defaultResponse;
    }
    final changes = decoded['changes'] as List;
    final accepted = <Map<String, Object?>>[];
    for (var i = 0; i < changes.length; i += 1) {
      final change = changes[i];
      if (change is! Map) continue;
      final baseVersion = change['base_version'];
      accepted.add({
        'entity_type': change['entity_type'],
        'entity_id': change['entity_id'],
        'server_seq': receivedRequests.length + i,
        'new_version': baseVersion is num ? baseVersion.toInt() + 1 : 1,
      });
    }
    return ApiResponse(
      statusCode: 200,
      bodyJson: jsonEncode({'accepted': accepted, 'conflicts': const []}),
    );
  }
}

/// Convenience builder for a retryable (or terminal) failure response.
ApiResponse fakeCloudFailure({
  int statusCode = 503,
  String code = 'unavailable',
  String message = 'fake cloud unavailable',
  bool retryable = true,
}) {
  return ApiResponse(
    statusCode: statusCode,
    error: ApiError(code: code, message: message, retryable: retryable),
  );
}

ApiResponse fakeCloudConflict({
  String code = 'conflict',
  String message = 'fake cloud conflict',
}) {
  return fakeCloudFailure(
    statusCode: 409,
    code: code,
    message: message,
    retryable: false,
  );
}
