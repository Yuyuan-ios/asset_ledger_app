import 'dart:convert';

import 'package:asset_ledger/core/operations/operation_actor_type.dart';
import 'package:asset_ledger/core/operations/operation_confirmation_token.dart';
import 'package:asset_ledger/core/operations/operation_models.dart';
import 'package:asset_ledger/data/models/operation_token_record.dart';
import 'package:flutter_test/flutter_test.dart';

final _createdAt = DateTime.utc(2026, 6, 1, 12, 0, 0);
final _expiresAt = DateTime.utc(2026, 6, 1, 12, 30, 0);

OperationConfirmationToken _token({
  String tokenId = 'tok-1',
  String operationId = 'op-1',
  OperationActorType actorType = OperationActorType.owner,
  String? actorId,
  OperationActorType? delegatedActorType,
  String? delegatedActorId,
  String? sessionId,
  String? source,
  String inputHash = 'h-input',
  String fullAnalysisHash = 'h-full',
  String? redactedPreviewHash,
  String actorScopeHash = 'h-scope',
  OperationConfirmationTokenStatus status =
      OperationConfirmationTokenStatus.issued,
}) {
  return OperationConfirmationToken(
    tokenId: tokenId,
    operationId: operationId,
    operationType: OperationType.saveTimingRecord,
    actorType: actorType,
    actorId: actorId,
    delegatedActorType: delegatedActorType,
    delegatedActorId: delegatedActorId,
    sessionId: sessionId,
    source: source,
    createdAt: _createdAt,
    expiresAt: _expiresAt,
    inputHash: inputHash,
    fullAnalysisHash: fullAnalysisHash,
    redactedPreviewHash: redactedPreviewHash,
    actorScopeHash: actorScopeHash,
    status: status,
  );
}

void main() {
  group('OperationTokenRecord serialization', () {
    test('issued owner record toMap/fromMap round-trip', () {
      final record = OperationTokenRecord(token: _token());
      final restored = OperationTokenRecord.fromMap(record.toMap());
      expect(restored.toMap(), record.toMap());
      expect(restored.id, 'tok-1');
      expect(restored.operationId, 'op-1');
      expect(restored.status, OperationConfirmationTokenStatus.issued);
      expect(restored.token.actorType, OperationActorType.owner);
      expect(restored.token.actorId, isNull);
      expect(restored.consumedAt, isNull);
      expect(restored.cancelledAt, isNull);
    });

    test('agent delegated record round-trip', () {
      final record = OperationTokenRecord(
        token: _token(
          actorType: OperationActorType.agent,
          actorId: 'agent-1',
          delegatedActorType: OperationActorType.owner,
          delegatedActorId: 'owner-1',
          sessionId: 'sess-1',
          redactedPreviewHash: 'h-redacted',
          source: 'mcp',
        ),
      );
      final restored = OperationTokenRecord.fromMap(record.toMap());
      expect(restored.toMap(), record.toMap());
      expect(restored.token.delegatedActorType, OperationActorType.owner);
      expect(restored.token.sessionId, 'sess-1');
      expect(restored.token.redactedPreviewHash, 'h-redacted');
    });

    test('bool fields stored as 0/1', () {
      final map = OperationTokenRecord(token: _token()).toMap();
      expect(map['freshness_required'], 1);
      expect(map['requires_reanalysis_before_execute'], 1);
      expect(map['one_time_use'], 1);
    });

    test('DateTime columns serialized as UTC ISO8601 (Z)', () {
      final map = OperationTokenRecord(token: _token()).toMap();
      expect(map['created_at'], '2026-06-01T12:00:00.000Z');
      expect(map['expires_at'], '2026-06-01T12:30:00.000Z');
    });

    test('token_json rebuilds the full token', () {
      final map = OperationTokenRecord(token: _token()).toMap();
      final decoded = jsonDecode(map['token_json'] as String);
      final rebuilt = OperationConfirmationToken.fromMap(
        Map<String, Object?>.from(decoded as Map),
      );
      expect(rebuilt.tokenId, 'tok-1');
      expect(rebuilt.fullAnalysisHash, 'h-full');
      expect(rebuilt.status, OperationConfirmationTokenStatus.issued);
    });

    test('consumed record round-trip preserves status + consumed_at', () {
      final now = DateTime.utc(2026, 6, 1, 12, 10, 0);
      final consumed = OperationTokenRecord(token: _token()).asConsumed(now);
      final map = consumed.toMap();
      expect(map['status'], 'consumed');
      expect(map['consumed_at'], '2026-06-01T12:10:00.000Z');
      final restored = OperationTokenRecord.fromMap(map);
      expect(restored.status, OperationConfirmationTokenStatus.consumed);
      expect(restored.consumedAt, now);
      // token_json status stays in sync with the column.
      final decoded = jsonDecode(map['token_json'] as String) as Map;
      expect(decoded['status'], 'consumed');
    });

    test('cancelled record round-trip preserves reason + cancelled_at', () {
      final now = DateTime.utc(2026, 6, 1, 12, 15, 0);
      final cancelled = OperationTokenRecord(
        token: _token(),
      ).asCancelled(now, reason: 'user_cancelled');
      final restored = OperationTokenRecord.fromMap(cancelled.toMap());
      expect(restored.status, OperationConfirmationTokenStatus.cancelled);
      expect(restored.cancelledAt, now);
      expect(restored.lastError, 'user_cancelled');
    });

    test('metadataJson + lastError round-trip', () {
      final record = OperationTokenRecord(
        token: _token(),
        lastError: 'note',
        metadataJson: '{"tool_run_id":"r-1"}',
      );
      final restored = OperationTokenRecord.fromMap(record.toMap());
      expect(restored.lastError, 'note');
      expect(restored.metadataJson, '{"tool_run_id":"r-1"}');
    });
  });

  group('OperationTokenRecord integrity checks', () {
    test('column disagreeing with token_json throws (id / operation_id / status / input_hash)', () {
      for (final entry in <String, Object?>{
        'id': 'tampered',
        'operation_id': 'tampered',
        'status': 'cancelled',
        'input_hash': 'tampered',
        'full_analysis_hash': 'tampered',
        'actor_scope_hash': 'tampered',
        'actor_type': 'driver',
      }.entries) {
        final map = OperationTokenRecord(token: _token()).toMap();
        map[entry.key] = entry.value;
        expect(
          () => OperationTokenRecord.fromMap(map),
          throwsArgumentError,
          reason: 'tampered ${entry.key} must throw',
        );
      }
    });

    test('bool column disagreeing with token_json throws', () {
      final map = OperationTokenRecord(token: _token()).toMap();
      map['one_time_use'] = 0; // token_json says 1
      expect(() => OperationTokenRecord.fromMap(map), throwsArgumentError);
    });

    test('missing token_json throws', () {
      final map = OperationTokenRecord(token: _token()).toMap();
      map.remove('token_json');
      expect(() => OperationTokenRecord.fromMap(map), throwsArgumentError);
    });

    test('invalid status wireName in token_json throws', () {
      final map = OperationTokenRecord(token: _token()).toMap();
      final decoded = Map<String, Object?>.from(
        jsonDecode(map['token_json'] as String) as Map,
      );
      decoded['status'] = 'frozen';
      map['token_json'] = jsonEncode(decoded);
      map['status'] = 'frozen';
      expect(() => OperationTokenRecord.fromMap(map), throwsArgumentError);
    });
  });
}
