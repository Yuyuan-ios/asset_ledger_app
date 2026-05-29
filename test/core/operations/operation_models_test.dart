import 'package:asset_ledger/core/operations/operation_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OperationType', () {
    test('wireName round-trips for every value', () {
      for (final type in OperationType.values) {
        expect(OperationType.fromWireName(type.wireName), type);
        expect(OperationType.tryParse(type.wireName), type);
      }
    });

    test('wire codes are stable snake_case (not enum index)', () {
      expect(OperationType.saveTimingRecord.wireName, 'save_timing_record');
      expect(OperationType.deleteTimingRecord.wireName, 'delete_timing_record');
      expect(OperationType.settleProject.wireName, 'settle_project');
      expect(OperationType.writeOffProject.wireName, 'write_off_project');
      expect(OperationType.linkExternalWork.wireName, 'link_external_work');
      expect(OperationType.unlinkExternalWork.wireName, 'unlink_external_work');
      expect(OperationType.importExternalWork.wireName, 'import_external_work');
      expect(OperationType.restoreBackup.wireName, 'restore_backup');
      expect(OperationType.generic.wireName, 'generic');
    });

    test('unknown wireName: tryParse → null, fromWireName → throws', () {
      expect(OperationType.tryParse('nope'), isNull);
      expect(OperationType.tryParse(null), isNull);
      expect(
        () => OperationType.fromWireName('nope'),
        throwsArgumentError,
      );
    });
  });

  group('OperationRiskLevel', () {
    test('ordering: critical > high > medium > low', () {
      expect(OperationRiskLevel.critical.rank, greaterThan(OperationRiskLevel.high.rank));
      expect(OperationRiskLevel.high.rank, greaterThan(OperationRiskLevel.medium.rank));
      expect(OperationRiskLevel.medium.rank, greaterThan(OperationRiskLevel.low.rank));
    });

    test('isAtLeast compares by rank', () {
      expect(OperationRiskLevel.high.isAtLeast(OperationRiskLevel.high), isTrue);
      expect(OperationRiskLevel.critical.isAtLeast(OperationRiskLevel.high), isTrue);
      expect(OperationRiskLevel.medium.isAtLeast(OperationRiskLevel.high), isFalse);
      expect(OperationRiskLevel.low.isAtLeast(OperationRiskLevel.medium), isFalse);
    });

    test('wireName round-trips; unknown → null/throws', () {
      for (final level in OperationRiskLevel.values) {
        expect(OperationRiskLevel.fromWireName(level.wireName), level);
      }
      expect(OperationRiskLevel.tryParse('nope'), isNull);
      expect(() => OperationRiskLevel.fromWireName('nope'), throwsArgumentError);
    });
  });

  group('OperationImpactSeverity', () {
    test('wireName round-trips for every value', () {
      for (final s in OperationImpactSeverity.values) {
        expect(OperationImpactSeverity.fromWireName(s.wireName), s);
        expect(OperationImpactSeverity.tryParse(s.wireName), s);
      }
      expect(OperationImpactSeverity.destructive.wireName, 'destructive');
    });

    test('unknown wireName → null / throws', () {
      expect(OperationImpactSeverity.tryParse('boom'), isNull);
      expect(() => OperationImpactSeverity.fromWireName('boom'), throwsArgumentError);
    });
  });

  group('OperationEntityRef', () {
    test('toMap/fromMap round-trip with optionals', () {
      const ref = OperationEntityRef(
        entityType: 'timing_record',
        entityId: 't-1',
        label: '尚义 · HITACHI',
        projectId: 'project:1',
        deviceId: '7',
      );
      final restored = OperationEntityRef.fromMap(ref.toMap());
      expect(restored, ref);
    });

    test('toMap/fromMap round-trip with defaults (no optionals)', () {
      const ref = OperationEntityRef(entityType: 'project', entityId: 'p-1');
      final restored = OperationEntityRef.fromMap(ref.toMap());
      expect(restored, ref);
      expect(restored.label, '');
      expect(restored.projectId, isNull);
      expect(restored.deviceId, isNull);
    });

    test('fromMap throws when required entity_id missing', () {
      expect(
        () => OperationEntityRef.fromMap(const {'entity_type': 'project'}),
        throwsArgumentError,
      );
    });

    test('fromMap throws when required entity_type empty', () {
      expect(
        () => OperationEntityRef.fromMap(
          const {'entity_type': '', 'entity_id': 'x'},
        ),
        throwsArgumentError,
      );
    });
  });

  group('OperationImpactItem', () {
    test('toMap/fromMap round-trip (destructive with affected entities)', () {
      const item = OperationImpactItem(
        title: '将删除核销记录',
        description: '撤销结清会删除关联核销并恢复 active',
        severity: OperationImpactSeverity.destructive,
        affectedEntities: [
          OperationEntityRef(entityType: 'write_off', entityId: 'w-1'),
          OperationEntityRef(entityType: 'project', entityId: 'p-1'),
        ],
        code: 'revoke_settlement',
      );
      final restored = OperationImpactItem.fromMap(item.toMap());
      expect(restored.toMap(), item.toMap());
      expect(restored.severity, OperationImpactSeverity.destructive);
      expect(restored.isDestructive, isTrue);
      expect(restored.affectedEntities, item.affectedEntities);
    });

    test('round-trip with empty affectedEntities and warning severity', () {
      const item = OperationImpactItem(
        title: '金额变更',
        severity: OperationImpactSeverity.warning,
      );
      final restored = OperationImpactItem.fromMap(item.toMap());
      expect(restored.toMap(), item.toMap());
      expect(restored.affectedEntities, isEmpty);
      expect(restored.isDestructive, isFalse);
    });

    test('unknown severity falls back to info (tolerant)', () {
      final restored = OperationImpactItem.fromMap(const {
        'title': 'x',
        'severity': 'nonsense',
      });
      expect(restored.severity, OperationImpactSeverity.info);
    });

    test('fromMap throws when title missing', () {
      expect(
        () => OperationImpactItem.fromMap(const {'severity': 'info'}),
        throwsArgumentError,
      );
    });
  });

  group('OperationPreview', () {
    OperationPreview sample() {
      return const OperationPreview(
        operationId: 'op-123',
        operationType: OperationType.deleteTimingRecord,
        title: '删除计时记录',
        summary: '将删除 1 条计时记录并重算受影响项目',
        warnings: ['该操作不可撤销'],
        affectedEntities: [
          OperationEntityRef(entityType: 'timing_record', entityId: 't-1'),
        ],
        impactItems: [
          OperationImpactItem(
            title: '删除相关核销',
            severity: OperationImpactSeverity.destructive,
          ),
        ],
        requiresConfirmation: true,
        riskLevel: OperationRiskLevel.high,
      );
    }

    test('toMap/fromMap round-trip', () {
      final preview = sample();
      final restored = OperationPreview.fromMap(preview.toMap());
      expect(restored.toMap(), preview.toMap());
      expect(restored.operationType, OperationType.deleteTimingRecord);
      expect(restored.riskLevel, OperationRiskLevel.high);
      expect(restored.requiresConfirmation, isTrue);
      expect(restored.warnings, ['该操作不可撤销']);
    });

    test('hasWarnings reflects warnings list', () {
      expect(sample().hasWarnings, isTrue);
      const noWarn = OperationPreview(
        operationId: 'op-1',
        operationType: OperationType.generic,
      );
      expect(noWarn.hasWarnings, isFalse);
    });

    test('hasDestructiveImpact reflects impact severities', () {
      expect(sample().hasDestructiveImpact, isTrue);
      const infoOnly = OperationPreview(
        operationId: 'op-1',
        operationType: OperationType.generic,
        impactItems: [
          OperationImpactItem(
            title: 'i',
            severity: OperationImpactSeverity.info,
          ),
        ],
      );
      expect(infoOnly.hasDestructiveImpact, isFalse);
    });

    test('suggestsConfirmation is advisory and does not mutate requiresConfirmation', () {
      const highButNotRequired = OperationPreview(
        operationId: 'op-1',
        operationType: OperationType.settleProject,
        riskLevel: OperationRiskLevel.high,
        requiresConfirmation: false,
      );
      expect(highButNotRequired.suggestsConfirmation, isTrue);
      // 模型只表达，不替业务改写用户传入值。
      expect(highButNotRequired.requiresConfirmation, isFalse);

      const lowRisk = OperationPreview(
        operationId: 'op-2',
        operationType: OperationType.generic,
        riskLevel: OperationRiskLevel.low,
      );
      expect(lowRisk.suggestsConfirmation, isFalse);
    });

    test('defaults round-trip (empty lists, low risk, no confirmation)', () {
      const minimal = OperationPreview(
        operationId: 'op-min',
        operationType: OperationType.generic,
      );
      final restored = OperationPreview.fromMap(minimal.toMap());
      expect(restored.toMap(), minimal.toMap());
      expect(restored.warnings, isEmpty);
      expect(restored.affectedEntities, isEmpty);
      expect(restored.impactItems, isEmpty);
      expect(restored.requiresConfirmation, isFalse);
      expect(restored.riskLevel, OperationRiskLevel.low);
    });

    test('fromMap throws when operation_id missing', () {
      expect(
        () => OperationPreview.fromMap(const {
          'operation_type': 'generic',
        }),
        throwsArgumentError,
      );
    });

    test('fromMap throws when operation_type missing', () {
      expect(
        () => OperationPreview.fromMap(const {'operation_id': 'op-1'}),
        throwsArgumentError,
      );
    });

    test('fromMap tolerates unknown operation_type → generic', () {
      final restored = OperationPreview.fromMap(const {
        'operation_id': 'op-1',
        'operation_type': 'future_op_we_dont_know',
      });
      expect(restored.operationType, OperationType.generic);
    });
  });

  group('OperationExecutionResult', () {
    test('success factory: success true, error null', () {
      final result = OperationExecutionResult.success(
        operationId: 'op-1',
        operationType: OperationType.saveTimingRecord,
        userMessage: '已保存',
        affectedEntities: const [
          OperationEntityRef(entityType: 'timing_record', entityId: 't-1'),
        ],
      );
      expect(result.success, isTrue);
      expect(result.error, isNull);
      expect(result.auditId, isNull);
      expect(result.userMessage, '已保存');
    });

    test('failure factory: success false, error required & non-empty', () {
      final result = OperationExecutionResult.failure(
        operationId: 'op-1',
        error: '保存失败：更新 0 行',
      );
      expect(result.success, isFalse);
      expect(result.error, '保存失败：更新 0 行');
    });

    test('failure factory rejects empty error', () {
      expect(
        () => OperationExecutionResult.failure(operationId: 'op-1', error: ''),
        throwsArgumentError,
      );
    });

    test('success toMap/fromMap round-trip', () {
      final result = OperationExecutionResult.success(
        operationId: 'op-1',
        operationType: OperationType.settleProject,
        userMessage: 'ok',
        affectedEntities: const [
          OperationEntityRef(entityType: 'project', entityId: 'p-1'),
        ],
      );
      final restored = OperationExecutionResult.fromMap(result.toMap());
      expect(restored.toMap(), result.toMap());
      expect(restored.success, isTrue);
      expect(restored.error, isNull);
      expect(restored.operationType, OperationType.settleProject);
    });

    test('failure toMap/fromMap round-trip', () {
      final result = OperationExecutionResult.failure(
        operationId: 'op-1',
        error: 'boom',
        userMessage: '失败',
      );
      final restored = OperationExecutionResult.fromMap(result.toMap());
      expect(restored.toMap(), result.toMap());
      expect(restored.success, isFalse);
      expect(restored.error, 'boom');
    });

    test('fromMap throws when success flag missing', () {
      expect(
        () => OperationExecutionResult.fromMap(const {'operation_id': 'op-1'}),
        throwsArgumentError,
      );
    });

    test('fromMap throws when failure result has no error', () {
      expect(
        () => OperationExecutionResult.fromMap(const {
          'success': false,
          'operation_id': 'op-1',
        }),
        throwsArgumentError,
      );
    });

    test('fromMap tolerates unknown operation_type → null', () {
      final restored = OperationExecutionResult.fromMap(const {
        'success': true,
        'operation_id': 'op-1',
        'operation_type': 'unknown_future_op',
      });
      expect(restored.operationType, isNull);
    });
  });
}
