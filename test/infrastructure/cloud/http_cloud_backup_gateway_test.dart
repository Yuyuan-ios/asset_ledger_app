import 'dart:convert';

import 'package:asset_ledger/infrastructure/cloud/api_client.dart';
import 'package:asset_ledger/infrastructure/cloud/cloud_backup_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_cloud_api_client.dart';

void main() {
  CloudBackupEnvelope envelope({String payload = '{"data":{}}'}) {
    return CloudBackupEnvelope(
      formatVersion: CloudBackupEnvelope.supportedFormatVersion,
      createdAtIso: '2026-06-12T00:00:00.000Z',
      dbSchemaVersion: 36,
      payloadSha256: 'a' * 64,
      payloadBytes: payload.length,
      payloadJson: payload,
    );
  }

  group('HttpCloudBackupGateway', () {
    test('upload posts the envelope and returns backup_id', () async {
      final client = FakeCloudApiClient()
        ..enqueueResponse(
          const ApiResponse(statusCode: 200, bodyJson: '{"backup_id":"b1"}'),
        );
      final gateway = HttpCloudBackupGateway(client);

      final id = await gateway.upload(envelope());

      expect(id, 'b1');
      final request = client.receivedRequests.single;
      expect(request.method, 'POST');
      expect(request.path, '/v1/backups');
      final body = jsonDecode(request.bodyJson!) as Map<String, Object?>;
      expect(body['kind'], CloudBackupEnvelope.kindValue);
      expect(body['format_version'], 1);
      expect(body['payload_sha256'], 'a' * 64);
    });

    test('upload without backup_id in response is rejected', () async {
      final client = FakeCloudApiClient()
        ..enqueueResponse(
          const ApiResponse(statusCode: 200, bodyJson: '{"ok":true}'),
        );
      await expectLater(
        HttpCloudBackupGateway(client).upload(envelope()),
        throwsA(
          isA<CloudBackupGatewayException>().having(
            (e) => e.code,
            'code',
            'invalid_response',
          ),
        ),
      );
    });

    test('list parses metadata and skips malformed entries', () async {
      final client = FakeCloudApiClient()
        ..enqueueResponse(
          const ApiResponse(
            statusCode: 200,
            bodyJson:
                '{"backups":[{"backup_id":"b1","created_at":"2026-06-12T00:00:00Z",'
                '"db_schema_version":36,"payload_bytes":120},'
                '{"bogus":true},'
                '{"backup_id":"","created_at":"x"}]}',
          ),
        );

      final list = await HttpCloudBackupGateway(client).list();

      expect(list, hasLength(1));
      expect(list.single.backupId, 'b1');
      expect(list.single.dbSchemaVersion, 36);
      expect(
        client.receivedRequests.single.path,
        '/v1/backups',
      );
    });

    test('download decodes a valid envelope', () async {
      final client = FakeCloudApiClient()
        ..enqueueResponse(
          ApiResponse(statusCode: 200, bodyJson: envelope().encode()),
        );

      final downloaded =
          await HttpCloudBackupGateway(client).download('b 1/x');

      expect(downloaded.payloadJson, '{"data":{}}');
      // 路径段经 URL 编码,防注入。
      expect(client.receivedRequests.single.path, '/v1/backups/b%201%2Fx');
    });

    test('decodeEnvelope rejects unsupported version, missing fields, '
        'and oversized payloads', () {
      expect(
        () => HttpCloudBackupGateway.decodeEnvelope({'format_version': 99}),
        throwsA(
          isA<CloudBackupGatewayException>().having(
            (e) => e.code,
            'code',
            'unsupported_format_version',
          ),
        ),
      );
      expect(
        () => HttpCloudBackupGateway.decodeEnvelope({'format_version': 1}),
        throwsA(
          isA<CloudBackupGatewayException>().having(
            (e) => e.code,
            'code',
            'invalid_envelope',
          ),
        ),
      );
      expect(
        () => HttpCloudBackupGateway.decodeEnvelope(
          envelope(payload: 'x' * 32).toJson(),
          maxPayloadBytes: 16,
        ),
        throwsA(
          isA<CloudBackupGatewayException>().having(
            (e) => e.code,
            'code',
            'payload_too_large',
          ),
        ),
      );
    });

    test('server errors map to retryable gateway exceptions', () async {
      final client = FakeCloudApiClient()
        ..enqueueResponse(fakeCloudFailure(statusCode: 503));

      await expectLater(
        HttpCloudBackupGateway(client).list(),
        throwsA(
          isA<CloudBackupGatewayException>().having(
            (e) => e.retryable,
            'retryable',
            isTrue,
          ),
        ),
      );
    });
  });
}
