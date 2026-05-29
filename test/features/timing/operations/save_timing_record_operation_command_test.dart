import 'package:asset_ledger/core/operations/operation_models.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_operation_command.dart';
import 'package:asset_ledger/features/timing/use_cases/save_timing_record_with_impact_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

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
