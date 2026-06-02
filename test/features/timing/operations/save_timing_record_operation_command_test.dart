import 'package:asset_ledger/core/operations/operation_models.dart';
import 'package:asset_ledger/core/operations/operation_transaction_runner.dart';
import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/operation_audit_log.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/repositories/operation_audit_log_repository.dart';
import 'package:asset_ledger/data/repositories/project_repository.dart';
import 'package:asset_ledger/data/services/project_resolver.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_operation_command.dart';
import 'package:asset_ledger/features/timing/use_cases/save_timing_record_with_impact_use_case.dart';
import 'package:asset_ledger/infrastructure/local/operations/local_operation_transaction_runner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart'
    show Database, DatabaseExecutor, inMemoryDatabasePath, openDatabase;

import '../../../test_setup.dart';

void main() {
  configureTestDatabase();

  const command = SaveTimingRecordOperationCommand();
  const projectRef = OperationEntityRef(
    entityType: 'project',
    entityId: 'project:a',
    label: '丁队五里山',
  );

  SaveTimingRecordOperationPreviewInput input({
    bool isEditing = false,
    bool projectChanged = false,
    bool willDissolveMerge = false,
    bool willRevokeSettlement = false,
    List<OperationEntityRef>? affectedEntities,
    List<String> warnings = const [],
  }) {
    return SaveTimingRecordOperationPreviewInput(
      operationId: 'op-save-1',
      isEditing: isEditing,
      timingRecordId: isEditing ? 'timing:1' : null,
      deviceLabel: 'Hitachi 200',
      projectLabel: '丁队五里山',
      oldProjectLabel: projectChanged ? '旧项目' : null,
      newProjectLabel: projectChanged ? '新项目' : null,
      projectChanged: projectChanged,
      willDissolveMerge: willDissolveMerge,
      willRevokeSettlement: willRevokeSettlement,
      affectedEntities: affectedEntities ?? const [projectRef],
      warnings: warnings,
    );
  }

  group('preview', () {
    test('builds add timing preview with medium risk and confirmation', () {
      final preview = command.preview(input(warnings: const ['请确认工时']));

      expect(preview.operationId, 'op-save-1');
      expect(preview.operationType, OperationType.saveTimingRecord);
      expect(preview.riskLevel, OperationRiskLevel.medium);
      expect(preview.requiresConfirmation, isTrue);
      expect(preview.title, '保存计时记录');
      expect(preview.summary, contains('新增计时'));
      expect(preview.summary, contains('Hitachi 200'));
      expect(preview.summary, contains('丁队五里山'));
      expect(preview.affectedEntities, const [projectRef]);
      expect(preview.warnings, const ['请确认工时']);
      expect(preview.impactItems, isEmpty);
    });

    test('adds project change impact for editing preview', () {
      final preview = command.preview(
        input(isEditing: true, projectChanged: true),
      );

      expect(preview.title, '修改计时记录');
      expect(preview.summary, contains('编辑计时'));
      expect(preview.summary, contains('项目归属：旧项目 -> 新项目'));
      expect(preview.impactItems, hasLength(1));
      expect(preview.impactItems.single.title, contains('项目归属'));
      expect(preview.impactItems.single.code, 'project_changed');
    });

    test('raises risk and impact when merge will be dissolved', () {
      final preview = command.preview(input(willDissolveMerge: true));

      expect(preview.riskLevel, OperationRiskLevel.high);
      expect(
        preview.impactItems.map((item) => item.title),
        contains('将自动解除相关合并项目'),
      );
    });

    test('raises risk and impact when settlement will be revoked', () {
      final preview = command.preview(input(willRevokeSettlement: true));

      expect(preview.riskLevel, OperationRiskLevel.high);
      expect(
        preview.impactItems.map((item) => item.title),
        contains('将自动撤销结清状态'),
      );
    });
  });

  group('executeConfirmed', () {
    test('calls save closure and maps success result', () async {
      final preview = command.preview(input());
      var called = false;

      final result = await command.executeConfirmed(
        preview: preview,
        operationId: preview.operationId,
        executeSave: () async {
          called = true;
          return _saveResult(userMessage: '已保存计时记录');
        },
      );

      expect(called, isTrue);
      expect(result.success, isTrue);
      expect(result.operationId, preview.operationId);
      expect(result.operationType, OperationType.saveTimingRecord);
      expect(result.affectedEntities, preview.affectedEntities);
      expect(result.userMessage, '已保存计时记录');
      expect(result.auditId, isNull);
      expect(result.error, isNull);
    });

    test('rejects preview with wrong operation type without saving', () async {
      var called = false;
      const wrongPreview = OperationPreview(
        operationId: 'op-save-1',
        operationType: OperationType.deleteTimingRecord,
        requiresConfirmation: true,
      );

      await expectLater(
        command.executeConfirmed(
          preview: wrongPreview,
          operationId: wrongPreview.operationId,
          executeSave: () async {
            called = true;
            return _saveResult();
          },
        ),
        throwsArgumentError,
      );
      expect(called, isFalse);
    });

    test('rejects operationId mismatch without saving', () async {
      var called = false;
      final preview = command.preview(input());

      await expectLater(
        command.executeConfirmed(
          preview: preview,
          operationId: 'another-op',
          executeSave: () async {
            called = true;
            return _saveResult();
          },
        ),
        throwsArgumentError,
      );
      expect(called, isFalse);
    });

    test('rejects preview that does not require confirmation', () async {
      var called = false;
      const unconfirmedPreview = OperationPreview(
        operationId: 'op-save-1',
        operationType: OperationType.saveTimingRecord,
        requiresConfirmation: false,
      );

      await expectLater(
        command.executeConfirmed(
          preview: unconfirmedPreview,
          operationId: unconfirmedPreview.operationId,
          executeSave: () async {
            called = true;
            return _saveResult();
          },
        ),
        throwsArgumentError,
      );
      expect(called, isFalse);
    });

    test('maps save exception to failure result', () async {
      final preview = command.preview(input());

      final result = await command.executeConfirmed(
        preview: preview,
        operationId: preview.operationId,
        executeSave: () async => throw StateError('stale timing record'),
      );

      expect(result.success, isFalse);
      expect(result.operationId, preview.operationId);
      expect(result.operationType, OperationType.saveTimingRecord);
      expect(result.affectedEntities, preview.affectedEntities);
      expect(result.userMessage, '保存计时记录失败，请刷新后重试。');
      expect(result.auditId, isNull);
      expect(result.error, contains('stale timing record'));
    });
  });

  group('executeConfirmed with audit', () {
    test('writes success audit and returns auditId', () async {
      final repo = _FakeAuditRepo();
      final auditCmd = SaveTimingRecordOperationCommand(
        auditRepository: repo,
        actorId: 'user-1',
        now: () => DateTime.utc(2026, 6, 1, 12, 0, 0),
        auditIdFactory: () => 'audit-success-1',
      );
      final preview = auditCmd.preview(input());

      final result = await auditCmd.executeConfirmed(
        preview: preview,
        operationId: preview.operationId,
        executeSave: () async => _saveResult(userMessage: '已保存'),
      );

      expect(result.success, isTrue);
      expect(result.auditId, 'audit-success-1');
      expect(repo.inserted, hasLength(1));
      final log = repo.inserted.single;
      expect(log.id, 'audit-success-1');
      expect(log.operationId, preview.operationId);
      expect(log.operationType, OperationType.saveTimingRecord);
      expect(log.actorType, OperationAuditActorType.owner);
      expect(log.actorId, 'user-1');
      expect(log.source, OperationAuditSource.app);
      expect(log.createdAt, DateTime.utc(2026, 6, 1, 12, 0, 0));
      expect(log.confirmed, isTrue);
      expect(log.result, OperationAuditResult.success);
      expect(log.errorMessage, isNull);
      expect(log.entityRefs, preview.affectedEntities);
      expect(log.preview?.operationId, preview.operationId);
      // 序列化形态完整可解析。
      final restored = OperationAuditLog.fromMap(log.toMap());
      expect(restored.preview?.operationId, preview.operationId);
      expect(restored.result, OperationAuditResult.success);
    });

    test('writes failure audit when executeSave throws', () async {
      final repo = _FakeAuditRepo();
      final auditCmd = SaveTimingRecordOperationCommand(
        auditRepository: repo,
        now: () => DateTime.utc(2026, 6, 1, 12, 0, 0),
        auditIdFactory: () => 'audit-fail-1',
      );
      final preview = auditCmd.preview(input());

      final result = await auditCmd.executeConfirmed(
        preview: preview,
        operationId: preview.operationId,
        executeSave: () async => throw StateError('stale timing record'),
      );

      expect(result.success, isFalse);
      expect(result.auditId, 'audit-fail-1');
      expect(result.error, contains('stale timing record'));
      expect(repo.inserted, hasLength(1));
      final log = repo.inserted.single;
      expect(log.confirmed, isTrue);
      expect(log.result, OperationAuditResult.failure);
      expect(log.errorMessage, contains('stale timing record'));
    });

    test('mismatch / wrong type does not write audit', () async {
      final repo = _FakeAuditRepo();
      final auditCmd = SaveTimingRecordOperationCommand(auditRepository: repo);
      const wrongTypePreview = OperationPreview(
        operationId: 'op-x',
        operationType: OperationType.deleteTimingRecord,
        requiresConfirmation: true,
      );

      await expectLater(
        auditCmd.executeConfirmed(
          preview: wrongTypePreview,
          operationId: wrongTypePreview.operationId,
          executeSave: () async => _saveResult(),
        ),
        throwsArgumentError,
      );

      final preview = auditCmd.preview(input());
      await expectLater(
        auditCmd.executeConfirmed(
          preview: preview,
          operationId: 'mismatch',
          executeSave: () async => _saveResult(),
        ),
        throwsArgumentError,
      );

      expect(repo.inserted, isEmpty);
    });
  });

  group('executeConfirmedInTransaction', () {
    test('success runs save and audit in the transaction', () async {
      final repo = _FakeAuditRepo();
      final runner = await _newFakeRunner();
      final auditCmd = SaveTimingRecordOperationCommand(
        auditRepository: repo,
        transactionRunner: runner,
        auditIdFactory: () => 'audit-txn-success',
      );
      final preview = auditCmd.preview(input());
      var saveCalls = 0;

      final result = await auditCmd.executeConfirmedInTransaction(
        preview: preview,
        operationId: preview.operationId,
        executeSaveWithExecutor: (executor) async {
          saveCalls += 1;
          expect(identical(executor, runner.executor), isTrue);
          return _saveResult(userMessage: '已保存');
        },
      );

      expect(result.success, isTrue);
      expect(result.auditId, 'audit-txn-success');
      expect(result.userMessage, '已保存');
      expect(saveCalls, 1);
      expect(runner.runCalls, 1);
      expect(runner.commits, 1);
      expect(runner.rollbacks, 0);
      expect(repo.insertedWithExecutor, hasLength(1));
      expect(repo.insertedWithExecutor.single.id, 'audit-txn-success');
      expect(
        repo.insertedWithExecutor.single.result,
        OperationAuditResult.success,
      );
    });

    test('success audit stores auditTokenId when provided', () async {
      final repo = _FakeAuditRepo();
      final runner = await _newFakeRunner();
      final auditCmd = SaveTimingRecordOperationCommand(
        auditRepository: repo,
        transactionRunner: runner,
        auditIdFactory: () => 'audit-txn-token',
      );
      final preview = auditCmd.preview(input());

      final result = await auditCmd.executeConfirmedInTransaction(
        preview: preview,
        operationId: preview.operationId,
        auditTokenId: 'tok-1',
        executeSaveWithExecutor: (_) async => _saveResult(userMessage: '已保存'),
      );

      expect(result.success, isTrue);
      expect(repo.insertedWithExecutor, hasLength(1));
      expect(repo.insertedWithExecutor.single.tokenId, 'tok-1');
    });

    test('audit insert failure rolls back the transaction result', () async {
      final repo = _FakeAuditRepo()
        ..throwOnInsertWithExecutor = StateError('audit disk full');
      final runner = await _newFakeRunner();
      final auditCmd = SaveTimingRecordOperationCommand(
        auditRepository: repo,
        transactionRunner: runner,
        auditIdFactory: () => 'audit-txn-fail',
      );
      final preview = auditCmd.preview(input());
      var saveCalls = 0;

      final result = await auditCmd.executeConfirmedInTransaction(
        preview: preview,
        operationId: preview.operationId,
        executeSaveWithExecutor: (_) async {
          saveCalls += 1;
          return _saveResult(userMessage: '已保存');
        },
      );

      expect(saveCalls, 1, reason: '业务写入已进入事务，但 audit 失败应回滚事务');
      expect(result.success, isFalse);
      expect(result.auditId, isNull);
      expect(result.userMessage, '保存计时记录失败，请刷新后重试。');
      expect(result.error, contains('audit write failed'));
      expect(result.error, contains('audit disk full'));
      expect(runner.runCalls, 1);
      expect(runner.commits, 0);
      expect(runner.rollbacks, 1);
      expect(repo.insertedWithExecutor, isEmpty);
    });

    test('business failure rolls back and does not write audit', () async {
      final repo = _FakeAuditRepo();
      final runner = await _newFakeRunner();
      final auditCmd = SaveTimingRecordOperationCommand(
        auditRepository: repo,
        transactionRunner: runner,
      );
      final preview = auditCmd.preview(input());

      final result = await auditCmd.executeConfirmedInTransaction(
        preview: preview,
        operationId: preview.operationId,
        executeSaveWithExecutor: (_) async {
          throw StateError('stale timing record');
        },
      );

      expect(result.success, isFalse);
      expect(result.error, contains('stale timing record'));
      expect(runner.runCalls, 1);
      expect(runner.commits, 0);
      expect(runner.rollbacks, 1);
      expect(repo.insertedWithExecutor, isEmpty);
    });

    test('requires transactionRunner', () async {
      final auditCmd = SaveTimingRecordOperationCommand(
        auditRepository: _FakeAuditRepo(),
      );
      final preview = auditCmd.preview(input());

      await expectLater(
        auditCmd.executeConfirmedInTransaction(
          preview: preview,
          operationId: preview.operationId,
          executeSaveWithExecutor: (_) async => _saveResult(),
        ),
        throwsStateError,
      );
    });

    test('requires auditRepository', () async {
      final runner = await _newFakeRunner();
      final auditCmd = SaveTimingRecordOperationCommand(
        transactionRunner: runner,
      );
      final preview = auditCmd.preview(input());

      await expectLater(
        auditCmd.executeConfirmedInTransaction(
          preview: preview,
          operationId: preview.operationId,
          executeSaveWithExecutor: (_) async => _saveResult(),
        ),
        throwsStateError,
      );
      expect(runner.runCalls, 0);
    });

    test('operationId mismatch fails before transaction', () async {
      final repo = _FakeAuditRepo();
      final runner = await _newFakeRunner();
      final auditCmd = SaveTimingRecordOperationCommand(
        auditRepository: repo,
        transactionRunner: runner,
      );
      final preview = auditCmd.preview(input());
      var saveCalls = 0;

      await expectLater(
        auditCmd.executeConfirmedInTransaction(
          preview: preview,
          operationId: 'another-op',
          executeSaveWithExecutor: (_) async {
            saveCalls += 1;
            return _saveResult();
          },
        ),
        throwsArgumentError,
      );

      expect(saveCalls, 0);
      expect(runner.runCalls, 0);
      expect(repo.insertedWithExecutor, isEmpty);
    });

    test('wrong operation type fails before transaction', () async {
      final repo = _FakeAuditRepo();
      final runner = await _newFakeRunner();
      final auditCmd = SaveTimingRecordOperationCommand(
        auditRepository: repo,
        transactionRunner: runner,
      );
      const wrongPreview = OperationPreview(
        operationId: 'op-save-1',
        operationType: OperationType.deleteTimingRecord,
        requiresConfirmation: true,
      );
      var saveCalls = 0;

      await expectLater(
        auditCmd.executeConfirmedInTransaction(
          preview: wrongPreview,
          operationId: wrongPreview.operationId,
          executeSaveWithExecutor: (_) async {
            saveCalls += 1;
            return _saveResult();
          },
        ),
        throwsArgumentError,
      );

      expect(saveCalls, 0);
      expect(runner.runCalls, 0);
      expect(repo.insertedWithExecutor, isEmpty);
    });

    test(
      'local runner rolls back business write when audit insert fails',
      () async {
        await AppDatabase.resetForTest();
        addTearDown(AppDatabase.resetForTest);
        final db = await _openCurrentInMemoryDb();
        final repo = SqfliteOperationAuditLogRepository();
        await repo.insert(_auditLog(id: 'audit-duplicate'));

        final auditCmd = SaveTimingRecordOperationCommand(
          auditRepository: repo,
          transactionRunner: const LocalOperationTransactionRunner(),
          auditIdFactory: () => 'audit-duplicate',
        );
        final preview = auditCmd.preview(input());
        final resolver = ProjectResolver(
          projectRepository: SqfliteProjectRepository(),
          now: () => DateTime.utc(2026, 5, 30),
        );

        final result = await auditCmd.executeConfirmedInTransaction(
          preview: preview,
          operationId: preview.operationId,
          executeSaveWithExecutor: (executor) async {
            final resolved = await resolver.resolveOrCreateWithExecutor(
              executor,
              contact: '甲方',
              site: 'txn',
            );
            expect(resolved.created, isTrue);
            final deviceId = await executor.insert(
              'devices',
              Device(
                name: 'Device',
                brand: 'brand',
                defaultUnitPrice: 100,
                baseMeterHours: 0,
              ).toMap(),
            );
            final record = TimingRecord(
              deviceId: deviceId,
              startDate: 20260530,
              projectId: resolved.projectId,
              contact: '甲方',
              site: 'txn',
              type: TimingType.hours,
              startMeter: 0,
              endMeter: 1,
              hours: 1,
              income: 100,
            );
            final timingId = await executor.insert(
              'timing_records',
              record.toMap(),
            );
            return SaveTimingRecordWithImpactResult(
              savedRecord: record.copyWith(id: timingId),
              projectChanged: false,
              mergeDissolved: false,
              settlementRevoked: false,
              affectedProjectIds: [resolved.projectId],
              revokedProjectIds: const [],
              userMessage: '已保存',
            );
          },
        );

        expect(result.success, isFalse);
        expect(result.error, contains('audit write failed'));
        expect(
          await db.query(
            'operation_audit_logs',
            where: 'id = ?',
            whereArgs: ['audit-duplicate'],
          ),
          hasLength(1),
          reason: '事务前已有的 audit 应保留',
        );
        expect(await db.query('projects'), isEmpty);
        expect(await db.query('devices'), isEmpty);
        expect(await db.query('timing_records'), isEmpty);
      },
    );
  });

  group('cancel', () {
    test(
      'writes cancelled audit and returns failure with cancel error',
      () async {
        final repo = _FakeAuditRepo();
        final auditCmd = SaveTimingRecordOperationCommand(
          auditRepository: repo,
          now: () => DateTime.utc(2026, 6, 1, 12, 0, 0),
          auditIdFactory: () => 'audit-cancel-1',
        );
        final preview = auditCmd.preview(input());

        final result = await auditCmd.cancel(
          preview: preview,
          reason: 'user-tapped-cancel',
        );

        expect(result.success, isFalse);
        expect(result.error, 'user-tapped-cancel');
        expect(result.userMessage, '操作已取消');
        expect(result.auditId, 'audit-cancel-1');
        expect(repo.inserted, hasLength(1));
        final log = repo.inserted.single;
        expect(log.id, 'audit-cancel-1');
        expect(log.confirmed, isFalse);
        expect(log.result, OperationAuditResult.cancelled);
        expect(log.errorMessage, 'user-tapped-cancel');
        expect(log.preview?.operationId, preview.operationId);
      },
    );

    test('cancel without reason uses default cancelled error', () async {
      final repo = _FakeAuditRepo();
      final auditCmd = SaveTimingRecordOperationCommand(
        auditRepository: repo,
        auditIdFactory: () => 'audit-cancel-2',
      );
      final preview = auditCmd.preview(input());

      final result = await auditCmd.cancel(preview: preview);

      expect(result.error, 'cancelled');
      expect(repo.inserted.single.errorMessage, isNull);
    });

    test(
      'cancel without audit repository skips audit and returns failure',
      () async {
        const cmd = SaveTimingRecordOperationCommand();
        final preview = cmd.preview(input());

        final result = await cmd.cancel(preview: preview);

        expect(result.success, isFalse);
        expect(result.error, 'cancelled');
        expect(result.auditId, isNull);
      },
    );

    test('cancel rejects wrong-type preview without writing audit', () async {
      final repo = _FakeAuditRepo();
      final auditCmd = SaveTimingRecordOperationCommand(auditRepository: repo);
      const wrongPreview = OperationPreview(
        operationId: 'op-x',
        operationType: OperationType.deleteTimingRecord,
        requiresConfirmation: true,
      );

      await expectLater(
        auditCmd.cancel(preview: wrongPreview),
        throwsArgumentError,
      );
      expect(repo.inserted, isEmpty);
    });
  });

  group('audit insert failure', () {
    test(
      'business success + audit insert failure → failure with combined message',
      () async {
        final repo = _FakeAuditRepo()..throwOnInsert = StateError('disk full');
        final auditCmd = SaveTimingRecordOperationCommand(
          auditRepository: repo,
          auditIdFactory: () => 'audit-x',
        );
        final preview = auditCmd.preview(input());

        final result = await auditCmd.executeConfirmed(
          preview: preview,
          operationId: preview.operationId,
          executeSave: () async => _saveResult(userMessage: '已保存'),
        );

        expect(result.success, isFalse);
        expect(result.auditId, isNull);
        expect(result.userMessage, contains('操作已执行'));
        expect(result.userMessage, contains('审计写入失败'));
        expect(result.error, contains('audit write failed'));
        expect(result.error, contains('disk full'));
      },
    );

    test(
      'business failure + audit insert failure → failure mentions both',
      () async {
        final repo = _FakeAuditRepo()..throwOnInsert = StateError('disk full');
        final auditCmd = SaveTimingRecordOperationCommand(
          auditRepository: repo,
          auditIdFactory: () => 'audit-x',
        );
        final preview = auditCmd.preview(input());

        final result = await auditCmd.executeConfirmed(
          preview: preview,
          operationId: preview.operationId,
          executeSave: () async => throw StateError('stale timing record'),
        );

        expect(result.success, isFalse);
        expect(result.auditId, isNull);
        expect(result.userMessage, contains('保存计时记录失败'));
        expect(result.userMessage, contains('审计写入失败'));
        expect(result.error, contains('business:'));
        expect(result.error, contains('stale timing record'));
        expect(result.error, contains('audit:'));
        expect(result.error, contains('disk full'));
      },
    );
  });
}

Future<_FakeTransactionRunner> _newFakeRunner() async {
  final db = await openDatabase(inMemoryDatabasePath);
  addTearDown(db.close);
  return _FakeTransactionRunner(db);
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

SaveTimingRecordWithImpactResult _saveResult({String? userMessage}) {
  return SaveTimingRecordWithImpactResult(
    savedRecord: const TimingRecord(
      id: 1,
      deviceId: 1,
      startDate: 20260529,
      projectId: 'project:a',
      contact: '丁队',
      site: '五里山',
      type: TimingType.hours,
      startMeter: 10,
      endMeter: 17,
      hours: 7,
      income: 1400,
    ),
    projectChanged: false,
    mergeDissolved: false,
    settlementRevoked: false,
    affectedProjectIds: const ['project:a'],
    revokedProjectIds: const [],
    userMessage: userMessage,
  );
}

OperationAuditLog _auditLog({required String id}) {
  return OperationAuditLog(
    id: id,
    operationId: 'op-existing',
    operationType: OperationType.generic,
    actorType: OperationAuditActorType.system,
    source: OperationAuditSource.test,
    createdAt: DateTime.utc(2026, 5, 30),
    confirmed: true,
    result: OperationAuditResult.success,
  );
}

class _FakeTransactionRunner implements OperationTransactionRunner {
  _FakeTransactionRunner(this.executor);

  final DatabaseExecutor executor;
  int runCalls = 0;
  int commits = 0;
  int rollbacks = 0;

  @override
  Future<T> run<T>(Future<T> Function(DatabaseExecutor executor) action) async {
    runCalls += 1;
    try {
      final result = await action(executor);
      commits += 1;
      return result;
    } catch (_) {
      rollbacks += 1;
      rethrow;
    }
  }
}

class _FakeAuditRepo implements OperationAuditLogRepository {
  final List<OperationAuditLog> inserted = [];
  final List<OperationAuditLog> insertedWithExecutor = [];
  Object? throwOnInsert;
  Object? throwOnInsertWithExecutor;

  @override
  Future<void> insert(OperationAuditLog log) async {
    final boom = throwOnInsert;
    if (boom != null) throw boom;
    inserted.add(log);
  }

  @override
  Future<void> insertWithExecutor(
    DatabaseExecutor executor,
    OperationAuditLog log,
  ) async {
    final boom = throwOnInsertWithExecutor ?? throwOnInsert;
    if (boom != null) throw boom;
    insertedWithExecutor.add(log);
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
    return inserted.where((log) => log.operationId == operationId).toList();
  }

  @override
  Future<List<OperationAuditLog>> listByTokenId(String tokenId) async {
    return inserted
        .where((log) => log.tokenId == tokenId)
        .toList(growable: false);
  }

  @override
  Future<List<OperationAuditLog>> listRecent({int limit = 50}) async {
    if (limit <= 0) return const [];
    final sorted = [...inserted]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(limit).toList();
  }
}
