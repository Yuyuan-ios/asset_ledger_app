import 'dart:convert';

import 'package:asset_ledger/core/operations/operation_access_control.dart';
import 'package:asset_ledger/core/operations/operation_actor_scope.dart';
import 'package:asset_ledger/core/operations/operation_actor_type.dart';
import 'package:asset_ledger/core/operations/operation_confirmation_token.dart';
import 'package:asset_ledger/core/operations/operation_models.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

final _createdAt = DateTime.utc(2026, 6, 1, 12, 0, 0);
final _expiresAt = DateTime.utc(2026, 6, 1, 12, 30, 0);
final _beforeExpiry = DateTime.utc(2026, 6, 1, 12, 10, 0);
final _afterExpiry = DateTime.utc(2026, 6, 1, 12, 30, 1);

final _inputHash = OperationConfirmationFingerprint.stableHash({
  'operation_id': 'op-1',
  'device_id': 7,
  'hours': 7,
});
final _fullAnalysisHash = OperationConfirmationFingerprint.stableHash({
  'old_project_id': 'project:a',
  'would_create_new_project': false,
});
final _redactedHash = OperationConfirmationFingerprint.stableHash({
  'summary': '编辑计时；设备：挖机A',
});

ActorScope _ownerScope() => ActorScope.fullOwner(ownerId: 'owner-1');
String _scopeHash(ActorScope scope) =>
    OperationConfirmationFingerprint.stableHash(scope.toMap());

OperationConfirmationToken _ownerToken({
  ActorScope? scope,
  OperationConfirmationTokenStatus status =
      OperationConfirmationTokenStatus.issued,
  String? redactedPreviewHash,
  bool freshnessRequired = true,
  bool requiresReanalysisBeforeExecute = true,
}) {
  final s = scope ?? _ownerScope();
  return OperationConfirmationToken(
    tokenId: 'tok-1',
    operationId: 'op-1',
    operationType: OperationType.saveTimingRecord,
    actorType: OperationActorType.owner,
    createdAt: _createdAt,
    expiresAt: _expiresAt,
    inputHash: _inputHash,
    fullAnalysisHash: _fullAnalysisHash,
    redactedPreviewHash: redactedPreviewHash,
    actorScopeHash: _scopeHash(s),
    freshnessRequired: freshnessRequired,
    requiresReanalysisBeforeExecute: requiresReanalysisBeforeExecute,
    status: status,
  );
}

OperationConfirmationToken _agentAsOwnerToken({ActorScope? scope}) {
  final s = scope ?? _ownerScope();
  return OperationConfirmationToken(
    tokenId: 'tok-agent',
    operationId: 'op-1',
    operationType: OperationType.saveTimingRecord,
    actorType: OperationActorType.agent,
    actorId: 'agent-1',
    delegatedActorType: OperationActorType.owner,
    delegatedActorId: 'owner-1',
    sessionId: 'sess-1',
    createdAt: _createdAt,
    expiresAt: _expiresAt,
    inputHash: _inputHash,
    fullAnalysisHash: _fullAnalysisHash,
    actorScopeHash: _scopeHash(s),
  );
}

ActorContext _ownerActor() => ActorContext(actorType: OperationActorType.owner);

ActorContext _agentAsOwnerActor() => ActorContext(
  actorType: OperationActorType.agent,
  actorId: 'agent-1',
  delegatedActorType: OperationActorType.owner,
  delegatedActorId: 'owner-1',
  sessionId: 'sess-1',
);

OperationConfirmationTokenValidationInput _ownerInput({
  OperationConfirmationToken? token,
  ActorContext? actor,
  ActorScope? scope,
  OperationType operationType = OperationType.saveTimingRecord,
  String operationId = 'op-1',
  String? inputHash,
  String? fullAnalysisHash,
  String? redactedPreviewHash,
  DateTime? now,
  String? sessionId,
}) {
  final s = scope ?? _ownerScope();
  return OperationConfirmationTokenValidationInput(
    token: token ?? _ownerToken(scope: s),
    actor: actor ?? _ownerActor(),
    scope: s,
    operationType: operationType,
    operationId: operationId,
    inputHash: inputHash ?? _inputHash,
    fullAnalysisHash: fullAnalysisHash ?? _fullAnalysisHash,
    redactedPreviewHash: redactedPreviewHash,
    now: now ?? _beforeExpiry,
    sessionId: sessionId,
  );
}

void main() {
  const validator = OperationConfirmationTokenValidator();

  group('OperationConfirmationTokenStatus', () {
    test('wireName round-trips for every value', () {
      for (final s in OperationConfirmationTokenStatus.values) {
        expect(OperationConfirmationTokenStatus.fromWireName(s.wireName), s);
        expect(OperationConfirmationTokenStatus.tryParse(s.wireName), s);
      }
      expect(OperationConfirmationTokenStatus.issued.wireName, 'issued');
      expect(OperationConfirmationTokenStatus.consumed.wireName, 'consumed');
    });

    test('unknown status: tryParse null, fromWireName throws', () {
      expect(OperationConfirmationTokenStatus.tryParse('nope'), isNull);
      expect(OperationConfirmationTokenStatus.tryParse(null), isNull);
      expect(
        () => OperationConfirmationTokenStatus.fromWireName('nope'),
        throwsArgumentError,
      );
    });
  });

  group('OperationConfirmationToken construction', () {
    test('valid owner token can omit actorId', () {
      final token = _ownerToken();
      expect(token.actorId, isNull);
      expect(token.status, OperationConfirmationTokenStatus.issued);
      expect(token.oneTimeUse, isTrue);
    });

    test('driver / partner / agent missing actorId throws', () {
      for (final type in [
        OperationActorType.driver,
        OperationActorType.partner,
      ]) {
        expect(
          () => OperationConfirmationToken(
            tokenId: 't',
            operationId: 'op-1',
            operationType: OperationType.saveTimingRecord,
            actorType: type,
            createdAt: _createdAt,
            expiresAt: _expiresAt,
            inputHash: _inputHash,
            fullAnalysisHash: _fullAnalysisHash,
            actorScopeHash: 'h',
          ),
          throwsArgumentError,
          reason: '${type.wireName} token must require actorId',
        );
      }
      // agent without actorId also throws.
      expect(
        () => OperationConfirmationToken(
          tokenId: 't',
          operationId: 'op-1',
          operationType: OperationType.saveTimingRecord,
          actorType: OperationActorType.agent,
          delegatedActorType: OperationActorType.owner,
          delegatedActorId: 'owner-1',
          createdAt: _createdAt,
          expiresAt: _expiresAt,
          inputHash: _inputHash,
          fullAnalysisHash: _fullAnalysisHash,
          actorScopeHash: 'h',
        ),
        throwsArgumentError,
      );
    });

    test('agent without delegated actor throws', () {
      expect(
        () => OperationConfirmationToken(
          tokenId: 't',
          operationId: 'op-1',
          operationType: OperationType.saveTimingRecord,
          actorType: OperationActorType.agent,
          actorId: 'agent-1',
          createdAt: _createdAt,
          expiresAt: _expiresAt,
          inputHash: _inputHash,
          fullAnalysisHash: _fullAnalysisHash,
          actorScopeHash: 'h',
        ),
        throwsArgumentError,
      );
    });

    test('agent delegated to agent / unknown throws', () {
      for (final delegated in [
        OperationActorType.agent,
        OperationActorType.unknown,
      ]) {
        expect(
          () => OperationConfirmationToken(
            tokenId: 't',
            operationId: 'op-1',
            operationType: OperationType.saveTimingRecord,
            actorType: OperationActorType.agent,
            actorId: 'agent-1',
            delegatedActorType: delegated,
            delegatedActorId: 'x',
            createdAt: _createdAt,
            expiresAt: _expiresAt,
            inputHash: _inputHash,
            fullAnalysisHash: _fullAnalysisHash,
            actorScopeHash: 'h',
          ),
          throwsArgumentError,
          reason: 'agent cannot delegate to ${delegated.wireName}',
        );
      }
    });

    test('non-agent carrying delegated scope throws', () {
      expect(
        () => OperationConfirmationToken(
          tokenId: 't',
          operationId: 'op-1',
          operationType: OperationType.saveTimingRecord,
          actorType: OperationActorType.owner,
          delegatedActorType: OperationActorType.driver,
          delegatedActorId: 'd-1',
          createdAt: _createdAt,
          expiresAt: _expiresAt,
          inputHash: _inputHash,
          fullAnalysisHash: _fullAnalysisHash,
          actorScopeHash: 'h',
        ),
        throwsArgumentError,
      );
    });

    test('expiresAt <= createdAt throws', () {
      expect(
        () => _build(expiresAt: _createdAt),
        throwsArgumentError,
      );
      expect(
        () => _build(expiresAt: _createdAt.subtract(const Duration(minutes: 1))),
        throwsArgumentError,
      );
    });

    test('missing required hash fields throw', () {
      expect(() => _build(inputHash: ''), throwsArgumentError);
      expect(() => _build(fullAnalysisHash: ''), throwsArgumentError);
      expect(() => _build(actorScopeHash: ''), throwsArgumentError);
    });

    test('freshnessRequired=false / reanalysis=false throw', () {
      expect(() => _build(freshnessRequired: false), throwsArgumentError);
      expect(
        () => _build(requiresReanalysisBeforeExecute: false),
        throwsArgumentError,
      );
    });
  });

  group('OperationConfirmationToken serialization', () {
    test('toMap / fromMap round-trip (owner)', () {
      final token = _ownerToken(redactedPreviewHash: _redactedHash);
      final restored = OperationConfirmationToken.fromMap(token.toMap());
      expect(restored.toMap(), token.toMap());
      expect(restored.actorType, OperationActorType.owner);
      expect(restored.actorId, isNull);
      expect(restored.status, OperationConfirmationTokenStatus.issued);
      expect(restored.redactedPreviewHash, _redactedHash);
    });

    test('toMap / fromMap round-trip (agent delegated)', () {
      final token = _agentAsOwnerToken();
      final restored = OperationConfirmationToken.fromMap(token.toMap());
      expect(restored.toMap(), token.toMap());
      expect(restored.delegatedActorType, OperationActorType.owner);
      expect(restored.delegatedActorId, 'owner-1');
      expect(restored.sessionId, 'sess-1');
      expect(restored.hasDelegatedScope, isTrue);
    });

    test('fromMap invalid enum wireName throws', () {
      final map = _ownerToken().toMap();
      map['status'] = 'frozen';
      expect(
        () => OperationConfirmationToken.fromMap(map),
        throwsArgumentError,
      );
    });

    test('fromMap missing required field throws', () {
      final map = _ownerToken().toMap();
      map.remove('input_hash');
      expect(
        () => OperationConfirmationToken.fromMap(map),
        throwsArgumentError,
      );
    });
  });

  group('OperationConfirmationFingerprint', () {
    test('same map, different key order, produces same hash', () {
      final a = OperationConfirmationFingerprint.stableHash({'a': 1, 'b': 2});
      final b = OperationConfirmationFingerprint.stableHash({'b': 2, 'a': 1});
      expect(a, b);
      // 与手写 canonical 串的独立 sha256 一致：证明 key 升序且非 hashCode。
      final expected =
          sha256.convert(utf8.encode('{"a":1,"b":2}')).toString();
      expect(a, expected);
    });

    test('changed value produces different hash', () {
      final a = OperationConfirmationFingerprint.stableHash({'a': 1});
      final b = OperationConfirmationFingerprint.stableHash({'a': 2});
      expect(a, isNot(b));
    });

    test('list order affects hash', () {
      final a = OperationConfirmationFingerprint.stableHash([1, 2, 3]);
      final b = OperationConfirmationFingerprint.stableHash([3, 2, 1]);
      expect(a, isNot(b));
    });

    test('DateTime canonicalization is stable across timezone', () {
      final utc = DateTime.utc(2026, 6, 1, 12, 0, 0);
      final a = OperationConfirmationFingerprint.stableHash({'t': utc});
      final b = OperationConfirmationFingerprint.stableHash({'t': utc.toLocal()});
      expect(a, b);
    });

    test('output is 64-char lowercase hex sha256, deterministic', () {
      final h = OperationConfirmationFingerprint.stableHash({'a': 1, 'b': 2});
      expect(h, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(h, OperationConfirmationFingerprint.stableHash({'b': 2, 'a': 1}));
    });

    test('unsupported types throw (no hashCode fallback)', () {
      expect(
        () => OperationConfirmationFingerprint.stableHash(Object()),
        throwsArgumentError,
      );
      expect(
        () => OperationConfirmationFingerprint.stableHash({1: 'x'}),
        throwsArgumentError,
      );
    });
  });

  group('OperationConfirmationTokenValidator success', () {
    test('valid owner token validates', () {
      final result = validator.validate(_ownerInput());
      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });

    test('valid agent token with delegated owner + matching session', () {
      final scope = _ownerScope();
      final token = _agentAsOwnerToken(scope: scope);
      final result = validator.validate(
        OperationConfirmationTokenValidationInput(
          token: token,
          actor: _agentAsOwnerActor(),
          scope: scope,
          operationType: OperationType.saveTimingRecord,
          operationId: 'op-1',
          inputHash: _inputHash,
          fullAnalysisHash: _fullAnalysisHash,
          now: _beforeExpiry,
          sessionId: 'sess-1',
        ),
      );
      expect(result.isValid, isTrue, reason: result.errors.toString());
    });

    test('valid when token binds redactedPreviewHash and input matches', () {
      final token = _ownerToken(redactedPreviewHash: _redactedHash);
      final result = validator.validate(
        _ownerInput(token: token, redactedPreviewHash: _redactedHash),
      );
      expect(result.isValid, isTrue);
    });
  });

  group('OperationConfirmationTokenValidator failures', () {
    test('consumed / expired / cancelled status invalid', () {
      for (final status in [
        OperationConfirmationTokenStatus.consumed,
        OperationConfirmationTokenStatus.expired,
        OperationConfirmationTokenStatus.cancelled,
      ]) {
        final result = validator.validate(
          _ownerInput(token: _ownerToken(status: status)),
        );
        expect(result.isValid, isFalse);
        expect(result.errors, contains(OperationConfirmationTokenError.tokenNotIssued));
      }
    });

    test('now >= expiresAt invalid', () {
      final result = validator.validate(_ownerInput(now: _afterExpiry));
      expect(result.isValid, isFalse);
      expect(result.errors, contains(OperationConfirmationTokenError.tokenExpired));
    });

    test('operationType mismatch invalid', () {
      final result = validator.validate(
        _ownerInput(operationType: OperationType.deleteTimingRecord),
      );
      expect(result.errors, contains(OperationConfirmationTokenError.operationTypeMismatch));
    });

    test('operationId mismatch invalid', () {
      final result = validator.validate(_ownerInput(operationId: 'op-other'));
      expect(result.errors, contains(OperationConfirmationTokenError.operationIdMismatch));
    });

    test('actorType mismatch invalid', () {
      final scope = _ownerScope();
      // token owner, actor partner (same scope hash); expect actor_type_mismatch.
      final result = validator.validate(
        OperationConfirmationTokenValidationInput(
          token: _ownerToken(scope: scope),
          actor: ActorContext(
            actorType: OperationActorType.partner,
            actorId: 'p-1',
          ),
          scope: scope,
          operationType: OperationType.saveTimingRecord,
          operationId: 'op-1',
          inputHash: _inputHash,
          fullAnalysisHash: _fullAnalysisHash,
          now: _beforeExpiry,
        ),
      );
      expect(result.errors, contains(OperationConfirmationTokenError.actorTypeMismatch));
    });

    test('actorId mismatch invalid', () {
      final scope = _ownerScope();
      final token = OperationConfirmationToken(
        tokenId: 'tok',
        operationId: 'op-1',
        operationType: OperationType.saveTimingRecord,
        actorType: OperationActorType.driver,
        actorId: 'driver-A',
        createdAt: _createdAt,
        expiresAt: _expiresAt,
        inputHash: _inputHash,
        fullAnalysisHash: _fullAnalysisHash,
        actorScopeHash: _scopeHash(scope),
      );
      final result = validator.validate(
        OperationConfirmationTokenValidationInput(
          token: token,
          actor: ActorContext(
            actorType: OperationActorType.driver,
            actorId: 'driver-B',
          ),
          scope: scope,
          operationType: OperationType.saveTimingRecord,
          operationId: 'op-1',
          inputHash: _inputHash,
          fullAnalysisHash: _fullAnalysisHash,
          now: _beforeExpiry,
        ),
      );
      expect(result.errors, contains(OperationConfirmationTokenError.actorIdMismatch));
    });

    test('delegated actor mismatch invalid', () {
      final scope = _ownerScope();
      final token = _agentAsOwnerToken(scope: scope);
      // actor delegated to driver instead of owner.
      final result = validator.validate(
        OperationConfirmationTokenValidationInput(
          token: token,
          actor: ActorContext(
            actorType: OperationActorType.agent,
            actorId: 'agent-1',
            delegatedActorType: OperationActorType.driver,
            delegatedActorId: 'driver-1',
            sessionId: 'sess-1',
          ),
          scope: scope,
          operationType: OperationType.saveTimingRecord,
          operationId: 'op-1',
          inputHash: _inputHash,
          fullAnalysisHash: _fullAnalysisHash,
          now: _beforeExpiry,
          sessionId: 'sess-1',
        ),
      );
      expect(result.errors, contains(OperationConfirmationTokenError.delegatedActorMismatch));
    });

    test('session mismatch invalid (agent)', () {
      final scope = _ownerScope();
      final result = validator.validate(
        OperationConfirmationTokenValidationInput(
          token: _agentAsOwnerToken(scope: scope),
          actor: _agentAsOwnerActor(),
          scope: scope,
          operationType: OperationType.saveTimingRecord,
          operationId: 'op-1',
          inputHash: _inputHash,
          fullAnalysisHash: _fullAnalysisHash,
          now: _beforeExpiry,
          sessionId: 'sess-OTHER',
        ),
      );
      expect(result.errors, contains(OperationConfirmationTokenError.sessionMismatch));
    });

    test('scope hash mismatch invalid', () {
      // token bound to fullOwner scope; present a different (devices) scope.
      final otherScope = ActorScope.devices(deviceIds: const ['7']);
      final result = validator.validate(
        _ownerInput(token: _ownerToken(), scope: otherScope),
      );
      expect(result.errors, contains(OperationConfirmationTokenError.scopeHashMismatch));
    });

    test('inputHash mismatch invalid', () {
      final result = validator.validate(_ownerInput(inputHash: 'deadbeef'));
      expect(result.errors, contains(OperationConfirmationTokenError.inputHashMismatch));
    });

    test('fullAnalysisHash mismatch invalid', () {
      final result = validator.validate(_ownerInput(fullAnalysisHash: 'deadbeef'));
      expect(result.errors, contains(OperationConfirmationTokenError.fullAnalysisHashMismatch));
    });

    test('redactedPreviewHash mismatch invalid (when token binds it)', () {
      final token = _ownerToken(redactedPreviewHash: _redactedHash);
      final result = validator.validate(
        _ownerInput(token: token, redactedPreviewHash: 'tampered'),
      );
      expect(result.errors, contains(OperationConfirmationTokenError.redactedPreviewHashMismatch));
    });

    test('expired ActorScope invalid', () {
      final expiredScope = ActorScope.fullOwner(
        ownerId: 'owner-1',
        expiresAt: _createdAt, // already past at _beforeExpiry
      );
      final result = validator.validate(
        _ownerInput(
          token: _ownerToken(scope: expiredScope),
          scope: expiredScope,
        ),
      );
      expect(result.errors, contains(OperationConfirmationTokenError.scopeExpired));
    });

    test('agent actor without delegated scope invalid', () {
      final scope = _ownerScope();
      final result = validator.validate(
        OperationConfirmationTokenValidationInput(
          token: _agentAsOwnerToken(scope: scope),
          actor: ActorContext(
            actorType: OperationActorType.agent,
            actorId: 'agent-1',
          ),
          scope: scope,
          operationType: OperationType.saveTimingRecord,
          operationId: 'op-1',
          inputHash: _inputHash,
          fullAnalysisHash: _fullAnalysisHash,
          now: _beforeExpiry,
          sessionId: 'sess-1',
        ),
      );
      expect(result.isValid, isFalse);
      expect(result.errors, contains(OperationConfirmationTokenError.delegatedActorRequired));
    });

    test('driver actor missing actorId is rejected at ActorContext construction', () {
      // The actor_id_required validator branch is defensive: a driver
      // ActorContext cannot even be built without actorId, so the invariant
      // is enforced upstream of the validator.
      expect(
        () => ActorContext(actorType: OperationActorType.driver),
        throwsArgumentError,
      );
    });

    test('freshnessRequired=false / reanalysis=false rejected at construction', () {
      // Tokens cannot be built with these false, so the validator's
      // freshness_not_required / reanalysis_not_required codes are defensive.
      expect(() => _build(freshnessRequired: false), throwsArgumentError);
      expect(
        () => _build(requiresReanalysisBeforeExecute: false),
        throwsArgumentError,
      );
    });

    test('multiple mismatches collect multiple error codes', () {
      final otherScope = ActorScope.devices(deviceIds: const ['7']);
      final result = validator.validate(
        _ownerInput(
          token: _ownerToken(),
          scope: otherScope,
          operationId: 'op-x',
          inputHash: 'bad',
          now: _afterExpiry,
        ),
      );
      expect(result.isValid, isFalse);
      expect(
        result.errors,
        containsAll(<String>[
          OperationConfirmationTokenError.tokenExpired,
          OperationConfirmationTokenError.operationIdMismatch,
          OperationConfirmationTokenError.scopeHashMismatch,
          OperationConfirmationTokenError.inputHashMismatch,
        ]),
      );
    });
  });
}

/// 通用 owner token builder（用于不变量异常用例），允许逐项覆盖。
OperationConfirmationToken _build({
  String tokenId = 'tok',
  String operationId = 'op-1',
  String inputHash = 'h-input',
  String fullAnalysisHash = 'h-full',
  String actorScopeHash = 'h-scope',
  DateTime? createdAt,
  DateTime? expiresAt,
  bool freshnessRequired = true,
  bool requiresReanalysisBeforeExecute = true,
}) {
  return OperationConfirmationToken(
    tokenId: tokenId,
    operationId: operationId,
    operationType: OperationType.saveTimingRecord,
    actorType: OperationActorType.owner,
    createdAt: createdAt ?? _createdAt,
    expiresAt: expiresAt ?? _expiresAt,
    inputHash: inputHash,
    fullAnalysisHash: fullAnalysisHash,
    actorScopeHash: actorScopeHash,
    freshnessRequired: freshnessRequired,
    requiresReanalysisBeforeExecute: requiresReanalysisBeforeExecute,
  );
}
