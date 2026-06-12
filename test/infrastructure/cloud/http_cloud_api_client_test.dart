import 'package:asset_ledger/infrastructure/cloud/http_cloud_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('requires https for non-local endpoints', () {
    expect(
      () => HttpCloudApiClient(
        baseUrl: 'http://backup.example.com',
        accessTokenProvider: () async => null,
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('allows localhost http for development and widget tests', () {
    final client = HttpCloudApiClient(
      baseUrl: 'http://127.0.0.1:8080',
      accessTokenProvider: () async => null,
    );

    expect(client, isA<HttpCloudApiClient>());
  });
}
