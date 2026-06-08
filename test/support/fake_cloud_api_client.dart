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
  void enqueueResponse(ApiResponse response) => _scriptedResponses.add(response);

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    receivedRequests.add(request);
    if (_scriptedResponses.isNotEmpty) {
      return _scriptedResponses.removeAt(0);
    }
    return _defaultResponse;
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
