import 'package:asset_ledger/infrastructure/cloud/api_client.dart';
import 'package:asset_ledger/infrastructure/cloud/http_cloud_backup_key_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_cloud_api_client.dart';

void main() {
  group('HttpCloudBackupKeyProvider', () {
    test(
      'fetches the account backup secret from /v1/account/backup-key',
      () async {
        final client = FakeCloudApiClient()
          ..enqueueResponse(
            const ApiResponse(
              statusCode: 200,
              bodyJson: '{"backup_secret":"deadbeef-stable-secret"}',
            ),
          );
        final provider = HttpCloudBackupKeyProvider(client);

        expect(await provider.accountSecret(), 'deadbeef-stable-secret');
        final request = client.receivedRequests.single;
        expect(request.method, 'GET');
        expect(request.path, '/v1/account/backup-key');
      },
    );

    test('caches the secret and does not refetch', () async {
      final client = FakeCloudApiClient()
        ..enqueueResponse(
          const ApiResponse(
            statusCode: 200,
            bodyJson: '{"backup_secret":"s1"}',
          ),
        );
      final provider = HttpCloudBackupKeyProvider(client);

      expect(await provider.accountSecret(), 's1');
      expect(await provider.accountSecret(), 's1');
      expect(client.sendCount, 1, reason: '稳定密钥只取一次');
    });

    test('invalidate forces a refetch', () async {
      final client = FakeCloudApiClient()
        ..enqueueResponse(
          const ApiResponse(statusCode: 200, bodyJson: '{"backup_secret":"a"}'),
        )
        ..enqueueResponse(
          const ApiResponse(statusCode: 200, bodyJson: '{"backup_secret":"b"}'),
        );
      final provider = HttpCloudBackupKeyProvider(client);

      expect(await provider.accountSecret(), 'a');
      provider.invalidate();
      expect(await provider.accountSecret(), 'b');
      expect(client.sendCount, 2);
    });

    test(
      'returns null on 503 not-configured (encryption stays unavailable)',
      () async {
        final client = FakeCloudApiClient()
          ..enqueueResponse(fakeCloudFailure(statusCode: 503));
        expect(
          await HttpCloudBackupKeyProvider(client).accountSecret(),
          isNull,
        );
      },
    );

    test('returns null on 401 unauthorized', () async {
      final client = FakeCloudApiClient()
        ..enqueueResponse(fakeCloudFailure(statusCode: 401));
      expect(await HttpCloudBackupKeyProvider(client).accountSecret(), isNull);
    });

    test('returns null on malformed body', () async {
      final client = FakeCloudApiClient()
        ..enqueueResponse(
          const ApiResponse(statusCode: 200, bodyJson: '{"nope":1}'),
        );
      expect(await HttpCloudBackupKeyProvider(client).accountSecret(), isNull);
    });
  });
}
