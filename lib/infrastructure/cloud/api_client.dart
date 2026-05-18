class ApiRequest {
  const ApiRequest({
    required this.method,
    required this.path,
    this.headers = const {},
    this.bodyJson,
  });

  final String method;
  final String path;
  final Map<String, String> headers;
  final String? bodyJson;
}

class ApiResponse {
  const ApiResponse({required this.statusCode, this.bodyJson, this.error});

  final int statusCode;
  final String? bodyJson;
  final ApiError? error;

  bool get isSuccess => statusCode >= 200 && statusCode < 300 && error == null;
}

class ApiError {
  const ApiError({
    required this.code,
    required this.message,
    this.retryable = false,
  });

  final String code;
  final String message;
  final bool retryable;
}

abstract class CloudApiClient {
  Future<ApiResponse> send(ApiRequest request);
}

class EmptyCloudApiClient implements CloudApiClient {
  const EmptyCloudApiClient();

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    return const ApiResponse(statusCode: 204);
  }
}
