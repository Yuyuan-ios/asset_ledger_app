import 'package:asset_ledger/core/operations/operation_models.dart';
import 'package:asset_ledger/data/models/operation_audit_log.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/repositories/operation_audit_log_repository.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_operation_command.dart';
import 'package:asset_ledger/features/timing/use_cases/save_timing_record_with_impact_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' show DatabaseExecutor;

void main() {
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

  group('cancel', () {
    test('writes cancelled audit and returns failure with cancel error', () async {
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
    });

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

    test('cancel without audit repository skips audit and returns failure',
        () async {
      const cmd = SaveTimingRecordOperationCommand();
      final preview = cmd.preview(input());

      final result = await cmd.cancel(preview: preview);

      expect(result.success, isFalse);
      expect(result.error, 'cancelled');
      expect(result.auditId, isNull);
    });

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

class _FakeAuditRepo implements OperationAuditLogRepository {
  final List<OperationAuditLog> inserted = [];
  Object? throwOnInsert;

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
    await insert(log);
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
  Future<List<OperationAuditLog>> listRecent({int limit = 50}) async {
    if (limit <= 0) return const [];
    final sorted = [...inserted]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(limit).toList();
  }
}
