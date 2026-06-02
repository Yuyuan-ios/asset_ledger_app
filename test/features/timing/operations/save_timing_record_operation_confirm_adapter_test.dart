import 'dart:convert';

import 'package:asset_ledger/core/operations/operation_models.dart';
import 'package:asset_ledger/core/operations/operation_transaction_runner.dart';
import 'package:asset_ledger/data/models/operation_audit_log.dart';
import 'package:asset_ledger/data/repositories/operation_audit_log_repository.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_operation_analyzer.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_operation_command.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_operation_confirm_adapter.dart';
import 'package:asset_ledger/features/timing/use_cases/save_timing_record_with_impact_use_case.dart';
import 'package:asset_ledger/core/operations/operation_access_control.dart';
import 'package:asset_ledger/core/operations/operation_actor_scope.dart';
import 'package:asset_ledger/core/operations/operation_actor_type.dart';
import 'package:asset_ledger/core/operations/operation_confirmation_token.dart';
import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/operation_token_record.dart';
import 'package:asset_ledger/data/repositories/operation_token_repository.dart';
import 'package:asset_ledger/infrastructure/local/operations/local_operation_transaction_runner.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  group('SaveTimingRecordOperationConfirmAdapter', () {
    test('fresh verdict calls command and forwards execute closure', () async {
      final analyzer = _FakeAnalyzer()
        ..verdict = SaveTimingRecordFreshnessVerdict(
          isFresh: true,
          latest: _previousResult(),
          staleReasons: const [],
        );
      final command = _FakeCommand(
        result: OperationExecutionResult.success(
          operationId: 'op-save-1',
          operationType: OperationType.saveTimingRecord,
          userMessage: '已保存',
          auditId: 'audit-1',
        ),
        callExecuteClosure: true,
      );
      final adapter = SaveTimingRecordOperationConfirmAdapter(
        analyzer: analyzer,
        command: command,
      );
      var saveCalled = false;

      final result = await adapter.executeConfirmedWithFreshness(
        analyzeInput: _analyzeInput(),
        previousAnalyzeResult: _previousResult(),
        operationId: 'op-save-1',
        executeSaveWithExecutor: (_) async {
          saveCalled = true;
          return _saveResult();
        },
      );

      expect(analyzer.validateCalls, 1);
      expect(command.executeCalls, 1);
      expect(command.lastOperationId, 'op-save-1');
      expect(command.lastPreview?.operationId, 'op-save-1');
      expect(saveCalled, isTrue);
      expect(result.success, isTrue);
      expect(result.userMessage, '已保存');
      expect(result.auditId, 'audit-1');
    });

    test('stale verdict blocks command and save execution', () async {
      final analyzer = _FakeAnalyzer()
        ..verdict = const SaveTimingRecordFreshnessVerdict(
          isFresh: false,
          latest: null,
          staleReasons: [
            SaveTimingRecordStaleReason(
              type: SaveTimingRecordStaleReasonType.oldProjectChanged,
              message: '旧项目变化',
            ),
            SaveTimingRecordStaleReason(
              type: SaveTimingRecordStaleReasonType.mergeGroupsChanged,
              message: '合并组变化',
            ),
          ],
        );
      final command = _FakeCommand();
      final adapter = SaveTimingRecordOperationConfirmAdapter(
        analyzer: analyzer,
        command: command,
      );
      var saveCalled = false;

      final result = await adapter.executeConfirmedWithFreshness(
        analyzeInput: _analyzeInput(),
        previousAnalyzeResult: _previousResult(),
        operationId: 'op-save-1',
        executeSaveWithExecutor: (_) async {
          saveCalled = true;
          return _saveResult();
        },
      );

      expect(analyzer.validateCalls, 1);
      expect(command.executeCalls, 0);
      expect(saveCalled, isFalse);
      expect(result.success, isFalse);
      expect(result.userMessage, '数据已变化，请重新预览。');
      expect(result.error, contains('preview_stale'));
      expect(result.error, contains('oldProjectChanged'));
      expect(result.error, contains('mergeGroupsChanged'));
      expect(result.auditId, isNull);
    });

    test('stale with audit writes failure audit', () async {
      final analyzer = _FakeAnalyzer()
        ..verdict = const SaveTimingRecordFreshnessVerdict(
          isFresh: false,
          latest: null,
          staleReasons: [
            SaveTimingRecordStaleReason(
              type: SaveTimingRecordStaleReasonType.oldRecordMissing,
              message: '记录已不存在',
            ),
          ],
        );
      final auditRepo = _FakeAuditRepo();
      final command = _FakeCommand();
      final adapter = SaveTimingRecordOperationConfirmAdapter(
        analyzer: analyzer,
        command: command,
        auditRepository: auditRepo,
        actorType: OperationAuditActorType.agent,
        actorId: 'agent-1',
        source: OperationAuditSource.mcp,
        now: () => DateTime.utc(2026, 5, 31, 8),
        auditIdFactory: () => 'audit-stale-1',
      );
      var saveCalled = false;

      final result = await adapter.executeConfirmedWithFreshness(
        analyzeInput: _analyzeInput(),
        previousAnalyzeResult: _previousResult(),
        operationId: 'op-save-1',
        executeSaveWithExecutor: (_) async {
          saveCalled = true;
          return _saveResult();
        },
      );

      expect(command.executeCalls, 0);
      expect(saveCalled, isFalse);
      expect(result.success, isFalse);
      expect(result.auditId, 'audit-stale-1');
      expect(result.error, 'preview_stale:oldRecordMissing');

      expect(auditRepo.inserted, hasLength(1));
      final audit = auditRepo.inserted.single;
      expect(audit.id, 'audit-stale-1');
      expect(audit.operationId, 'op-save-1');
      expect(audit.tokenId, isNull);
      expect(audit.operationType, OperationType.saveTimingRecord);
      expect(audit.actorType, OperationAuditActorType.agent);
      expect(audit.actorId, 'agent-1');
      expect(audit.source, OperationAuditSource.mcp);
      expect(audit.createdAt, DateTime.utc(2026, 5, 31, 8));
      expect(audit.entityRefs, [_projectRef]);
      expect(audit.preview?.operationId, 'op-save-1');
      expect(audit.toMap()['preview_snapshot_json'], isA<String>());
      expect(audit.confirmed, isTrue);
      expect(audit.result, OperationAuditResult.failure);

      final errorJson = jsonDecode(audit.errorMessage!) as Map<String, Object?>;
      expect(errorJson['code'], 'preview_stale');
      expect(errorJson['reasons'], ['oldRecordMissing']);
    });

    test('stale with multiple reasons writes all reason codes', () async {
      final analyzer = _FakeAnalyzer()
        ..verdict = const SaveTimingRecordFreshnessVerdict(
          isFresh: false,
          latest: null,
          staleReasons: [
            SaveTimingRecordStaleReason(
              type: SaveTimingRecordStaleReasonType.oldProjectChanged,
              message: '旧项目变化',
            ),
            SaveTimingRecordStaleReason(
              type: SaveTimingRecordStaleReasonType.mergeGroupsChanged,
              message: '合并组变化',
            ),
          ],
        );
      final auditRepo = _FakeAuditRepo();
      final adapter = SaveTimingRecordOperationConfirmAdapter(
        analyzer: analyzer,
        command: _FakeCommand(),
        auditRepository: auditRepo,
        auditIdFactory: () => 'audit-stale-2',
      );

      final result = await adapter.executeConfirmedWithFreshness(
        analyzeInput: _analyzeInput(),
        previousAnalyzeResult: _previousResult(),
        operationId: 'op-save-1',
        executeSaveWithExecutor: (_) async => _saveResult(),
      );

      expect(
        result.error,
        'preview_stale:oldProjectChanged,mergeGroupsChanged',
      );
      final errorJson =
          jsonDecode(auditRepo.inserted.single.errorMessage!)
              as Map<String, Object?>;
      expect(errorJson['reasons'], ['oldProjectChanged', 'mergeGroupsChanged']);
    });

    test('stale audit insert failure does not execute save', () async {
      final analyzer = _FakeAnalyzer()
        ..verdict = const SaveTimingRecordFreshnessVerdict(
          isFresh: false,
          latest: null,
          staleReasons: [
            SaveTimingRecordStaleReason(
              type: SaveTimingRecordStaleReasonType.oldRecordMissing,
              message: '记录已不存在',
            ),
          ],
        );
      final auditRepo = _FakeAuditRepo()..insertError = StateError('disk full');
      final command = _FakeCommand();
      final adapter = SaveTimingRecordOperationConfirmAdapter(
        analyzer: analyzer,
        command: command,
        auditRepository: auditRepo,
        auditIdFactory: () => 'audit-stale-fail',
      );
      var saveCalled = false;

      final result = await adapter.executeConfirmedWithFreshness(
        analyzeInput: _analyzeInput(),
        previousAnalyzeResult: _previousResult(),
        operationId: 'op-save-1',
        executeSaveWithExecutor: (_) async {
          saveCalled = true;
          return _saveResult();
        },
      );

      expect(command.executeCalls, 0);
      expect(saveCalled, isFalse);
      expect(result.success, isFalse);
      expect(result.auditId, isNull);
      expect(result.error, contains('preview_stale:oldRecordMissing'));
      expect(result.error, contains('audit_write_failed'));
      expect(result.error, contains('disk full'));
      expect(auditRepo.inserted, isEmpty);
    });

    test('operationId mismatch fails before analyzer and command', () async {
      final analyzer = _FakeAnalyzer();
      final command = _FakeCommand();
      final auditRepo = _FakeAuditRepo();
      final adapter = SaveTimingRecordOperationConfirmAdapter(
        analyzer: analyzer,
        command: command,
        auditRepository: auditRepo,
      );
      var saveCalled = false;

      await expectLater(
        adapter.executeConfirmedWithFreshness(
          analyzeInput: _analyzeInput(),
          previousAnalyzeResult: _previousResult(),
          operationId: 'op-other',
          executeSaveWithExecutor: (_) async {
            saveCalled = true;
            return _saveResult();
          },
        ),
        throwsArgumentError,
      );

      expect(analyzer.validateCalls, 0);
      expect(command.executeCalls, 0);
      expect(saveCalled, isFalse);
      expect(auditRepo.inserted, isEmpty);
    });

    test(
      'analyzer failure returns failure without command execution',
      () async {
        final analyzer = _FakeAnalyzer()
          ..throwOnValidate = StateError('db busy');
        final command = _FakeCommand();
        final auditRepo = _FakeAuditRepo();
        final adapter = SaveTimingRecordOperationConfirmAdapter(
          analyzer: analyzer,
          command: command,
          auditRepository: auditRepo,
        );
        var saveCalled = false;

        final result = await adapter.executeConfirmedWithFreshness(
          analyzeInput: _analyzeInput(),
          previousAnalyzeResult: _previousResult(),
          operationId: 'op-save-1',
          executeSaveWithExecutor: (_) async {
            saveCalled = true;
            return _saveResult();
          },
        );

        expect(analyzer.validateCalls, 1);
        expect(command.executeCalls, 0);
        expect(saveCalled, isFalse);
        expect(result.success, isFalse);
        expect(result.userMessage, '数据已变化，请重新预览。');
        expect(result.error, contains('freshness_check_failed'));
        expect(result.error, contains('db busy'));
        expect(result.auditId, isNull);
        expect(auditRepo.inserted, isEmpty);
      },
    );

    test(
      'oldRecordMissing stale is encoded as machine-readable error',
      () async {
        final analyzer = _FakeAnalyzer()
          ..verdict = const SaveTimingRecordFreshnessVerdict(
            isFresh: false,
            latest: null,
            staleReasons: [
              SaveTimingRecordStaleReason(
                type: SaveTimingRecordStaleReasonType.oldRecordMissing,
                message: '记录已不存在',
              ),
            ],
          );
        final command = _FakeCommand();
        final adapter = SaveTimingRecordOperationConfirmAdapter(
          analyzer: analyzer,
          command: command,
        );

        final result = await adapter.executeConfirmedWithFreshness(
          analyzeInput: _analyzeInput(),
          previousAnalyzeResult: _previousResult(),
          operationId: 'op-save-1',
          executeSaveWithExecutor: (_) async => _saveResult(),
        );

        expect(command.executeCalls, 0);
        expect(result.success, isFalse);
        expect(result.userMessage, '数据已变化，请重新预览。');
        expect(result.error, 'preview_stale:oldRecordMissing');
        expect(result.auditId, isNull);
      },
    );

    test('fresh path preserves command auditId', () async {
      final analyzer = _FakeAnalyzer()
        ..verdict = SaveTimingRecordFreshnessVerdict(
          isFresh: true,
          latest: _previousResult(),
          staleReasons: const [],
        );
      final command = _FakeCommand(
        result: OperationExecutionResult.success(
          operationId: 'op-save-1',
          operationType: OperationType.saveTimingRecord,
          auditId: 'audit-from-command',
        ),
      );
      final auditRepo = _FakeAuditRepo();
      final adapter = SaveTimingRecordOperationConfirmAdapter(
        analyzer: analyzer,
        command: command,
        auditRepository: auditRepo,
      );

      final result = await adapter.executeConfirmedWithFreshness(
        analyzeInput: _analyzeInput(),
        previousAnalyzeResult: _previousResult(),
        operationId: 'op-save-1',
        executeSaveWithExecutor: (_) async => _saveResult(),
      );

      expect(command.executeCalls, 1);
      expect(result.success, isTrue);
      expect(result.auditId, 'audit-from-command');
      expect(auditRepo.inserted, isEmpty);
    });
  });

  group('executeConfirmedWithToken (unit, fakes)', () {
    final scope = ActorScope.fullOwner(ownerId: 'owner-1');
    final ownerActor = ActorContext(actorType: OperationActorType.owner);
    final checkedNow = DateTime.utc(2026, 5, 31, 8);

    test('token not found: no freshness, no command, no execute', () async {
      final analyzer = _FakeAnalyzer();
      final command = _FakeCommand();
      final tokenRepo = _FakeTokenRepository();
      final auditRepo = _FakeAuditRepo();
      final adapter = SaveTimingRecordOperationConfirmAdapter(
        analyzer: analyzer,
        command: command,
        auditRepository: auditRepo,
        tokenRepository: tokenRepo,
        auditIdFactory: () => 'audit-token-missing',
      );

      final result = await adapter.executeConfirmedWithToken(
        analyzeInput: _analyzeInput(),
        previousAnalyzeResult: _previousResult(),
        operationId: 'op-save-1',
        tokenId: 'missing',
        actor: ownerActor,
        scope: scope,
        now: checkedNow,
        executeSaveWithExecutor: (_) async => _saveResult(),
      );

      expect(result.success, isFalse);
      expect(result.error, 'token_not_found');
      expect(result.auditId, 'audit-token-missing');
      expect(analyzer.validateCalls, 0);
      expect(command.executeCalls, 0);
      expect(tokenRepo.claimCalls, 0);
      final logsByToken = await auditRepo.listByTokenId('missing');
      expect(logsByToken, hasLength(1));
      _expectTokenFailureAudit(
        logsByToken.single,
        tokenId: 'missing',
        code: 'token_not_found',
      );
    });

    test('token failure audit write failure does not return success', () async {
      final analyzer = _FakeAnalyzer();
      final command = _FakeCommand();
      final tokenRepo = _FakeTokenRepository();
      final auditRepo = _FakeAuditRepo()
        ..insertError = StateError('audit disk full');
      final adapter = SaveTimingRecordOperationConfirmAdapter(
        analyzer: analyzer,
        command: command,
        auditRepository: auditRepo,
        tokenRepository: tokenRepo,
        auditIdFactory: () => 'audit-token-missing',
      );

      final result = await adapter.executeConfirmedWithToken(
        analyzeInput: _analyzeInput(),
        previousAnalyzeResult: _previousResult(),
        operationId: 'op-save-1',
        tokenId: 'missing',
        actor: ownerActor,
        scope: scope,
        now: checkedNow,
        executeSaveWithExecutor: (_) async => _saveResult(),
      );

      expect(result.success, isFalse);
      expect(result.auditId, isNull);
      expect(result.error, contains('token_not_found'));
      expect(result.error, contains('audit_write_failed'));
      expect(result.error, contains('audit disk full'));
      expect(analyzer.validateCalls, 0);
      expect(command.executeCalls, 0);
      expect(tokenRepo.claimCalls, 0);
      expect(auditRepo.inserted, isEmpty);
    });

    test('actor id mismatch: token_invalid, no claim, no execute', () async {
      final driverScope = ActorScope.devices(deviceIds: const ['1']);
      final analyzer = _FakeAnalyzer();
      final command = _FakeCommand();
      final auditRepo = _FakeAuditRepo();
      final tokenRepo = _FakeTokenRepository()
        ..seed(
          _record(
            _token(
              actorType: OperationActorType.driver,
              actorId: 'driver-A',
              scope: driverScope,
            ),
          ),
        );
      final adapter = SaveTimingRecordOperationConfirmAdapter(
        analyzer: analyzer,
        command: command,
        auditRepository: auditRepo,
        tokenRepository: tokenRepo,
        auditIdFactory: () => 'audit-token-invalid-actor',
      );

      final result = await adapter.executeConfirmedWithToken(
        analyzeInput: _analyzeInput(),
        previousAnalyzeResult: _previousResult(),
        operationId: 'op-save-1',
        tokenId: 'tok-1',
        actor: ActorContext(
          actorType: OperationActorType.driver,
          actorId: 'driver-B',
        ),
        scope: driverScope,
        now: checkedNow,
        executeSaveWithExecutor: (_) async => _saveResult(),
      );

      expect(result.success, isFalse);
      expect(result.error, contains('token_invalid'));
      expect(result.error, contains('actor_id_mismatch'));
      expect(result.auditId, 'audit-token-invalid-actor');
      expect(analyzer.validateCalls, 0);
      expect(command.executeCalls, 0);
      expect(tokenRepo.claimCalls, 0);
      final logsByToken = await auditRepo.listByTokenId('tok-1');
      expect(logsByToken, hasLength(1));
      _expectTokenFailureAudit(
        logsByToken.single,
        tokenId: 'tok-1',
        code: 'token_invalid',
        reasons: const ['actor_id_mismatch'],
      );
    });

    test('scope hash mismatch: token_invalid, no claim', () async {
      final command = _FakeCommand();
      final auditRepo = _FakeAuditRepo();
      final tokenRepo = _FakeTokenRepository()
        ..seed(_record(_token(scope: scope)));
      final adapter = SaveTimingRecordOperationConfirmAdapter(
        analyzer: _FakeAnalyzer(),
        command: command,
        auditRepository: auditRepo,
        tokenRepository: tokenRepo,
        auditIdFactory: () => 'audit-token-invalid-scope',
      );

      final result = await adapter.executeConfirmedWithToken(
        analyzeInput: _analyzeInput(),
        previousAnalyzeResult: _previousResult(),
        operationId: 'op-save-1',
        tokenId: 'tok-1',
        actor: ownerActor,
        scope: ActorScope.devices(deviceIds: const ['9']),
        now: checkedNow,
        executeSaveWithExecutor: (_) async => _saveResult(),
      );

      expect(result.success, isFalse);
      expect(result.error, contains('scope_hash_mismatch'));
      expect(result.auditId, 'audit-token-invalid-scope');
      expect(command.executeCalls, 0);
      expect(tokenRepo.claimCalls, 0);
      final logsByToken = await auditRepo.listByTokenId('tok-1');
      expect(logsByToken, hasLength(1));
      _expectTokenFailureAudit(
        logsByToken.single,
        tokenId: 'tok-1',
        code: 'token_invalid',
        reasons: const ['scope_hash_mismatch'],
      );
    });

    test('expired token: token_invalid token_expired, no claim', () async {
      final command = _FakeCommand();
      final auditRepo = _FakeAuditRepo();
      final tokenRepo = _FakeTokenRepository()
        ..seed(
          _record(
            _token(
              scope: scope,
              createdAt: DateTime.utc(2026, 5, 31, 6),
              expiresAt: DateTime.utc(2026, 5, 31, 7, 30),
            ),
          ),
        );
      final adapter = SaveTimingRecordOperationConfirmAdapter(
        analyzer: _FakeAnalyzer(),
        command: command,
        auditRepository: auditRepo,
        tokenRepository: tokenRepo,
        auditIdFactory: () => 'audit-token-expired',
      );

      final result = await adapter.executeConfirmedWithToken(
        analyzeInput: _analyzeInput(),
        previousAnalyzeResult: _previousResult(),
        operationId: 'op-save-1',
        tokenId: 'tok-1',
        actor: ownerActor,
        scope: scope,
        now: checkedNow, // 08:00 > expiresAt 07:30
        executeSaveWithExecutor: (_) async => _saveResult(),
      );

      expect(result.success, isFalse);
      expect(result.error, contains('token_expired'));
      expect(result.auditId, 'audit-token-expired');
      expect(command.executeCalls, 0);
      expect(tokenRepo.claimCalls, 0);
      final logsByToken = await auditRepo.listByTokenId('tok-1');
      expect(logsByToken, hasLength(1));
      _expectTokenFailureAudit(
        logsByToken.single,
        tokenId: 'tok-1',
        code: 'token_invalid',
        reasons: const ['token_expired'],
      );
    });

    test('redactedPreviewHash mismatch: token_invalid, no claim', () async {
      final command = _FakeCommand();
      final tokenRepo = _FakeTokenRepository()
        ..seed(_record(_token(scope: scope, redactedPreviewHash: 'h-red')));
      final adapter = SaveTimingRecordOperationConfirmAdapter(
        analyzer: _FakeAnalyzer(),
        command: command,
        tokenRepository: tokenRepo,
      );

      final result = await adapter.executeConfirmedWithToken(
        analyzeInput: _analyzeInput(),
        previousAnalyzeResult: _previousResult(),
        operationId: 'op-save-1',
        tokenId: 'tok-1',
        actor: ownerActor,
        scope: scope,
        redactedPreviewHash: 'tampered',
        now: checkedNow,
        executeSaveWithExecutor: (_) async => _saveResult(),
      );

      expect(result.success, isFalse);
      expect(result.error, contains('redacted_preview_hash_mismatch'));
      expect(command.executeCalls, 0);
      expect(tokenRepo.claimCalls, 0);
    });

    test('fresh token path passes tokenId to command auditTokenId', () async {
      final command = _FakeCommand();
      final tokenRepo = _FakeTokenRepository()
        ..seed(_record(_token(scope: scope)));
      final adapter = SaveTimingRecordOperationConfirmAdapter(
        analyzer: _FakeAnalyzer(),
        command: command,
        tokenRepository: tokenRepo,
      );

      final result = await adapter.executeConfirmedWithToken(
        analyzeInput: _analyzeInput(),
        previousAnalyzeResult: _previousResult(),
        operationId: 'op-save-1',
        tokenId: 'tok-1',
        actor: ownerActor,
        scope: scope,
        now: checkedNow,
        executeSaveWithExecutor: (_) async => _saveResult(),
      );

      expect(result.success, isTrue);
      expect(command.executeCalls, 1);
      expect(command.lastAuditTokenId, 'tok-1');
    });

    test(
      'stale preview: valid token but stale -> no claim, token stays issued',
      () async {
        final analyzer = _FakeAnalyzer()
          ..verdict = const SaveTimingRecordFreshnessVerdict(
            isFresh: false,
            latest: null,
            staleReasons: [
              SaveTimingRecordStaleReason(
                type: SaveTimingRecordStaleReasonType.oldProjectChanged,
                message: '旧项目变化',
              ),
            ],
          );
        final command = _FakeCommand();
        final tokenRepo = _FakeTokenRepository()
          ..seed(_record(_token(scope: scope)));
        final adapter = SaveTimingRecordOperationConfirmAdapter(
          analyzer: analyzer,
          command: command,
          tokenRepository: tokenRepo,
        );

        final result = await adapter.executeConfirmedWithToken(
          analyzeInput: _analyzeInput(),
          previousAnalyzeResult: _previousResult(),
          operationId: 'op-save-1',
          tokenId: 'tok-1',
          actor: ownerActor,
          scope: scope,
          now: checkedNow,
          executeSaveWithExecutor: (_) async => _saveResult(),
        );

        expect(result.success, isFalse);
        expect(result.error, contains('preview_stale'));
        expect(analyzer.validateCalls, 1);
        expect(command.executeCalls, 0);
        expect(tokenRepo.claimCalls, 0);
        expect(
          (await tokenRepo.findById('tok-1'))!.status,
          OperationConfirmationTokenStatus.issued,
        );
      },
    );

    test('stale preview writes audit tokenId for token-aware path', () async {
      final analyzer = _FakeAnalyzer()
        ..verdict = const SaveTimingRecordFreshnessVerdict(
          isFresh: false,
          latest: null,
          staleReasons: [
            SaveTimingRecordStaleReason(
              type: SaveTimingRecordStaleReasonType.oldProjectChanged,
              message: '旧项目变化',
            ),
          ],
        );
      final tokenRepo = _FakeTokenRepository()
        ..seed(_record(_token(scope: scope)));
      final auditRepo = _FakeAuditRepo();
      final adapter = SaveTimingRecordOperationConfirmAdapter(
        analyzer: analyzer,
        command: _FakeCommand(),
        auditRepository: auditRepo,
        tokenRepository: tokenRepo,
        auditIdFactory: () => 'audit-stale-token',
      );

      final result = await adapter.executeConfirmedWithToken(
        analyzeInput: _analyzeInput(),
        previousAnalyzeResult: _previousResult(),
        operationId: 'op-save-1',
        tokenId: 'tok-1',
        actor: ownerActor,
        scope: scope,
        now: checkedNow,
        executeSaveWithExecutor: (_) async => _saveResult(),
      );

      expect(result.success, isFalse);
      expect(result.auditId, 'audit-stale-token');
      expect(auditRepo.inserted, hasLength(1));
      expect(auditRepo.inserted.single.tokenId, 'tok-1');
      expect(tokenRepo.claimCalls, 0);
    });

    test('fresh + claim success + business success consumes token', () async {
      final analyzer = _FakeAnalyzer(); // default fresh
      final tokenRepo = _FakeTokenRepository()
        ..seed(_record(_token(scope: scope)));
      final auditRepo = _FakeAuditRepo();
      final command = SaveTimingRecordOperationCommand(
        transactionRunner: _FakeTransactionRunner(),
        auditRepository: auditRepo,
        auditIdFactory: () => 'audit-real-1',
      );
      final adapter = SaveTimingRecordOperationConfirmAdapter(
        analyzer: analyzer,
        command: command,
        tokenRepository: tokenRepo,
      );
      var saveCalled = false;

      final result = await adapter.executeConfirmedWithToken(
        analyzeInput: _analyzeInput(),
        previousAnalyzeResult: _previousResult(),
        operationId: 'op-save-1',
        tokenId: 'tok-1',
        actor: ownerActor,
        scope: scope,
        now: checkedNow,
        executeSaveWithExecutor: (_) async {
          saveCalled = true;
          return _saveResult(userMessage: '已保存');
        },
      );

      expect(result.success, isTrue);
      expect(saveCalled, isTrue);
      expect(tokenRepo.claimCalls, 1);
      expect(
        (await tokenRepo.findById('tok-1'))!.status,
        OperationConfirmationTokenStatus.consumed,
      );
      expect(auditRepo.inserted, hasLength(1));
      expect(auditRepo.inserted.single.tokenId, 'tok-1');
    });

    test('claim false: business not executed, token_claim_failed', () async {
      final analyzer = _FakeAnalyzer();
      final tokenRepo = _FakeTokenRepository()
        ..claimSucceeds = false
        ..seed(_record(_token(scope: scope)));
      final auditRepo = _FakeAuditRepo();
      final command = SaveTimingRecordOperationCommand(
        transactionRunner: _FakeTransactionRunner(),
        auditRepository: auditRepo,
        auditIdFactory: () => 'audit-real-2',
      );
      final adapter = SaveTimingRecordOperationConfirmAdapter(
        analyzer: analyzer,
        command: command,
        auditRepository: auditRepo,
        tokenRepository: tokenRepo,
        auditIdFactory: () => 'audit-claim-failed',
      );
      var saveCalled = false;

      final result = await adapter.executeConfirmedWithToken(
        analyzeInput: _analyzeInput(),
        previousAnalyzeResult: _previousResult(),
        operationId: 'op-save-1',
        tokenId: 'tok-1',
        actor: ownerActor,
        scope: scope,
        now: checkedNow,
        executeSaveWithExecutor: (_) async {
          saveCalled = true;
          return _saveResult();
        },
      );

      expect(result.success, isFalse);
      expect(result.error, contains('token_claim_failed'));
      expect(result.auditId, 'audit-claim-failed');
      expect(saveCalled, isFalse);
      expect(tokenRepo.claimCalls, 1);
      final logsByToken = await auditRepo.listByTokenId('tok-1');
      expect(logsByToken, hasLength(1));
      _expectTokenFailureAudit(
        logsByToken.single,
        tokenId: 'tok-1',
        code: 'token_claim_failed',
      );
    });

    test('missing token repository returns failure (no execute)', () async {
      final command = _FakeCommand();
      final adapter = SaveTimingRecordOperationConfirmAdapter(
        analyzer: _FakeAnalyzer(),
        command: command,
      );

      final result = await adapter.executeConfirmedWithToken(
        analyzeInput: _analyzeInput(),
        previousAnalyzeResult: _previousResult(),
        operationId: 'op-save-1',
        tokenId: 'tok-1',
        actor: ownerActor,
        scope: scope,
        now: checkedNow,
        executeSaveWithExecutor: (_) async => _saveResult(),
      );

      expect(result.success, isFalse);
      expect(result.error, 'token_repository_unavailable');
      expect(command.executeCalls, 0);
    });
  });

  group('executeConfirmedWithToken (integration, real sqflite tx)', () {
    final scope = ActorScope.fullOwner(ownerId: 'owner-1');
    final ownerActor = ActorContext(actorType: OperationActorType.owner);
    final checkedNow = DateTime.utc(2026, 5, 31, 8);

    late SqfliteOperationTokenRepository tokenRepo;
    late SqfliteOperationAuditLogRepository auditRepo;
    late SaveTimingRecordOperationConfirmAdapter adapter;

    setUp(() async {
      await AppDatabase.resetForTest();
      await _openCurrentInMemoryDb();
      tokenRepo = SqfliteOperationTokenRepository();
      auditRepo = SqfliteOperationAuditLogRepository();
      var auditSequence = 0;
      String nextAuditId() => 'audit-int-${++auditSequence}';
      final command = SaveTimingRecordOperationCommand(
        transactionRunner: const LocalOperationTransactionRunner(),
        auditRepository: auditRepo,
        auditIdFactory: nextAuditId,
      );
      adapter = SaveTimingRecordOperationConfirmAdapter(
        analyzer: _FakeAnalyzer(), // fresh
        command: command,
        auditRepository: auditRepo,
        tokenRepository: tokenRepo,
        auditIdFactory: nextAuditId,
      );
      await tokenRepo.insert(_record(_token(scope: scope)));
    });

    tearDown(() async {
      await AppDatabase.resetForTest();
    });

    test(
      'success commits: token consumed + audit row written in one tx',
      () async {
        final result = await adapter.executeConfirmedWithToken(
          analyzeInput: _analyzeInput(),
          previousAnalyzeResult: _previousResult(),
          operationId: 'op-save-1',
          tokenId: 'tok-1',
          actor: ownerActor,
          scope: scope,
          now: checkedNow,
          executeSaveWithExecutor: (_) async => _saveResult(userMessage: 'ok'),
        );

        expect(result.success, isTrue);
        expect(
          (await tokenRepo.findById('tok-1'))!.status,
          OperationConfirmationTokenStatus.consumed,
        );
        expect(await auditRepo.listByOperationId('op-save-1'), hasLength(1));
        final logsByToken = await auditRepo.listByTokenId('tok-1');
        expect(logsByToken, hasLength(1));
        expect(logsByToken.single.id, 'audit-int-1');
      },
    );

    test(
      'business failure rolls back claim: token stays issued, no audit',
      () async {
        final result = await adapter.executeConfirmedWithToken(
          analyzeInput: _analyzeInput(),
          previousAnalyzeResult: _previousResult(),
          operationId: 'op-save-1',
          tokenId: 'tok-1',
          actor: ownerActor,
          scope: scope,
          now: checkedNow,
          executeSaveWithExecutor: (_) async =>
              throw StateError('business boom'),
        );

        expect(result.success, isFalse);
        expect(
          (await tokenRepo.findById('tok-1'))!.status,
          OperationConfirmationTokenStatus.issued,
        );
        expect(await auditRepo.listByOperationId('op-save-1'), isEmpty);
      },
    );

    test('replay after success is blocked (token not issued)', () async {
      final first = await adapter.executeConfirmedWithToken(
        analyzeInput: _analyzeInput(),
        previousAnalyzeResult: _previousResult(),
        operationId: 'op-save-1',
        tokenId: 'tok-1',
        actor: ownerActor,
        scope: scope,
        now: checkedNow,
        executeSaveWithExecutor: (_) async => _saveResult(),
      );
      expect(first.success, isTrue);

      final replay = await adapter.executeConfirmedWithToken(
        analyzeInput: _analyzeInput(),
        previousAnalyzeResult: _previousResult(),
        operationId: 'op-save-1',
        tokenId: 'tok-1',
        actor: ownerActor,
        scope: scope,
        now: checkedNow,
        executeSaveWithExecutor: (_) async => _saveResult(),
      );
      expect(replay.success, isFalse);
      expect(replay.error, contains('token_not_issued'));
      expect(replay.auditId, 'audit-int-2');

      final logsByOperation = await auditRepo.listByOperationId('op-save-1');
      expect(logsByOperation, hasLength(2));
      final logsByToken = await auditRepo.listByTokenId('tok-1');
      expect(logsByToken, hasLength(2));
      expect(logsByToken.first.id, 'audit-int-1');
      _expectTokenFailureAudit(
        logsByToken.last,
        tokenId: 'tok-1',
        code: 'token_invalid',
        reasons: const ['token_not_issued'],
      );
    });
  });
}

OperationConfirmationToken _token({
  String tokenId = 'tok-1',
  String operationId = 'op-save-1',
  OperationActorType actorType = OperationActorType.owner,
  String? actorId,
  OperationActorType? delegatedActorType,
  String? delegatedActorId,
  String? sessionId,
  required ActorScope scope,
  String? redactedPreviewHash,
  DateTime? createdAt,
  DateTime? expiresAt,
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
    createdAt: createdAt ?? DateTime.utc(2026, 5, 31, 7),
    expiresAt: expiresAt ?? DateTime.utc(2026, 5, 31, 9),
    inputHash: SaveTimingRecordOperationConfirmAdapter.inputHashFor(
      _analyzeInput(),
    ),
    fullAnalysisHash:
        SaveTimingRecordOperationConfirmAdapter.fullAnalysisHashFor(
          _previousResult(),
        ),
    redactedPreviewHash: redactedPreviewHash,
    actorScopeHash: OperationConfirmationFingerprint.stableHash(scope.toMap()),
  );
}

OperationTokenRecord _record(OperationConfirmationToken token) {
  return OperationTokenRecord(token: token);
}

Future<Database> _openCurrentInMemoryDb() {
  AppDatabase.debugInitDbOverride = () {
    return openDatabase(
      inMemoryDatabasePath,
      version: AppDatabase.schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, _) => DbSchema.create(db),
    );
  };
  return AppDatabase.database;
}

class _FakeTransactionRunner implements OperationTransactionRunner {
  @override
  Future<T> run<T>(
    Future<T> Function(OperationDatabaseExecutor executor) action,
  ) {
    return action(_FakeExecutor());
  }
}

class _FakeTokenRepository implements OperationTokenRepository {
  final Map<String, OperationTokenRecord> _store = {};
  bool claimSucceeds = true;
  int claimCalls = 0;
  String? lastClaimId;

  void seed(OperationTokenRecord record) => _store[record.id] = record;

  @override
  Future<OperationTokenRecord?> findById(String id) async => _store[id];

  @override
  Future<bool> claimForConsumeWithExecutor(
    Object? executor, {
    required String id,
    required DateTime now,
  }) async {
    claimCalls += 1;
    lastClaimId = id;
    if (!claimSucceeds) return false;
    final record = _store[id];
    if (record == null) return false;
    if (record.status != OperationConfirmationTokenStatus.issued) return false;
    if (!record.expiresAt.isAfter(now)) return false;
    _store[id] = record.asConsumed(now);
    return true;
  }

  @override
  Future<bool> claimForConsume({required String id, required DateTime now}) =>
      claimForConsumeWithExecutor(null, id: id, now: now);

  @override
  Future<void> insert(OperationTokenRecord record) async => seed(record);

  @override
  Future<void> insertWithExecutor(
    Object? executor,
    OperationTokenRecord record,
  ) async => seed(record);

  @override
  Future<OperationTokenRecord?> findByIdWithExecutor(
    Object? executor,
    String id,
  ) async => _store[id];

  @override
  Future<List<OperationTokenRecord>> listByOperationId(
    String operationId,
  ) async {
    return _store.values
        .where((r) => r.operationId == operationId)
        .toList(growable: false);
  }

  @override
  Future<List<OperationTokenRecord>> listActiveByActorSession({
    required OperationActorType actorType,
    String? actorId,
    String? sessionId,
    required DateTime now,
    int limit = 50,
  }) async => const [];

  @override
  Future<bool> markCancelled({
    required String id,
    required DateTime cancelledAt,
    String? reason,
  }) async => false;

  @override
  Future<int> markExpiredBefore(DateTime now) async => 0;
}

const _projectRef = OperationEntityRef(
  entityType: 'project',
  entityId: 'project:a',
  label: '丁队五里山',
  projectId: 'project:a',
);

SaveTimingRecordOperationAnalyzeInput _analyzeInput() {
  return const SaveTimingRecordOperationAnalyzeInput(
    operationId: 'op-save-1',
    editingRecordId: 1,
    draftRecord: TimingRecord(
      id: 1,
      deviceId: 1,
      startDate: 20260531,
      projectId: 'project:a',
      contact: '丁队',
      site: '五里山',
      type: TimingType.hours,
      startMeter: 1,
      endMeter: 8,
      hours: 7,
      income: 1400,
    ),
  );
}

SaveTimingRecordOperationAnalyzeResult _previousResult() {
  const previewInput = SaveTimingRecordOperationPreviewInput(
    operationId: 'op-save-1',
    isEditing: true,
    timingRecordId: '1',
    deviceLabel: 'Hitachi 200',
    projectLabel: '丁队五里山',
    affectedEntities: [_projectRef],
  );
  return const SaveTimingRecordOperationAnalyzeResult(
    previewInput: previewInput,
    preview: OperationPreview(
      operationId: 'op-save-1',
      operationType: OperationType.saveTimingRecord,
      title: '修改计时记录',
      summary: '编辑计时；设备：Hitachi 200；项目：丁队五里山',
      affectedEntities: [_projectRef],
      requiresConfirmation: true,
      riskLevel: OperationRiskLevel.medium,
    ),
    oldProjectId: 'project:a',
    existingNewProjectId: 'project:a',
    wouldCreateNewProject: false,
    affectedProjectIds: ['project:a'],
    mergeGroupIdsToDissolve: [],
    requiresReanalysisBeforeExecute: true,
    warnings: [],
  );
}

SaveTimingRecordWithImpactResult _saveResult({String? userMessage}) {
  return SaveTimingRecordWithImpactResult(
    savedRecord: _analyzeInput().draftRecord,
    projectChanged: false,
    mergeDissolved: false,
    settlementRevoked: false,
    affectedProjectIds: const ['project:a'],
    revokedProjectIds: const [],
    userMessage: userMessage,
  );
}

void _expectTokenFailureAudit(
  OperationAuditLog audit, {
  required String tokenId,
  required String code,
  List<String> reasons = const [],
}) {
  expect(audit.operationId, 'op-save-1');
  expect(audit.tokenId, tokenId);
  expect(audit.operationType, OperationType.saveTimingRecord);
  expect(audit.entityRefs, [_projectRef]);
  expect(audit.preview?.operationId, 'op-save-1');
  expect(audit.confirmed, isTrue);
  expect(audit.result, OperationAuditResult.failure);

  final errorJson = jsonDecode(audit.errorMessage!) as Map<String, Object?>;
  expect(errorJson['code'], code);
  if (reasons.isEmpty) {
    expect(errorJson.containsKey('reasons'), isFalse);
  } else {
    expect(errorJson['reasons'], reasons);
  }
}

class _FakeAnalyzer extends SaveTimingRecordOperationAnalyzer {
  _FakeAnalyzer() : super(command: const SaveTimingRecordOperationCommand());

  int validateCalls = 0;
  Object? throwOnValidate;
  SaveTimingRecordFreshnessVerdict? verdict;

  @override
  Future<SaveTimingRecordFreshnessVerdict> validateFreshness({
    required SaveTimingRecordOperationAnalyzeInput input,
    required SaveTimingRecordOperationAnalyzeResult previousResult,
  }) async {
    validateCalls += 1;
    final error = throwOnValidate;
    if (error != null) throw error;
    return verdict ??
        SaveTimingRecordFreshnessVerdict(
          isFresh: true,
          latest: previousResult,
          staleReasons: const [],
        );
  }
}

class _FakeCommand extends SaveTimingRecordOperationCommand {
  _FakeCommand({this.result, this.callExecuteClosure = false});

  final OperationExecutionResult? result;
  final bool callExecuteClosure;

  int executeCalls = 0;
  OperationPreview? lastPreview;
  String? lastOperationId;
  String? lastAuditTokenId;

  @override
  Future<OperationExecutionResult> executeConfirmedInTransaction({
    required OperationPreview preview,
    required String operationId,
    required Future<SaveTimingRecordWithImpactResult> Function(
      OperationDatabaseExecutor executor,
    )
    executeSaveWithExecutor,
    String? auditTokenId,
  }) async {
    executeCalls += 1;
    lastPreview = preview;
    lastOperationId = operationId;
    lastAuditTokenId = auditTokenId;
    if (callExecuteClosure) {
      await executeSaveWithExecutor(_FakeExecutor());
    }
    return result ??
        OperationExecutionResult.success(
          operationId: preview.operationId,
          operationType: OperationType.saveTimingRecord,
          affectedEntities: preview.affectedEntities,
          userMessage: 'ok',
        );
  }
}

class _FakeExecutor implements OperationDatabaseExecutor {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuditRepo implements OperationAuditLogRepository {
  final inserted = <OperationAuditLog>[];
  Object? insertError;

  @override
  Future<void> insert(OperationAuditLog log) async {
    final error = insertError;
    if (error != null) throw error;
    inserted.add(log);
  }

  @override
  Future<void> insertWithExecutor(
    Object? executor,
    OperationAuditLog log,
  ) async {
    final error = insertError;
    if (error != null) throw error;
    inserted.add(log);
  }

  @override
  Future<OperationAuditLog?> findById(String id) async {
    for (final log in inserted) {
      if (log.id == id) return log;
    }
    return null;
  }

  @override
  Future<List<OperationAuditLog>> listByOperationId(String operationId) async {
    return inserted
        .where((log) => log.operationId == operationId)
        .toList(growable: false);
  }

  @override
  Future<List<OperationAuditLog>> listByTokenId(String tokenId) async {
    return inserted
        .where((log) => log.tokenId == tokenId)
        .toList(growable: false);
  }

  @override
  Future<List<OperationAuditLog>> listRecent({int limit = 50}) async {
    return inserted.take(limit).toList(growable: false);
  }
}
