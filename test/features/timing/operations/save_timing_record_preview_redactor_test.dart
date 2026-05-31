import 'dart:convert';

import 'package:asset_ledger/core/operations/operation_access_control.dart';
import 'package:asset_ledger/core/operations/operation_actor_type.dart';
import 'package:asset_ledger/core/operations/operation_models.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_operation_analyzer.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_operation_command.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_operation_preview_adapter.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_preview_redactor.dart';
import 'package:flutter_test/flutter_test.dart';

/// 这些是测试里刻意放入的「敏感原文」，redacted 输出对非 owner 不得出现它们。
const _contact = '张老板';
const _site = '清河工地';
const _projectLabel = '$_contact · $_site';
const _oldProjectId = 'project:aaa';
const _newProjectId = 'project:bbb';
const _legacyKey = 'legacy-key-xyz';
const _mergeGroupId = 7777;
const _deviceName = '挖机A';

/// 构造一份「敏感的」保存计时预览 response（编辑 + 改项目 + 解除合并 + 撤销结清）。
/// 纯内存构造，不使用 sqflite。
SaveTimingRecordOperationPreviewResponse buildSensitiveResponse({
  bool withFreshness = true,
}) {
  final affectedEntities = <OperationEntityRef>[
    const OperationEntityRef(
      entityType: 'device',
      entityId: '42',
      label: _deviceName,
      deviceId: '42',
    ),
    const OperationEntityRef(
      entityType: 'timing_record',
      entityId: '101',
      label: '计时记录 101',
      projectId: _oldProjectId,
      deviceId: '42',
    ),
    const OperationEntityRef(
      entityType: 'project',
      entityId: _oldProjectId,
      label: _projectLabel,
      projectId: _oldProjectId,
    ),
    const OperationEntityRef(
      entityType: 'project',
      entityId: 'new:$_legacyKey',
      label: _projectLabel,
    ),
    const OperationEntityRef(
      entityType: 'merge_group',
      entityId: '$_mergeGroupId',
      label: '合并项目 $_mergeGroupId',
    ),
  ];

  final warnings = <String>[
    '保存后将自动解除受影响的合并项目。',
    '保存后将自动撤销不再成立的结清状态。',
    '当前记录指向的项目 $_oldProjectId 不存在，请刷新后再试。',
    '预览基于当前本地数据，执行前必须重新分析确认。',
  ];

  final preview = OperationPreview(
    operationId: 'op-1',
    operationType: OperationType.saveTimingRecord,
    title: '修改计时记录',
    summary: '编辑计时；设备：$_deviceName；项目：$_projectLabel；'
        '项目归属：老板 · 旧址 -> $_projectLabel',
    warnings: warnings,
    affectedEntities: affectedEntities,
    impactItems: [
      OperationImpactItem(
        title: '项目归属将变化',
        description: '项目归属：老板 · 旧址 -> $_projectLabel',
        severity: OperationImpactSeverity.warning,
        affectedEntities: affectedEntities,
        code: 'project_changed',
      ),
      const OperationImpactItem(
        title: '将自动解除相关合并项目',
        description: '保存后，受影响的合并项目会自动解除，以避免账务口径错误。',
        severity: OperationImpactSeverity.warning,
        code: 'merge_dissolve',
      ),
      const OperationImpactItem(
        title: '将自动撤销结清状态',
        description: '保存后，受影响项目如果不再满足结清条件，会自动恢复为进行中。',
        severity: OperationImpactSeverity.warning,
        code: 'settlement_revoke',
      ),
    ],
    requiresConfirmation: true,
    riskLevel: OperationRiskLevel.high,
  );

  final previewInput = SaveTimingRecordOperationPreviewInput(
    operationId: 'op-1',
    isEditing: true,
    timingRecordId: '101',
    deviceLabel: _deviceName,
    projectLabel: _projectLabel,
    oldProjectLabel: '老板 · 旧址',
    newProjectLabel: _projectLabel,
    projectChanged: true,
    willDissolveMerge: true,
    willRevokeSettlement: true,
    affectedEntities: affectedEntities,
    warnings: warnings,
  );

  final analysis = SaveTimingRecordOperationAnalyzeResult(
    previewInput: previewInput,
    preview: preview,
    oldProjectId: _oldProjectId,
    existingNewProjectId: _newProjectId,
    wouldCreateNewProject: false,
    affectedProjectIds: const [_oldProjectId, _newProjectId],
    mergeGroupIdsToDissolve: const [_mergeGroupId],
    requiresReanalysisBeforeExecute: true,
    warnings: warnings,
  );

  final freshness = withFreshness
      ? SaveTimingRecordFreshnessVerdict(
          isFresh: false,
          latest: null,
          staleReasons: const [
            SaveTimingRecordStaleReason(
              type: SaveTimingRecordStaleReasonType.oldProjectChanged,
              message: '旧项目身份: $_oldProjectId → $_newProjectId',
              previousValue: _oldProjectId,
              latestValue: _newProjectId,
            ),
          ],
        )
      : null;

  return SaveTimingRecordOperationPreviewResponse(
    analysis: analysis,
    preview: preview,
    freshness: freshness,
  );
}

/// 把脱敏结果整体序列化为字符串，供泄漏断言扫描。
///
/// 用 jsonEncode 而非 Map.toString()：JSON 会给 key 加引号
/// （`"would_create_new_project":null`），因此 `"project:"` 这类裸前缀只会命中
/// **真实字符串值**（例如 `"project:aaa"`），不会被结构性 key 边界误伤。
/// jsonEncode 默认不转义非 ASCII，中文原文（联系人 / 工地）仍可被扫描到。
String serialize(RedactedSaveTimingRecordPreview redacted) =>
    jsonEncode(redacted.toMap());

void assertNoSensitiveLeak(RedactedSaveTimingRecordPreview redacted) {
  final text = serialize(redacted);
  for (final needle in <String>[
    _contact,
    _site,
    'project:',
    _legacyKey,
    '$_mergeGroupId',
    '结清',
    '核销',
  ]) {
    expect(
      text.contains(needle),
      isFalse,
      reason: 'redacted output must not leak "$needle"; got: $text',
    );
  }
}

void main() {
  const redactor = SaveTimingRecordPreviewRedactor();

  group('owner', () {
    test('receives unredacted preview (passthrough)', () {
      final response = buildSensitiveResponse();
      final owner = ActorContext(actorType: OperationActorType.owner);

      final result = redactor.redact(response: response, actor: owner);

      expect(result.redacted, isFalse);
      expect(result.redactionReasons, isEmpty);
      // project label / contact / site 保留
      expect(result.preview.summary, contains(_projectLabel));
      // project / merge entity 保留
      expect(
        result.preview.affectedEntities.any((e) => e.entityType == 'project'),
        isTrue,
      );
      // 财务信号保留
      expect(result.analysis.willRevokeSettlement, isTrue);
      expect(result.analysis.oldProjectId, _oldProjectId);
      expect(result.analysis.existingNewProjectId, _newProjectId);
      expect(result.analysis.affectedProjectIds, [_oldProjectId, _newProjectId]);
      expect(result.analysis.mergeGroupIdsToDissolve, [_mergeGroupId]);
      // freshness 原始 message / previousValue / latestValue 保留
      final reason = result.freshness!.staleReasons.single;
      expect(reason.message, contains(_oldProjectId));
      expect(reason.previousValue, _oldProjectId);
      expect(reason.latestValue, _newProjectId);
      // owner 可见全部能力
      expect(
        result.visibleCapabilities.toSet(),
        OperationVisibilityCapability.values.toSet(),
      );
      expect(result.hiddenCapabilities, isEmpty);
    });
  });

  group('driver', () {
    ActorContext driver() => ActorContext(
          actorType: OperationActorType.driver,
          actorId: 'driver-1',
        );

    test('redacts project / contact / site / finance / internal ids', () {
      final response = buildSensitiveResponse();
      final result = redactor.redact(response: response, actor: driver());

      expect(result.redacted, isTrue);

      // summary 只保留设备 + 模式
      expect(result.preview.summary, '编辑计时；设备：$_deviceName');
      expect(result.preview.summary, contains(_deviceName));
      expect(result.preview.summary, isNot(contains(_contact)));
      expect(result.preview.summary, isNot(contains(_site)));

      // affectedEntities：只剩 device，且内部 id 被剥离
      expect(result.preview.affectedEntities, hasLength(1));
      final deviceEntity = result.preview.affectedEntities.single;
      expect(deviceEntity.entityType, 'device');
      expect(deviceEntity.entityId, 'device:hidden');
      expect(deviceEntity.label, _deviceName);
      expect(deviceEntity.projectId, isNull);
      expect(deviceEntity.deviceId, isNull);

      // impactItems：删除 settlement_revoke / project_changed；合并影响泛化
      expect(
        result.preview.impactItems.map((i) => i.code).toList(),
        ['project_structure'],
      );

      // 财务信号隐藏
      expect(result.analysis.willRevokeSettlement, isNull);
      // 内部 id 剥离
      expect(result.analysis.oldProjectId, isNull);
      expect(result.analysis.existingNewProjectId, isNull);
      expect(result.analysis.affectedProjectIds, isEmpty);
      expect(result.analysis.mergeGroupIdsToDissolve, isEmpty);
      expect(result.analysis.wouldCreateNewProject, isNull);
      // 合并结构标志保留（用于泛化提示）
      expect(result.analysis.willDissolveMerge, isTrue);

      // freshness：仅保留 type
      final reason = result.freshness!.staleReasons.single;
      expect(reason.type, SaveTimingRecordStaleReasonType.oldProjectChanged);
      expect(reason.message, isNull);
      expect(reason.previousValue, isNull);
      expect(reason.latestValue, isNull);

      // hidden capabilities 至少包含项目 / 财务 / audit
      expect(
        result.hiddenCapabilities,
        containsAll(<OperationVisibilityCapability>[
          OperationVisibilityCapability.projectLabel,
          OperationVisibilityCapability.contactSite,
          OperationVisibilityCapability.financialAmount,
          OperationVisibilityCapability.payment,
          OperationVisibilityCapability.writeOff,
          OperationVisibilityCapability.profit,
          OperationVisibilityCapability.auditDetail,
        ]),
      );

      assertNoSensitiveLeak(result);
    });
  });

  group('partner', () {
    ActorContext partner() => ActorContext(
          actorType: OperationActorType.partner,
          actorId: 'partner-1',
        );

    test('redacts like driver: no contact/site/finance, merge generalized', () {
      final response = buildSensitiveResponse();
      final result = redactor.redact(response: response, actor: partner());

      expect(result.redacted, isTrue);
      expect(result.preview.summary, contains(_deviceName));
      expect(result.preview.summary, isNot(contains(_contact)));
      expect(result.preview.summary, isNot(contains(_site)));
      expect(
        result.preview.impactItems.map((i) => i.code).toList(),
        ['project_structure'],
      );
      expect(result.analysis.willRevokeSettlement, isNull);
      expect(result.analysis.affectedProjectIds, isEmpty);
      assertNoSensitiveLeak(result);
    });
  });

  group('agent', () {
    test('without delegated scope: minimal shell, no visible capabilities', () {
      final response = buildSensitiveResponse();
      final agent = ActorContext(
        actorType: OperationActorType.agent,
        actorId: 'agent-1',
      );

      final result = redactor.redact(response: response, actor: agent);

      expect(result.redacted, isTrue);
      expect(result.visibleCapabilities, isEmpty);
      expect(
        result.hiddenCapabilities.toSet(),
        OperationVisibilityCapability.values.toSet(),
      );
      // 最小空壳
      expect(result.preview.summary, isEmpty);
      expect(result.preview.affectedEntities, isEmpty);
      expect(result.preview.impactItems, isEmpty);
      expect(result.preview.warnings, isEmpty);
      expect(result.analysis.oldProjectId, isNull);
      expect(result.analysis.willRevokeSettlement, isNull);
      expect(result.analysis.willDissolveMerge, isFalse);
      assertNoSensitiveLeak(result);
    });

    test('delegated to owner: equivalent to owner (passthrough)', () {
      final response = buildSensitiveResponse();
      final agentAsOwner = ActorContext(
        actorType: OperationActorType.agent,
        actorId: 'agent-1',
        delegatedActorType: OperationActorType.owner,
        delegatedActorId: 'owner-1',
      );

      final result = redactor.redact(response: response, actor: agentAsOwner);

      expect(result.redacted, isFalse);
      expect(result.preview.summary, contains(_projectLabel));
      expect(result.analysis.willRevokeSettlement, isTrue);
      expect(result.analysis.oldProjectId, _oldProjectId);
      expect(result.freshness!.staleReasons.single.previousValue, _oldProjectId);
    });

    test('delegated to driver: equivalent to driver (redacted)', () {
      final response = buildSensitiveResponse();
      final agentAsDriver = ActorContext(
        actorType: OperationActorType.agent,
        actorId: 'agent-1',
        delegatedActorType: OperationActorType.driver,
        delegatedActorId: 'driver-1',
      );

      final result = redactor.redact(response: response, actor: agentAsDriver);

      expect(result.redacted, isTrue);
      expect(result.preview.summary, '编辑计时；设备：$_deviceName');
      expect(result.analysis.willRevokeSettlement, isNull);
      expect(result.analysis.affectedProjectIds, isEmpty);
      assertNoSensitiveLeak(result);
    });
  });

  group('immutability', () {
    test('original response is not mutated by redaction', () {
      final response = buildSensitiveResponse();

      // 快照原始值
      final origSummary = response.preview.summary;
      final origEntityCount = response.preview.affectedEntities.length;
      final origImpactCount = response.preview.impactItems.length;
      final origAffectedProjectIds =
          List<String>.from(response.analysis.affectedProjectIds);
      final origMergeIds =
          List<int>.from(response.analysis.mergeGroupIdsToDissolve);
      final origRevoke = response.analysis.previewInput.willRevokeSettlement;
      final origPrev = response.freshness!.staleReasons.single.previousValue;

      // 用 driver 触发最强脱敏
      redactor.redact(
        response: response,
        actor: ActorContext(
          actorType: OperationActorType.driver,
          actorId: 'driver-1',
        ),
      );

      expect(response.preview.summary, origSummary);
      expect(response.preview.affectedEntities.length, origEntityCount);
      expect(response.preview.impactItems.length, origImpactCount);
      expect(response.analysis.affectedProjectIds, origAffectedProjectIds);
      expect(response.analysis.mergeGroupIdsToDissolve, origMergeIds);
      expect(response.analysis.previewInput.willRevokeSettlement, origRevoke);
      expect(
        response.freshness!.staleReasons.single.previousValue,
        origPrev,
      );
    });
  });

  group('visibility metadata', () {
    test('driver visible/hidden capabilities match D23 policy', () {
      final response = buildSensitiveResponse();
      final result = redactor.redact(
        response: response,
        actor: ActorContext(
          actorType: OperationActorType.driver,
          actorId: 'driver-1',
        ),
      );

      expect(
        result.visibleCapabilities.toSet(),
        <OperationVisibilityCapability>{
          OperationVisibilityCapability.deviceName,
          OperationVisibilityCapability.timingBasic,
          OperationVisibilityCapability.exportDeviceWorkHours,
        },
      );
      // visible 与 hidden 互补且无交集
      expect(
        result.visibleCapabilities.toSet().intersection(
              result.hiddenCapabilities.toSet(),
            ),
        isEmpty,
      );
      expect(
        result.visibleCapabilities.length + result.hiddenCapabilities.length,
        OperationVisibilityCapability.values.length,
      );
    });
  });

  group('no freshness', () {
    test('redacted freshness is null when response has none', () {
      final response = buildSensitiveResponse(withFreshness: false);
      final ownerResult = redactor.redact(
        response: response,
        actor: ActorContext(actorType: OperationActorType.owner),
      );
      expect(ownerResult.freshness, isNull);

      final driverResult = redactor.redact(
        response: response,
        actor: ActorContext(
          actorType: OperationActorType.driver,
          actorId: 'd-1',
        ),
      );
      expect(driverResult.freshness, isNull);
    });
  });
}
