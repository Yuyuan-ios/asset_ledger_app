import 'dart:convert';

import 'package:asset_ledger/core/operations/operation_access_control.dart';
import 'package:asset_ledger/core/operations/operation_actor_scope.dart';
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
final _now = DateTime.utc(2026, 1, 1, 12);

/// 构造一份「敏感的」保存计时预览 response（编辑 + 改项目，可选解除合并 / 撤销结清）。
/// 纯内存构造，不使用 sqflite。
///
/// [willDissolveMerge] / [willRevokeSettlement] 默认都为 true（"全量"敏感场景）；
/// 把它们单独翻成 false，可构造 merge-only / settlement-only 场景，用于验证
/// riskLevel 侧信道（上游 command.preview 在任一为 true 时把风险升为 high）。
SaveTimingRecordOperationPreviewResponse buildSensitiveResponse({
  bool withFreshness = true,
  bool willDissolveMerge = true,
  bool willRevokeSettlement = true,
  bool includeDeviceEntity = true,
  bool includeTimingRecordEntity = true,
  String? timingRecordId = '101',
}) {
  final affectedEntities = <OperationEntityRef>[
    if (includeDeviceEntity)
      const OperationEntityRef(
        entityType: 'device',
        entityId: '42',
        label: _deviceName,
        deviceId: '42',
      ),
    if (includeTimingRecordEntity)
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
    if (willDissolveMerge)
      const OperationEntityRef(
        entityType: 'merge_group',
        entityId: '$_mergeGroupId',
        label: '合并项目 $_mergeGroupId',
      ),
  ];

  final warnings = <String>[
    if (willDissolveMerge) '保存后将自动解除受影响的合并项目。',
    if (willRevokeSettlement) '保存后将自动撤销不再成立的结清状态。',
    '当前记录指向的项目 $_oldProjectId 不存在，请刷新后再试。',
    '预览基于当前本地数据，执行前必须重新分析确认。',
  ];

  // 复刻 command.preview 的风险映射：任一影响为 true → high，否则 medium。
  final riskLevel = willDissolveMerge || willRevokeSettlement
      ? OperationRiskLevel.high
      : OperationRiskLevel.medium;

  final preview = OperationPreview(
    operationId: 'op-1',
    operationType: OperationType.saveTimingRecord,
    title: '修改计时记录',
    summary:
        '编辑计时；设备：$_deviceName；项目：$_projectLabel；'
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
      if (willDissolveMerge)
        const OperationImpactItem(
          title: '将自动解除相关合并项目',
          description: '保存后，受影响的合并项目会自动解除，以避免账务口径错误。',
          severity: OperationImpactSeverity.warning,
          code: 'merge_dissolve',
        ),
      if (willRevokeSettlement)
        const OperationImpactItem(
          title: '将自动撤销结清状态',
          description: '保存后，受影响项目如果不再满足结清条件，会自动恢复为进行中。',
          severity: OperationImpactSeverity.warning,
          code: 'settlement_revoke',
        ),
    ],
    requiresConfirmation: true,
    riskLevel: riskLevel,
  );

  final previewInput = SaveTimingRecordOperationPreviewInput(
    operationId: 'op-1',
    isEditing: true,
    timingRecordId: timingRecordId,
    deviceLabel: _deviceName,
    projectLabel: _projectLabel,
    oldProjectLabel: '老板 · 旧址',
    newProjectLabel: _projectLabel,
    projectChanged: true,
    willDissolveMerge: willDissolveMerge,
    willRevokeSettlement: willRevokeSettlement,
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
    mergeGroupIdsToDissolve: willDissolveMerge
        ? const [_mergeGroupId]
        : const [],
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

ActorScope ownerScope() => ActorScope.fullOwner(ownerId: 'owner-1');

ActorScope driverDeviceScope() =>
    ActorScope.devices(deviceIds: const ['42'], actorId: 'driver-1');

ActorScope driverTimingScope() => ActorScope.timingRecords(
  timingRecordIds: const ['101'],
  actorId: 'driver-1',
);

ActorScope partnerDeviceScope() =>
    ActorScope.devices(deviceIds: const ['42'], actorId: 'partner-1');

ActorScope deniedDeviceScope({required String actorId}) =>
    ActorScope.devices(deviceIds: const ['99'], actorId: actorId);

ActorScope expiredDeviceScope() => ActorScope.devices(
  deviceIds: const ['42'],
  actorId: 'driver-1',
  expiresAt: _now,
);

ActorScope emptyScope({String? actorId}) => ActorScope.empty(actorId: actorId);

void assertScopeDeniedNoLeak(RedactedSaveTimingRecordPreview result) {
  expect(result.scopeAllowed, isFalse);
  expect(result.redacted, isTrue);
  expect(result.scopeReasons, isNotEmpty);
  expect(result.visibleCapabilities, isEmpty);
  expect(
    result.hiddenCapabilities.toSet(),
    OperationVisibilityCapability.values.toSet(),
  );
  expect(result.preview.summary, '预览内容已隐藏');
  expect(result.preview.affectedEntities, isEmpty);
  expect(result.preview.impactItems, isEmpty);
  expect(result.preview.warnings, isEmpty);
  expect(result.freshness, isNull);
  expect(result.preview.riskLevel, OperationRiskLevel.medium);
  expect(result.analysis.oldProjectId, isNull);
  expect(result.analysis.existingNewProjectId, isNull);
  expect(result.analysis.affectedProjectIds, isEmpty);
  expect(result.analysis.mergeGroupIdsToDissolve, isEmpty);
  expect(result.analysis.willDissolveMerge, isFalse);
  expect(result.analysis.willRevokeSettlement, isNull);
  expect(result.analysis.wouldCreateNewProject, isNull);
  assertNoSensitiveLeak(result);
  final text = serialize(result);
  expect(text, isNot(contains(_deviceName)));
  expect(text, isNot(contains('42')));
  expect(text, isNot(contains('101')));
}

void main() {
  const redactor = SaveTimingRecordPreviewRedactor();

  RedactedSaveTimingRecordPreview redactFor({
    required SaveTimingRecordOperationPreviewResponse response,
    required ActorContext actor,
    required ActorScope scope,
  }) {
    return redactor.redact(
      response: response,
      actor: actor,
      scope: scope,
      now: _now,
    );
  }

  group('owner', () {
    test('receives unredacted preview (passthrough)', () {
      final response = buildSensitiveResponse();
      final owner = ActorContext(actorType: OperationActorType.owner);

      final result = redactFor(
        response: response,
        actor: owner,
        scope: ownerScope(),
      );

      expect(result.redacted, isFalse);
      expect(result.redactionReasons, isEmpty);
      // owner 直通：riskLevel 原样保留（high），不归一化
      expect(result.preview.riskLevel, OperationRiskLevel.high);
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
      expect(result.analysis.affectedProjectIds, [
        _oldProjectId,
        _newProjectId,
      ]);
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
    ActorContext driver() =>
        ActorContext(actorType: OperationActorType.driver, actorId: 'driver-1');

    test('redacts project / contact / site / finance / internal ids', () {
      final response = buildSensitiveResponse();
      final result = redactFor(
        response: response,
        actor: driver(),
        scope: driverDeviceScope(),
      );

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
      expect(result.preview.impactItems.map((i) => i.code).toList(), [
        'project_structure',
      ]);

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
      final result = redactFor(
        response: response,
        actor: partner(),
        scope: partnerDeviceScope(),
      );

      expect(result.redacted, isTrue);
      expect(result.preview.summary, contains(_deviceName));
      expect(result.preview.summary, isNot(contains(_contact)));
      expect(result.preview.summary, isNot(contains(_site)));
      expect(result.preview.impactItems.map((i) => i.code).toList(), [
        'project_structure',
      ]);
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

      final result = redactFor(
        response: response,
        actor: agent,
        scope: emptyScope(actorId: 'agent-1'),
      );

      expect(result.scopeReasons, ['no delegated actor scope']);
      assertScopeDeniedNoLeak(result);
    });

    test('delegated to owner: equivalent to owner (passthrough)', () {
      final response = buildSensitiveResponse();
      final agentAsOwner = ActorContext(
        actorType: OperationActorType.agent,
        actorId: 'agent-1',
        delegatedActorType: OperationActorType.owner,
        delegatedActorId: 'owner-1',
      );

      final result = redactFor(
        response: response,
        actor: agentAsOwner,
        scope: ownerScope(),
      );

      expect(result.redacted, isFalse);
      expect(result.preview.summary, contains(_projectLabel));
      expect(result.analysis.willRevokeSettlement, isTrue);
      expect(result.analysis.oldProjectId, _oldProjectId);
      expect(
        result.freshness!.staleReasons.single.previousValue,
        _oldProjectId,
      );
    });

    test('delegated to driver: equivalent to driver (redacted)', () {
      final response = buildSensitiveResponse();
      final agentAsDriver = ActorContext(
        actorType: OperationActorType.agent,
        actorId: 'agent-1',
        delegatedActorType: OperationActorType.driver,
        delegatedActorId: 'driver-1',
      );

      final result = redactFor(
        response: response,
        actor: agentAsDriver,
        scope: driverDeviceScope(),
      );

      expect(result.redacted, isTrue);
      expect(result.preview.summary, '编辑计时；设备：$_deviceName');
      expect(result.analysis.willRevokeSettlement, isNull);
      expect(result.analysis.affectedProjectIds, isEmpty);
      assertNoSensitiveLeak(result);
    });
  });

  group('scope policy', () {
    test('owner without fullOwner scope gets minimal shell', () {
      final response = buildSensitiveResponse();
      final result = redactFor(
        response: response,
        actor: ActorContext(actorType: OperationActorType.owner),
        scope: emptyScope(actorId: 'owner-1'),
      );

      expect(result.scopeReasons, ['scope missing']);
      assertScopeDeniedNoLeak(result);
    });

    test('driver outside device scope gets minimal shell', () {
      final response = buildSensitiveResponse();
      final result = redactFor(
        response: response,
        actor: ActorContext(
          actorType: OperationActorType.driver,
          actorId: 'driver-1',
        ),
        scope: deniedDeviceScope(actorId: 'driver-1'),
      );

      expect(result.scopeReasons, contains('device not in actor scope'));
      assertScopeDeniedNoLeak(result);
    });

    test(
      'driver can pass scope by timing record id when device entity is absent',
      () {
        final response = buildSensitiveResponse(includeDeviceEntity: false);
        final result = redactFor(
          response: response,
          actor: ActorContext(
            actorType: OperationActorType.driver,
            actorId: 'driver-1',
          ),
          scope: driverTimingScope(),
        );

        expect(result.scopeAllowed, isTrue);
        expect(result.scopeReasons, isEmpty);
        expect(result.redacted, isTrue);
        expect(result.preview.summary, '编辑计时；设备：$_deviceName');
        assertNoSensitiveLeak(result);
      },
    );

    test(
      'driver without device or timing record identifiers gets minimal shell',
      () {
        final response = buildSensitiveResponse(
          includeDeviceEntity: false,
          includeTimingRecordEntity: false,
          timingRecordId: null,
        );
        final result = redactFor(
          response: response,
          actor: ActorContext(
            actorType: OperationActorType.driver,
            actorId: 'driver-1',
          ),
          scope: driverDeviceScope(),
        );

        expect(result.scopeReasons, ['missing resource identifiers']);
        assertScopeDeniedNoLeak(result);
      },
    );

    test('partner outside shared device scope gets minimal shell', () {
      final response = buildSensitiveResponse();
      final result = redactFor(
        response: response,
        actor: ActorContext(
          actorType: OperationActorType.partner,
          actorId: 'partner-1',
        ),
        scope: deniedDeviceScope(actorId: 'partner-1'),
      );

      expect(result.scopeReasons, ['device not in actor scope']);
      assertScopeDeniedNoLeak(result);
    });

    test('expired scope gets minimal shell with generic reason', () {
      final response = buildSensitiveResponse();
      final result = redactFor(
        response: response,
        actor: ActorContext(
          actorType: OperationActorType.driver,
          actorId: 'driver-1',
        ),
        scope: expiredDeviceScope(),
      );

      expect(result.scopeReasons, ['scope expired']);
      assertScopeDeniedNoLeak(result);
    });
  });

  group('immutability', () {
    test('original response is not mutated by redaction', () {
      final response = buildSensitiveResponse();

      // 快照原始值
      final origSummary = response.preview.summary;
      final origEntityCount = response.preview.affectedEntities.length;
      final origImpactCount = response.preview.impactItems.length;
      final origAffectedProjectIds = List<String>.from(
        response.analysis.affectedProjectIds,
      );
      final origMergeIds = List<int>.from(
        response.analysis.mergeGroupIdsToDissolve,
      );
      final origRevoke = response.analysis.previewInput.willRevokeSettlement;
      final origPrev = response.freshness!.staleReasons.single.previousValue;

      // 用 driver 触发最强脱敏
      redactFor(
        response: response,
        actor: ActorContext(
          actorType: OperationActorType.driver,
          actorId: 'driver-1',
        ),
        scope: driverDeviceScope(),
      );

      expect(response.preview.summary, origSummary);
      expect(response.preview.affectedEntities.length, origEntityCount);
      expect(response.preview.impactItems.length, origImpactCount);
      expect(response.analysis.affectedProjectIds, origAffectedProjectIds);
      expect(response.analysis.mergeGroupIdsToDissolve, origMergeIds);
      expect(response.analysis.previewInput.willRevokeSettlement, origRevoke);
      expect(response.freshness!.staleReasons.single.previousValue, origPrev);
    });
  });

  group('visibility metadata', () {
    test('driver visible/hidden capabilities match D23 policy', () {
      final response = buildSensitiveResponse();
      final result = redactFor(
        response: response,
        actor: ActorContext(
          actorType: OperationActorType.driver,
          actorId: 'driver-1',
        ),
        scope: driverDeviceScope(),
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
      final ownerResult = redactFor(
        response: response,
        actor: ActorContext(actorType: OperationActorType.owner),
        scope: ownerScope(),
      );
      expect(ownerResult.freshness, isNull);

      final driverResult = redactFor(
        response: response,
        actor: ActorContext(
          actorType: OperationActorType.driver,
          actorId: 'd-1',
        ),
        scope: ActorScope.devices(deviceIds: const ['42'], actorId: 'd-1'),
      );
      expect(driverResult.freshness, isNull);
    });
  });

  // D26.5：堵住 riskLevel 侧信道。上游 command.preview 在 willRevokeSettlement
  // 或 willDissolveMerge 为 true 时把风险升为 high。非 owner 一律归一化为 medium，
  // 避免仅凭 riskLevel 反推出被隐藏的撤销结清 / 合并结构状态。
  group('riskLevel side-channel (settlement-only)', () {
    // settlement-only：撤销结清=true、解除合并=false → 上游 riskLevel=high。
    SaveTimingRecordOperationPreviewResponse settlementOnly() =>
        buildSensitiveResponse(
          willDissolveMerge: false,
          willRevokeSettlement: true,
        );

    void expectSettlementFullyHidden(ActorContext actor, ActorScope scope) {
      final response = settlementOnly();
      // 前置确认：上游确实是 high，否则本测试无意义。
      expect(response.preview.riskLevel, OperationRiskLevel.high);

      final result = redactFor(response: response, actor: actor, scope: scope);

      // 归一化为 medium：不得透传 high。
      expect(result.preview.riskLevel, OperationRiskLevel.medium);
      // 没有解除合并 → 无任何残留影响项 / 合并提示。
      expect(result.preview.impactItems, isEmpty);
      expect(result.preview.warnings, ['预览基于当前本地数据，执行前必须重新分析确认。']);
      // 财务信号隐藏，合并标志为 false。
      expect(result.analysis.willRevokeSettlement, isNull);
      expect(result.analysis.willDissolveMerge, isFalse);
      // 至此 riskLevel / impactItems / warnings / analysis / freshness 都不再
      // 暴露结清状态。
      assertNoSensitiveLeak(result);
    }

    test('driver cannot infer settlement revoke from riskLevel', () {
      expectSettlementFullyHidden(
        ActorContext(actorType: OperationActorType.driver, actorId: 'driver-1'),
        driverDeviceScope(),
      );
    });

    test('partner cannot infer settlement revoke from riskLevel', () {
      expectSettlementFullyHidden(
        ActorContext(
          actorType: OperationActorType.partner,
          actorId: 'partner-1',
        ),
        partnerDeviceScope(),
      );
    });

    test('agent-as-driver cannot infer settlement revoke from riskLevel', () {
      expectSettlementFullyHidden(
        ActorContext(
          actorType: OperationActorType.agent,
          actorId: 'agent-1',
          delegatedActorType: OperationActorType.driver,
          delegatedActorId: 'driver-1',
        ),
        driverDeviceScope(),
      );
    });

    test('agent without scope also gets normalized medium (none path)', () {
      final response = settlementOnly();
      final result = redactFor(
        response: response,
        actor: ActorContext(
          actorType: OperationActorType.agent,
          actorId: 'agent-1',
        ),
        scope: emptyScope(actorId: 'agent-1'),
      );
      expect(result.preview.riskLevel, OperationRiskLevel.medium);
      assertNoSensitiveLeak(result);
    });
  });

  group('riskLevel normalization (merge-only)', () {
    test('non-owner never sees high even when merge note is surfaced', () {
      // merge-only：解除合并=true、撤销结清=false → 上游 riskLevel=high。
      final response = buildSensitiveResponse(
        willDissolveMerge: true,
        willRevokeSettlement: false,
      );
      expect(response.preview.riskLevel, OperationRiskLevel.high);

      final result = redactFor(
        response: response,
        actor: ActorContext(
          actorType: OperationActorType.driver,
          actorId: 'driver-1',
        ),
        scope: driverDeviceScope(),
      );

      // "normalize harder"：即便合并提示被泛化展示，riskLevel 仍归一化为 medium。
      expect(result.preview.riskLevel, OperationRiskLevel.medium);
      // 合并结构提示仍然展示（泛化），合并标志保留。
      expect(result.preview.impactItems.map((i) => i.code).toList(), [
        'project_structure',
      ]);
      expect(result.analysis.willDissolveMerge, isTrue);
      assertNoSensitiveLeak(result);
    });
  });

  group('agent-as-partner', () {
    test('delegated to partner: redacted like partner', () {
      final response = buildSensitiveResponse();
      final agentAsPartner = ActorContext(
        actorType: OperationActorType.agent,
        actorId: 'agent-1',
        delegatedActorType: OperationActorType.partner,
        delegatedActorId: 'partner-1',
      );

      final result = redactFor(
        response: response,
        actor: agentAsPartner,
        scope: partnerDeviceScope(),
      );

      expect(result.redacted, isTrue);
      expect(result.preview.summary, '编辑计时；设备：$_deviceName');
      expect(result.preview.riskLevel, OperationRiskLevel.medium);
      expect(result.analysis.willRevokeSettlement, isNull);
      expect(result.analysis.affectedProjectIds, isEmpty);
      // 与 partner 一致的可见能力集合
      expect(
        result.visibleCapabilities.toSet(),
        <OperationVisibilityCapability>{
          OperationVisibilityCapability.deviceName,
          OperationVisibilityCapability.timingBasic,
          OperationVisibilityCapability.exportDeviceWorkHours,
        },
      );
      assertNoSensitiveLeak(result);
    });
  });
}
