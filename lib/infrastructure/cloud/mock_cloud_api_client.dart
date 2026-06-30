import 'dart:convert';

import 'api_client.dart';

/// Build-config controlled local cloud double for sandbox sync flows.
///
/// It never opens a socket. Production composition must keep using
/// [HttpCloudApiClient] through provider factories.
class MockCloudApiClient implements CloudApiClient {
  const MockCloudApiClient();

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    if (request.method == 'GET' && request.path.startsWith('/sync/changes')) {
      return ApiResponse(
        statusCode: 200,
        bodyJson: jsonEncode({'changes': const [], 'next_cursor': 0}),
      );
    }

    if (request.method == 'POST' && request.path == '/sync/changes') {
      return _acceptedSyncChangesResponse(request);
    }

    if (request.method == 'POST' && request.path == '/sync/devices') {
      return ApiResponse(statusCode: 200, bodyJson: jsonEncode({'ok': true}));
    }

    return ApiResponse(statusCode: 200, bodyJson: jsonEncode({'ok': true}));
  }

  ApiResponse _acceptedSyncChangesResponse(ApiRequest request) {
    final decoded = jsonDecode(request.bodyJson ?? '{}');
    if (decoded is! Map || decoded['changes'] is! List) {
      return ApiResponse(
        statusCode: 200,
        bodyJson: jsonEncode({'accepted': const [], 'conflicts': const []}),
      );
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
        'server_seq': i + 1,
        'new_version': baseVersion is num ? baseVersion.toInt() + 1 : 1,
      });
    }

    return ApiResponse(
      statusCode: 200,
      bodyJson: jsonEncode({'accepted': accepted, 'conflicts': const []}),
    );
  }
}
