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

/// Transport-level signal that the backend returned `426 Upgrade Required`.
///
/// Kept neutral (raw body fields, no feature types) so `infrastructure/cloud`
/// does not depend on `features/app_update`. The composition root maps these
/// fields into the app-update domain decision.
typedef UpgradeRequiredCallback =
    void Function({String? updateUrl, String? title, String? content});

abstract class CloudApiClient {
  Future<ApiResponse> send(ApiRequest request);
}

/// A do-nothing [CloudApiClient] that always reports a 204 no-content response.
///
/// R5.24: this client previously had a `const` no-arg constructor, which made it
/// trivial to inject silently — a push path wired to it would *look* like it
/// succeeded while never reaching a real backend. It now requires an explicit
/// `enableDryRun: true`, so it can only be used as a deliberate dry-run / test
/// double and can never be the accidental default in a production composition
/// root.
///
/// This is NOT a real HTTP client and must never be wired into production
/// composition. See `cloud_provider_no_silent_noop_fallback_test` which locks in
/// that `lib/` production code does not reference this class.
class NoOpCloudApiClient implements CloudApiClient {
  NoOpCloudApiClient({required this.enableDryRun})
    : assert(
        enableDryRun,
        'NoOpCloudApiClient is a dry-run/test double only. Pass '
        'enableDryRun: true to acknowledge it performs no real network I/O, '
        'or inject a real CloudApiClient instead.',
      ) {
    // Runtime guard so the contract still holds in release builds where
    // `assert` is stripped: a no-op cloud client must never be constructed as
    // an implicit/silent fallback.
    if (!enableDryRun) {
      throw ArgumentError.value(
        enableDryRun,
        'enableDryRun',
        'NoOpCloudApiClient may only be constructed as an explicit dry-run / '
            'test double (enableDryRun: true).',
      );
    }
  }

  final bool enableDryRun;

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    return const ApiResponse(statusCode: 204);
  }
}
