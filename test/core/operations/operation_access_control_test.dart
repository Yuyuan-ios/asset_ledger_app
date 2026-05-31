import 'package:asset_ledger/core/operations/operation_access_control.dart';
import 'package:asset_ledger/core/operations/operation_actor_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ActorContext', () {
    test('owner may omit actorId', () {
      final owner = ActorContext(actorType: OperationActorType.owner);
      expect(owner.isOwner, isTrue);
      expect(owner.actorId, isNull);
      expect(owner.requiresActorId, isFalse);
    });

    test('driver / partner / agent require actorId', () {
      for (final type in [
        OperationActorType.driver,
        OperationActorType.partner,
      ]) {
        expect(
          () => ActorContext(actorType: type),
          throwsArgumentError,
          reason: '${type.wireName} must require actorId',
        );
        final ok = ActorContext(actorType: type, actorId: 'a-1');
        expect(ok.requiresActorId, isTrue);
        expect(ok.actorId, 'a-1');
      }
      expect(
        () => ActorContext(actorType: OperationActorType.agent),
        throwsArgumentError,
      );
    });

    test('agent requires delegated actor scope to act for someone else', () {
      // 没有 delegated scope：仍可构造（保留为“裸 agent”），但
      // hasDelegatedScope=false，effectiveActorType=agent。
      final bareAgent = ActorContext(
        actorType: OperationActorType.agent,
        actorId: 'agent-1',
      );
      expect(bareAgent.hasDelegatedScope, isFalse);
      expect(bareAgent.effectiveActorType, OperationActorType.agent);

      // 仅给了 type 或仅给了 id：拒绝。
      expect(
        () => ActorContext(
          actorType: OperationActorType.agent,
          actorId: 'agent-1',
          delegatedActorType: OperationActorType.owner,
        ),
        throwsArgumentError,
      );
      expect(
        () => ActorContext(
          actorType: OperationActorType.agent,
          actorId: 'agent-1',
          delegatedActorId: 'owner-1',
        ),
        throwsArgumentError,
      );

      // 同时给了 type + id：成立。
      final delegated = ActorContext(
        actorType: OperationActorType.agent,
        actorId: 'agent-1',
        delegatedActorType: OperationActorType.owner,
        delegatedActorId: 'owner-1',
      );
      expect(delegated.hasDelegatedScope, isTrue);
      expect(delegated.effectiveActorType, OperationActorType.owner);
    });

    test('agent cannot delegate to another agent or unknown', () {
      expect(
        () => ActorContext(
          actorType: OperationActorType.agent,
          actorId: 'agent-1',
          delegatedActorType: OperationActorType.agent,
          delegatedActorId: 'agent-2',
        ),
        throwsArgumentError,
      );
      expect(
        () => ActorContext(
          actorType: OperationActorType.agent,
          actorId: 'agent-1',
          delegatedActorType: OperationActorType.unknown,
          delegatedActorId: 'x',
        ),
        throwsArgumentError,
      );
    });

    test('non-agent actors cannot carry delegated scope', () {
      expect(
        () => ActorContext(
          actorType: OperationActorType.owner,
          delegatedActorType: OperationActorType.driver,
          delegatedActorId: 'd-1',
        ),
        throwsArgumentError,
      );
    });

    test('unknown actor is constructible but signals legacy only', () {
      final unknown = ActorContext(actorType: OperationActorType.unknown);
      expect(unknown.isUnknown, isTrue);
      expect(unknown.requiresActorId, isFalse);
    });

    test('toMap / fromMap round-trip preserves all fields', () {
      final actor = ActorContext(
        actorType: OperationActorType.agent,
        actorId: 'agent-1',
        delegatedActorType: OperationActorType.driver,
        delegatedActorId: 'driver-7',
        sessionId: 'session-abc',
        source: 'mcp',
      );
      final restored = ActorContext.fromMap(actor.toMap());
      expect(restored.actorType, actor.actorType);
      expect(restored.actorId, actor.actorId);
      expect(restored.delegatedActorType, actor.delegatedActorType);
      expect(restored.delegatedActorId, actor.delegatedActorId);
      expect(restored.sessionId, actor.sessionId);
      expect(restored.source, actor.source);
      expect(restored.hasDelegatedScope, isTrue);
      expect(restored.effectiveActorType, OperationActorType.driver);
    });

    test('fromMap throws on missing actor_type', () {
      expect(
        () => ActorContext.fromMap(const {}),
        throwsArgumentError,
      );
    });

    test('fromMap throws on unknown actor_type wireName', () {
      expect(
        () => ActorContext.fromMap(const {'actor_type': 'super_admin'}),
        throwsArgumentError,
      );
    });
  });

  group('OperationPermissionAction', () {
    test('wireName round-trips for every value', () {
      for (final action in OperationPermissionAction.values) {
        expect(
          OperationPermissionAction.fromWireName(action.wireName),
          action,
        );
        expect(
          OperationPermissionAction.tryParse(action.wireName),
          action,
        );
      }
    });

    test('wire codes are stable snake_case', () {
      expect(
        OperationPermissionAction.previewSaveTimingRecord.wireName,
        'preview_save_timing_record',
      );
      expect(
        OperationPermissionAction.executeSaveTimingRecord.wireName,
        'execute_save_timing_record',
      );
      expect(
        OperationPermissionAction.exportDeviceWorkHours.wireName,
        'export_device_work_hours',
      );
      expect(
        OperationPermissionAction.restoreBackup.wireName,
        'restore_backup',
      );
    });

    test('unknown wireName: tryParse → null, fromWireName → throws', () {
      expect(OperationPermissionAction.tryParse('nope'), isNull);
      expect(
        () => OperationPermissionAction.fromWireName('nope'),
        throwsArgumentError,
      );
    });

    test('high-risk classification covers destructive / settlement actions', () {
      const highRisk = {
        OperationPermissionAction.deleteTimingRecord,
        OperationPermissionAction.settleProject,
        OperationPermissionAction.writeOffProject,
        OperationPermissionAction.linkExternalWork,
        OperationPermissionAction.importExternalWork,
        OperationPermissionAction.restoreBackup,
      };
      for (final action in OperationPermissionAction.values) {
        expect(
          action.isHighRisk,
          highRisk.contains(action),
          reason: 'isHighRisk mismatch for ${action.wireName}',
        );
      }
    });

    test('read / preview / write classifications are disjoint where expected', () {
      for (final action in OperationPermissionAction.values) {
        expect(
          action.isReadOnly && action.isWrite,
          isFalse,
          reason: '${action.wireName} cannot be both read-only and write',
        );
      }
      expect(
        OperationPermissionAction.previewSaveTimingRecord.isPreview,
        isTrue,
      );
      expect(
        OperationPermissionAction.executeSaveTimingRecord.isWrite,
        isTrue,
      );
      expect(
        OperationPermissionAction.readDevice.isReadOnly,
        isTrue,
      );
    });
  });

  group('OperationPermissionPolicy / owner', () {
    const policy = OperationPermissionPolicy();
    final owner = ActorContext(actorType: OperationActorType.owner);

    test('owner may preview save timing record', () {
      final d = policy.canPerform(
        actor: owner,
        action: OperationPermissionAction.previewSaveTimingRecord,
      );
      expect(d.allowed, isTrue);
      expect(d.requiresConfirmation, isFalse);
    });

    test('owner may execute save timing record (low-risk write, no confirm required by policy)', () {
      final d = policy.canPerform(
        actor: owner,
        action: OperationPermissionAction.executeSaveTimingRecord,
      );
      expect(d.allowed, isTrue);
      // executeSaveTimingRecord 不在 high-risk 集合里 → policy 不强制 confirm。
      // 实际链路是否走 preview 由 command 决定（D8 手动保存目前直接落库）。
      expect(d.requiresConfirmation, isFalse);
    });

    test('owner high-risk actions are allowed but require confirmation', () {
      const highRiskActions = [
        OperationPermissionAction.deleteTimingRecord,
        OperationPermissionAction.settleProject,
        OperationPermissionAction.writeOffProject,
        OperationPermissionAction.linkExternalWork,
        OperationPermissionAction.importExternalWork,
        OperationPermissionAction.restoreBackup,
      ];
      for (final action in highRiskActions) {
        final d = policy.canPerform(actor: owner, action: action);
        expect(d.allowed, isTrue, reason: 'owner should be allowed: ${action.wireName}');
        expect(
          d.requiresConfirmation,
          isTrue,
          reason: 'owner high-risk must require confirmation: ${action.wireName}',
        );
      }
    });

    test('owner may read audit / export work hours', () {
      expect(
        policy
            .canPerform(
              actor: owner,
              action: OperationPermissionAction.readAudit,
            )
            .allowed,
        isTrue,
      );
      expect(
        policy
            .canPerform(
              actor: owner,
              action: OperationPermissionAction.exportDeviceWorkHours,
            )
            .allowed,
        isTrue,
      );
    });
  });

  group('OperationPermissionPolicy / driver', () {
    const policy = OperationPermissionPolicy();
    final driver = ActorContext(
      actorType: OperationActorType.driver,
      actorId: 'driver-1',
    );

    test('driver may preview save timing record', () {
      final d = policy.canPerform(
        actor: driver,
        action: OperationPermissionAction.previewSaveTimingRecord,
      );
      expect(d.allowed, isTrue);
    });

    test('driver may read device / timing / export work hours', () {
      const allowed = [
        OperationPermissionAction.readDevice,
        OperationPermissionAction.readTimingRecord,
        OperationPermissionAction.exportDeviceWorkHours,
      ];
      for (final action in allowed) {
        expect(
          policy.canPerform(actor: driver, action: action).allowed,
          isTrue,
          reason: 'driver should be allowed: ${action.wireName}',
        );
      }
    });

    test('driver cannot execute save (review workflow not yet implemented)', () {
      final d = policy.canPerform(
        actor: driver,
        action: OperationPermissionAction.executeSaveTimingRecord,
      );
      expect(d.allowed, isFalse);
      expect(d.reason, isNotEmpty);
    });

    test('driver cannot delete / settle / write-off / restore / import / link', () {
      const deniedActions = [
        OperationPermissionAction.deleteTimingRecord,
        OperationPermissionAction.settleProject,
        OperationPermissionAction.writeOffProject,
        OperationPermissionAction.linkExternalWork,
        OperationPermissionAction.importExternalWork,
        OperationPermissionAction.restoreBackup,
      ];
      for (final action in deniedActions) {
        expect(
          policy.canPerform(actor: driver, action: action).allowed,
          isFalse,
          reason: 'driver should be denied: ${action.wireName}',
        );
      }
    });

    test('driver cannot see project / external work / audit details', () {
      const deniedReads = [
        OperationPermissionAction.readProject,
        OperationPermissionAction.readExternalWork,
        OperationPermissionAction.readAudit,
      ];
      for (final action in deniedReads) {
        expect(
          policy.canPerform(actor: driver, action: action).allowed,
          isFalse,
          reason: 'driver should be denied read: ${action.wireName}',
        );
      }
    });
  });

  group('OperationPermissionPolicy / partner', () {
    const policy = OperationPermissionPolicy();
    final partner = ActorContext(
      actorType: OperationActorType.partner,
      actorId: 'partner-1',
    );

    test('partner may read shared device / timing / export', () {
      const allowed = [
        OperationPermissionAction.readDevice,
        OperationPermissionAction.readTimingRecord,
        OperationPermissionAction.exportDeviceWorkHours,
      ];
      for (final action in allowed) {
        expect(
          policy.canPerform(actor: partner, action: action).allowed,
          isTrue,
          reason: 'partner should be allowed: ${action.wireName}',
        );
      }
    });

    test('partner cannot preview or execute save', () {
      const denied = [
        OperationPermissionAction.previewSaveTimingRecord,
        OperationPermissionAction.executeSaveTimingRecord,
      ];
      for (final action in denied) {
        expect(
          policy.canPerform(actor: partner, action: action).allowed,
          isFalse,
          reason: 'partner should be denied: ${action.wireName}',
        );
      }
    });

    test('partner cannot perform high-risk / finance actions', () {
      const denied = [
        OperationPermissionAction.deleteTimingRecord,
        OperationPermissionAction.settleProject,
        OperationPermissionAction.writeOffProject,
        OperationPermissionAction.linkExternalWork,
        OperationPermissionAction.importExternalWork,
        OperationPermissionAction.restoreBackup,
      ];
      for (final action in denied) {
        expect(
          policy.canPerform(actor: partner, action: action).allowed,
          isFalse,
          reason: 'partner should be denied: ${action.wireName}',
        );
      }
    });
  });

  group('OperationPermissionPolicy / agent', () {
    const policy = OperationPermissionPolicy();

    test('agent without delegated scope is denied everything', () {
      final agent = ActorContext(
        actorType: OperationActorType.agent,
        actorId: 'agent-1',
      );
      for (final action in OperationPermissionAction.values) {
        final d = policy.canPerform(actor: agent, action: action);
        expect(
          d.allowed,
          isFalse,
          reason: 'agent without scope must be denied: ${action.wireName}',
        );
      }
    });

    test('agent delegated to owner may preview, but cannot execute writes', () {
      final agent = ActorContext(
        actorType: OperationActorType.agent,
        actorId: 'agent-1',
        delegatedActorType: OperationActorType.owner,
        delegatedActorId: 'owner-1',
      );

      final preview = policy.canPerform(
        actor: agent,
        action: OperationPermissionAction.previewSaveTimingRecord,
      );
      expect(preview.allowed, isTrue);

      final exec = policy.canPerform(
        actor: agent,
        action: OperationPermissionAction.executeSaveTimingRecord,
      );
      expect(exec.allowed, isFalse, reason: 'agent must not directly execute writes');

      final settle = policy.canPerform(
        actor: agent,
        action: OperationPermissionAction.settleProject,
      );
      expect(settle.allowed, isFalse);

      final restore = policy.canPerform(
        actor: agent,
        action: OperationPermissionAction.restoreBackup,
      );
      expect(restore.allowed, isFalse);
    });

    test('agent delegated to driver may read driver-scoped data only', () {
      final agent = ActorContext(
        actorType: OperationActorType.agent,
        actorId: 'agent-1',
        delegatedActorType: OperationActorType.driver,
        delegatedActorId: 'driver-1',
      );
      expect(
        policy
            .canPerform(
              actor: agent,
              action: OperationPermissionAction.readTimingRecord,
            )
            .allowed,
        isTrue,
      );
      expect(
        policy
            .canPerform(
              actor: agent,
              action: OperationPermissionAction.readAudit,
            )
            .allowed,
        isFalse,
      );
    });
  });

  group('OperationPermissionPolicy / system + unknown', () {
    const policy = OperationPermissionPolicy();

    test('system is denied except for readAudit', () {
      final sys = ActorContext(actorType: OperationActorType.system);
      expect(
        policy
            .canPerform(
              actor: sys,
              action: OperationPermissionAction.readAudit,
            )
            .allowed,
        isTrue,
      );
      for (final action in OperationPermissionAction.values) {
        if (action == OperationPermissionAction.readAudit) continue;
        expect(
          policy.canPerform(actor: sys, action: action).allowed,
          isFalse,
          reason: 'system must be denied: ${action.wireName}',
        );
      }
    });

    test('unknown actor is denied every action', () {
      final u = ActorContext(actorType: OperationActorType.unknown);
      for (final action in OperationPermissionAction.values) {
        expect(
          policy.canPerform(actor: u, action: action).allowed,
          isFalse,
          reason: 'unknown must be denied: ${action.wireName}',
        );
      }
    });
  });

  group('OperationVisibilityCapability', () {
    test('wireName round-trips for every value', () {
      for (final cap in OperationVisibilityCapability.values) {
        expect(
          OperationVisibilityCapability.fromWireName(cap.wireName),
          cap,
        );
        expect(
          OperationVisibilityCapability.tryParse(cap.wireName),
          cap,
        );
      }
      expect(
        OperationVisibilityCapability.exportDeviceWorkHours.wireName,
        'export_device_work_hours',
      );
    });

    test('unknown wireName → null / throws', () {
      expect(OperationVisibilityCapability.tryParse('nope'), isNull);
      expect(
        () => OperationVisibilityCapability.fromWireName('nope'),
        throwsArgumentError,
      );
    });

    test('financial / project sensitive classifications', () {
      const financial = {
        OperationVisibilityCapability.financialAmount,
        OperationVisibilityCapability.payment,
        OperationVisibilityCapability.writeOff,
        OperationVisibilityCapability.profit,
      };
      for (final cap in OperationVisibilityCapability.values) {
        expect(
          cap.isFinancialSensitive,
          financial.contains(cap),
          reason: 'financial classification mismatch for ${cap.wireName}',
        );
      }
      expect(
        OperationVisibilityCapability.exportDeviceWorkHours.isExport,
        isTrue,
      );
    });
  });

  group('OperationVisibilityPolicy / owner', () {
    const policy = OperationVisibilityPolicy();
    final owner = ActorContext(actorType: OperationActorType.owner);

    test('owner sees every capability', () {
      for (final cap in OperationVisibilityCapability.values) {
        expect(
          policy.canSee(actor: owner, capability: cap).visible,
          isTrue,
          reason: 'owner should see ${cap.wireName}',
        );
      }
    });

    test('owner sees financial amount / profit / audit detail', () {
      const caps = [
        OperationVisibilityCapability.financialAmount,
        OperationVisibilityCapability.profit,
        OperationVisibilityCapability.auditDetail,
      ];
      for (final cap in caps) {
        expect(policy.canSee(actor: owner, capability: cap).visible, isTrue);
      }
    });
  });

  group('OperationVisibilityPolicy / driver', () {
    const policy = OperationVisibilityPolicy();
    final driver = ActorContext(
      actorType: OperationActorType.driver,
      actorId: 'driver-1',
    );

    test('driver sees deviceName / timingBasic / export', () {
      const visible = [
        OperationVisibilityCapability.deviceName,
        OperationVisibilityCapability.timingBasic,
        OperationVisibilityCapability.exportDeviceWorkHours,
      ];
      for (final cap in visible) {
        expect(
          policy.canSee(actor: driver, capability: cap).visible,
          isTrue,
          reason: 'driver should see ${cap.wireName}',
        );
      }
    });

    test('driver cannot see financial / payment / write-off / profit', () {
      const hidden = [
        OperationVisibilityCapability.financialAmount,
        OperationVisibilityCapability.payment,
        OperationVisibilityCapability.writeOff,
        OperationVisibilityCapability.profit,
      ];
      for (final cap in hidden) {
        expect(
          policy.canSee(actor: driver, capability: cap).visible,
          isFalse,
          reason: 'driver must not see ${cap.wireName}',
        );
      }
    });

    test('driver cannot see contactSite / projectLabel / externalWorkSource / auditDetail', () {
      const hidden = [
        OperationVisibilityCapability.contactSite,
        OperationVisibilityCapability.projectLabel,
        OperationVisibilityCapability.externalWorkSource,
        OperationVisibilityCapability.auditDetail,
      ];
      for (final cap in hidden) {
        expect(
          policy.canSee(actor: driver, capability: cap).visible,
          isFalse,
          reason: 'driver must not see ${cap.wireName}',
        );
      }
    });
  });

  group('OperationVisibilityPolicy / partner', () {
    const policy = OperationVisibilityPolicy();
    final partner = ActorContext(
      actorType: OperationActorType.partner,
      actorId: 'partner-1',
    );

    test('partner sees deviceName / timingBasic / export within shared scope', () {
      const visible = [
        OperationVisibilityCapability.deviceName,
        OperationVisibilityCapability.timingBasic,
        OperationVisibilityCapability.exportDeviceWorkHours,
      ];
      for (final cap in visible) {
        expect(
          policy.canSee(actor: partner, capability: cap).visible,
          isTrue,
          reason: 'partner should see ${cap.wireName}',
        );
      }
    });

    test('partner cannot see contactSite / projectLabel / externalWorkSource', () {
      const hidden = [
        OperationVisibilityCapability.contactSite,
        OperationVisibilityCapability.projectLabel,
        OperationVisibilityCapability.externalWorkSource,
      ];
      for (final cap in hidden) {
        expect(
          policy.canSee(actor: partner, capability: cap).visible,
          isFalse,
          reason: 'partner must not see ${cap.wireName}',
        );
      }
    });

    test('partner cannot see finance / audit detail', () {
      const hidden = [
        OperationVisibilityCapability.financialAmount,
        OperationVisibilityCapability.payment,
        OperationVisibilityCapability.writeOff,
        OperationVisibilityCapability.profit,
        OperationVisibilityCapability.auditDetail,
      ];
      for (final cap in hidden) {
        expect(
          policy.canSee(actor: partner, capability: cap).visible,
          isFalse,
          reason: 'partner must not see ${cap.wireName}',
        );
      }
    });
  });

  group('OperationVisibilityPolicy / agent + system + unknown', () {
    const policy = OperationVisibilityPolicy();

    test('agent without delegated scope sees nothing', () {
      final agent = ActorContext(
        actorType: OperationActorType.agent,
        actorId: 'agent-1',
      );
      for (final cap in OperationVisibilityCapability.values) {
        expect(
          policy.canSee(actor: agent, capability: cap).visible,
          isFalse,
          reason: 'agent without scope must not see ${cap.wireName}',
        );
      }
    });

    test('agent delegated to driver follows driver visibility', () {
      final agent = ActorContext(
        actorType: OperationActorType.agent,
        actorId: 'agent-1',
        delegatedActorType: OperationActorType.driver,
        delegatedActorId: 'driver-1',
      );
      expect(
        policy
            .canSee(
              actor: agent,
              capability: OperationVisibilityCapability.deviceName,
            )
            .visible,
        isTrue,
      );
      expect(
        policy
            .canSee(
              actor: agent,
              capability: OperationVisibilityCapability.financialAmount,
            )
            .visible,
        isFalse,
      );
    });

    test('agent delegated to owner sees everything', () {
      final agent = ActorContext(
        actorType: OperationActorType.agent,
        actorId: 'agent-1',
        delegatedActorType: OperationActorType.owner,
        delegatedActorId: 'owner-1',
      );
      for (final cap in OperationVisibilityCapability.values) {
        expect(
          policy.canSee(actor: agent, capability: cap).visible,
          isTrue,
          reason: 'agent-as-owner should see ${cap.wireName}',
        );
      }
    });

    test('system actor sees nothing in D23', () {
      final sys = ActorContext(actorType: OperationActorType.system);
      for (final cap in OperationVisibilityCapability.values) {
        expect(
          policy.canSee(actor: sys, capability: cap).visible,
          isFalse,
          reason: 'system must not see ${cap.wireName}',
        );
      }
    });

    test('unknown actor sees nothing', () {
      final u = ActorContext(actorType: OperationActorType.unknown);
      for (final cap in OperationVisibilityCapability.values) {
        expect(
          policy.canSee(actor: u, capability: cap).visible,
          isFalse,
          reason: 'unknown must not see ${cap.wireName}',
        );
      }
    });
  });

  group('Serialization of decisions', () {
    test('PermissionDecision.toMap carries all fields (allow)', () {
      const policy = OperationPermissionPolicy();
      final owner = ActorContext(actorType: OperationActorType.owner);
      final d = policy.canPerform(
        actor: owner,
        action: OperationPermissionAction.settleProject,
      );
      final map = d.toMap();
      expect(map['allowed'], isTrue);
      expect(map['requires_confirmation'], isTrue);
      expect(map['action'], 'settle_project');
      expect(map['actor_type'], 'owner');
      expect(map['reason'], isNotEmpty);
    });

    test('PermissionDecision.toMap carries all fields (deny)', () {
      const policy = OperationPermissionPolicy();
      final agent = ActorContext(
        actorType: OperationActorType.agent,
        actorId: 'agent-1',
      );
      final d = policy.canPerform(
        actor: agent,
        action: OperationPermissionAction.executeSaveTimingRecord,
      );
      final map = d.toMap();
      expect(map['allowed'], isFalse);
      expect(map['action'], 'execute_save_timing_record');
      expect(map['actor_type'], 'agent');
      expect(map['reason'], isNotEmpty);
    });

    test('PermissionDecision.deny rejects empty reason', () {
      expect(
        () => OperationPermissionDecision.deny(
          action: OperationPermissionAction.readDevice,
          actorType: OperationActorType.owner,
          reason: '',
        ),
        throwsArgumentError,
      );
    });

    test('VisibilityDecision.toMap carries all fields (visible)', () {
      const policy = OperationVisibilityPolicy();
      final owner = ActorContext(actorType: OperationActorType.owner);
      final d = policy.canSee(
        actor: owner,
        capability: OperationVisibilityCapability.profit,
      );
      final map = d.toMap();
      expect(map['visible'], isTrue);
      expect(map['capability'], 'profit');
      expect(map['actor_type'], 'owner');
    });

    test('VisibilityDecision.toMap carries all fields (hidden)', () {
      const policy = OperationVisibilityPolicy();
      final driver = ActorContext(
        actorType: OperationActorType.driver,
        actorId: 'd-1',
      );
      final d = policy.canSee(
        actor: driver,
        capability: OperationVisibilityCapability.financialAmount,
      );
      final map = d.toMap();
      expect(map['visible'], isFalse);
      expect(map['capability'], 'financial_amount');
      expect(map['actor_type'], 'driver');
      expect(map['reason'], isNotEmpty);
    });

    test('VisibilityDecision.hidden rejects empty reason', () {
      expect(
        () => OperationVisibilityDecision.hidden(
          capability: OperationVisibilityCapability.deviceName,
          actorType: OperationActorType.owner,
          reason: '',
        ),
        throwsArgumentError,
      );
    });
  });
}
