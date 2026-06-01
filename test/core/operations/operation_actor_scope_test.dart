import 'package:asset_ledger/core/operations/operation_access_control.dart';
import 'package:asset_ledger/core/operations/operation_actor_scope.dart';
import 'package:asset_ledger/core/operations/operation_actor_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 1, 1, 12);

  group('OperationResourceType / OperationResourceRef', () {
    test('enum wireName round-trips for every value', () {
      for (final type in OperationResourceType.values) {
        expect(OperationResourceType.fromWireName(type.wireName), type);
        expect(OperationResourceType.tryParse(type.wireName), type);
      }

      expect(OperationResourceType.timingRecord.wireName, 'timing_record');
      expect(
        OperationResourceType.externalPackage.wireName,
        'external_package',
      );
      expect(OperationResourceType.auditLog.wireName, 'audit_log');
      expect(OperationResourceType.tryParse('unknown_resource'), isNull);
      expect(
        () => OperationResourceType.fromWireName('unknown_resource'),
        throwsArgumentError,
      );
    });

    test('OperationResourceRef toMap / fromMap round-trips', () {
      final ref = OperationResourceRef(
        type: OperationResourceType.device,
        id: '  device-1  ',
      );

      expect(ref.id, 'device-1');
      expect(ref.toMap(), {'type': 'device', 'id': 'device-1'});

      final restored = OperationResourceRef.fromMap(ref.toMap());
      expect(restored, ref);
      expect(restored.hashCode, ref.hashCode);
    });

    test('empty id throws', () {
      expect(
        () =>
            OperationResourceRef(type: OperationResourceType.project, id: ' '),
        throwsArgumentError,
      );
      expect(
        () => OperationResourceRef.fromMap(const {'type': 'device', 'id': ''}),
        throwsArgumentError,
      );
    });

    test('equality supports Set de-duplication', () {
      final refs = <OperationResourceRef>{
        OperationResourceRef(type: OperationResourceType.device, id: '1'),
        OperationResourceRef(type: OperationResourceType.device, id: '1'),
        OperationResourceRef(type: OperationResourceType.project, id: '1'),
      };

      expect(refs, hasLength(2));
      expect(
        refs,
        contains(
          OperationResourceRef(type: OperationResourceType.device, id: '1'),
        ),
      );
    });
  });

  group('ActorScope', () {
    test('fullOwner represents full owner scope', () {
      final scope = ActorScope.fullOwner(
        ownerId: 'owner-1',
        actorId: 'owner-1',
        scopeSource: 'local_app',
      );

      expect(scope.isFullOwner, isTrue);
      expect(scope.isEmpty, isFalse);
      expect(scope.ownerId, 'owner-1');
      expect(scope.actorId, 'owner-1');
      expect(scope.scopeSource, 'local_app');
      expect(scope.hasDeviceScope, isFalse);
    });

    test('devices scope contains allowedDeviceIds', () {
      final scope = ActorScope.devices(
        deviceIds: const ['2', '1', '1'],
        actorId: 'driver-1',
        scopeSource: 'assignment',
      );

      expect(scope.isFullOwner, isFalse);
      expect(scope.isEmpty, isFalse);
      expect(scope.hasDeviceScope, isTrue);
      expect(scope.allowedDeviceIds, {'1', '2'});
      expect(scope.toMap()['allowed_device_ids'], ['1', '2']);
    });

    test(
      'projects / timingRecords / externalPackages scopes fill correct sets',
      () {
        final project = ActorScope.projects(projectIds: const ['project:1']);
        final timing = ActorScope.timingRecords(timingRecordIds: const ['101']);
        final external = ActorScope.externalPackages(
          externalPackageIds: const ['batch-1'],
        );

        expect(project.allowedProjectIds, {'project:1'});
        expect(project.hasProjectScope, isTrue);
        expect(timing.allowedTimingRecordIds, {'101'});
        expect(timing.hasTimingRecordScope, isTrue);
        expect(external.allowedExternalPackageIds, {'batch-1'});
        expect(external.hasExternalPackageScope, isTrue);
      },
    );

    test('empty scope isEmpty=true', () {
      final scope = ActorScope.empty(actorId: 'driver-1');

      expect(scope.isFullOwner, isFalse);
      expect(scope.isEmpty, isTrue);
      expect(scope.allowedDeviceIds, isEmpty);
      expect(scope.allowedProjectIds, isEmpty);
      expect(scope.allowedTimingRecordIds, isEmpty);
      expect(scope.allowedExternalPackageIds, isEmpty);
    });

    test('expiresAt / isExpired is exclusive at boundary', () {
      final future = ActorScope.devices(
        deviceIds: const ['1'],
        expiresAt: now.add(const Duration(seconds: 1)),
      );
      final exact = ActorScope.devices(deviceIds: const ['1'], expiresAt: now);
      final past = ActorScope.devices(
        deviceIds: const ['1'],
        expiresAt: now.subtract(const Duration(seconds: 1)),
      );

      expect(future.isExpired(now), isFalse);
      expect(exact.isExpired(now), isTrue);
      expect(past.isExpired(now), isTrue);
      expect(ActorScope.empty().isExpired(now), isFalse);
    });

    test('toMap / fromMap round-trip preserves sorted sets and metadata', () {
      final scope = _testCombinedScope(
        ownerId: 'owner-1',
        actorId: 'actor-1',
        allowedDeviceIds: const ['2', '1'],
        allowedProjectIds: const ['project:1'],
        allowedTimingRecordIds: const ['101'],
        allowedExternalPackageIds: const ['batch-1'],
        scopeSource: 'share',
        grantId: 'grant-1',
        expiresAt: now,
      );

      final map = scope.toMap();
      expect(map['allowed_device_ids'], ['1', '2']);
      expect(map['expires_at'], now.toIso8601String());

      final restored = ActorScope.fromMap(map);
      expect(restored.isFullOwner, scope.isFullOwner);
      expect(restored.ownerId, scope.ownerId);
      expect(restored.actorId, scope.actorId);
      expect(restored.allowedDeviceIds, scope.allowedDeviceIds);
      expect(restored.allowedProjectIds, scope.allowedProjectIds);
      expect(restored.allowedTimingRecordIds, scope.allowedTimingRecordIds);
      expect(
        restored.allowedExternalPackageIds,
        scope.allowedExternalPackageIds,
      );
      expect(restored.scopeSource, scope.scopeSource);
      expect(restored.grantId, scope.grantId);
      expect(restored.expiresAt, scope.expiresAt);
    });

    test('fromMap missing or invalid fields throws', () {
      expect(() => ActorScope.fromMap(const {}), throwsArgumentError);
      expect(
        () => ActorScope.fromMap(const {
          'full_owner': false,
          'allowed_device_ids': ['1'],
          'allowed_project_ids': ['p1'],
          'allowed_timing_record_ids': ['101'],
          'allowed_external_package_ids': ['batch-1'],
          'expires_at': 'not-a-date',
        }),
        throwsA(anything),
      );
      expect(
        () => ActorScope.devices(deviceIds: const ['1', ' ']),
        throwsArgumentError,
      );
    });
  });

  group('OperationScopePolicy', () {
    const policy = OperationScopePolicy();

    final owner = ActorContext(actorType: OperationActorType.owner);
    final driver = ActorContext(
      actorType: OperationActorType.driver,
      actorId: 'driver-1',
    );
    final partner = ActorContext(
      actorType: OperationActorType.partner,
      actorId: 'partner-1',
    );

    test('owner + fullOwner can access device / project / timing / report', () {
      final scope = ActorScope.fullOwner(ownerId: 'owner-1');

      for (final entry in const [
        (OperationResourceType.device, 'device-1'),
        (OperationResourceType.project, 'project-1'),
        (OperationResourceType.timingRecord, '101'),
        (OperationResourceType.report, 'device-hours'),
      ]) {
        final decision = policy.canAccessResource(
          actor: owner,
          scope: scope,
          resourceType: entry.$1,
          resourceId: entry.$2,
          now: now,
        );
        expect(decision.allowed, isTrue, reason: entry.$1.wireName);
      }
    });

    test('owner + explicit device scope can access only that device', () {
      final scope = ActorScope.devices(deviceIds: const ['device-1']);

      final allowed = policy.canAccessResource(
        actor: owner,
        scope: scope,
        resourceType: OperationResourceType.device,
        resourceId: 'device-1',
        now: now,
      );
      final otherDevice = policy.canAccessResource(
        actor: owner,
        scope: scope,
        resourceType: OperationResourceType.device,
        resourceId: 'device-2',
        now: now,
      );
      final report = policy.canAccessResource(
        actor: owner,
        scope: scope,
        resourceType: OperationResourceType.report,
        resourceId: 'device-hours',
        now: now,
      );

      expect(allowed.allowed, isTrue);
      expect(otherDevice.allowed, isFalse);
      expect(report.allowed, isFalse);
    });

    test('driver + device scope can access that device', () {
      final scope = ActorScope.devices(
        deviceIds: const ['device-1'],
        actorId: 'driver-1',
      );

      final allowed = policy.canAccessResource(
        actor: driver,
        scope: scope,
        resourceType: OperationResourceType.device,
        resourceId: 'device-1',
        now: now,
      );
      final denied = policy.canAccessResource(
        actor: driver,
        scope: scope,
        resourceType: OperationResourceType.device,
        resourceId: 'device-2',
        now: now,
      );

      expect(allowed.allowed, isTrue);
      expect(denied.allowed, isFalse);
    });

    test('driver without scope denies by default', () {
      final decision = policy.canAccessResource(
        actor: driver,
        scope: ActorScope.empty(actorId: 'driver-1'),
        resourceType: OperationResourceType.device,
        resourceId: 'device-1',
        now: now,
      );

      expect(decision.allowed, isFalse);
      expect(decision.reason, contains('empty actor scope'));
    });

    test(
      'driver cannot access project even when allowedProjectIds is present',
      () {
        final scope = ActorScope.projects(
          projectIds: const ['project-1'],
          actorId: 'driver-1',
        );

        final decision = policy.canAccessResource(
          actor: driver,
          scope: scope,
          resourceType: OperationResourceType.project,
          resourceId: 'project-1',
          now: now,
        );

        expect(decision.allowed, isFalse);
        expect(decision.reason, contains('driver cannot access project'));
      },
    );

    test('driver + timingRecord scope can access that record', () {
      final scope = ActorScope.timingRecords(
        timingRecordIds: const ['101'],
        actorId: 'driver-1',
      );

      final allowed = policy.canAccessResource(
        actor: driver,
        scope: scope,
        resourceType: OperationResourceType.timingRecord,
        resourceId: '101',
        now: now,
      );
      final denied = policy.canAccessResource(
        actor: driver,
        scope: scope,
        resourceType: OperationResourceType.timingRecord,
        resourceId: '102',
        now: now,
      );

      expect(allowed.allowed, isTrue);
      expect(denied.allowed, isFalse);
    });

    test('partner + device scope can access shared device', () {
      final scope = ActorScope.devices(
        deviceIds: const ['device-1'],
        actorId: 'partner-1',
      );

      final allowed = policy.canAccessResource(
        actor: partner,
        scope: scope,
        resourceType: OperationResourceType.device,
        resourceId: 'device-1',
        now: now,
      );
      final denied = policy.canAccessResource(
        actor: partner,
        scope: scope,
        resourceType: OperationResourceType.device,
        resourceId: 'device-2',
        now: now,
      );

      expect(allowed.allowed, isTrue);
      expect(denied.allowed, isFalse);
    });

    test('partner + externalPackage scope can access that package', () {
      final scope = ActorScope.externalPackages(
        externalPackageIds: const ['batch-1'],
        actorId: 'partner-1',
      );

      final allowed = policy.canAccessResource(
        actor: partner,
        scope: scope,
        resourceType: OperationResourceType.externalPackage,
        resourceId: 'batch-1',
        now: now,
      );
      final denied = policy.canAccessResource(
        actor: partner,
        scope: scope,
        resourceType: OperationResourceType.externalPackage,
        resourceId: 'batch-2',
        now: now,
      );

      expect(allowed.allowed, isTrue);
      expect(denied.allowed, isFalse);
    });

    test('partner without scope denies by default', () {
      final decision = policy.canAccessResource(
        actor: partner,
        scope: ActorScope.empty(actorId: 'partner-1'),
        resourceType: OperationResourceType.device,
        resourceId: 'device-1',
        now: now,
      );

      expect(decision.allowed, isFalse);
      expect(decision.reason, contains('empty actor scope'));
    });

    test('agent without delegated scope denies all scoped resources', () {
      final agent = ActorContext(
        actorType: OperationActorType.agent,
        actorId: 'agent-1',
      );
      final decision = policy.canAccessResource(
        actor: agent,
        scope: ActorScope.fullOwner(ownerId: 'owner-1'),
        resourceType: OperationResourceType.device,
        resourceId: 'device-1',
        now: now,
      );

      expect(decision.allowed, isFalse);
      expect(decision.reason, contains('agent without delegated scope'));
    });

    test('agent-as-owner + fullOwner follows owner scope', () {
      final agent = ActorContext(
        actorType: OperationActorType.agent,
        actorId: 'agent-1',
        delegatedActorType: OperationActorType.owner,
        delegatedActorId: 'owner-1',
      );
      final decision = policy.canAccessResource(
        actor: agent,
        scope: ActorScope.fullOwner(ownerId: 'owner-1'),
        resourceType: OperationResourceType.report,
        resourceId: 'device-hours',
        now: now,
      );

      expect(decision.allowed, isTrue);
    });

    test('agent-as-driver + device scope follows driver rules', () {
      final agent = ActorContext(
        actorType: OperationActorType.agent,
        actorId: 'agent-1',
        delegatedActorType: OperationActorType.driver,
        delegatedActorId: 'driver-1',
      );
      final scope = ActorScope.devices(
        deviceIds: const ['device-1'],
        actorId: 'driver-1',
      );

      final device = policy.canAccessResource(
        actor: agent,
        scope: scope,
        resourceType: OperationResourceType.device,
        resourceId: 'device-1',
        now: now,
      );
      final project = policy.canAccessResource(
        actor: agent,
        scope: ActorScope.projects(projectIds: const ['project-1']),
        resourceType: OperationResourceType.project,
        resourceId: 'project-1',
        now: now,
      );

      expect(device.allowed, isTrue);
      expect(project.allowed, isFalse);
    });

    test('system and unknown deny by default', () {
      for (final actor in [
        ActorContext(actorType: OperationActorType.system),
        ActorContext(actorType: OperationActorType.unknown),
      ]) {
        final decision = policy.canAccessResource(
          actor: actor,
          scope: ActorScope.fullOwner(ownerId: 'owner-1'),
          resourceType: OperationResourceType.device,
          resourceId: 'device-1',
          now: now,
        );

        expect(decision.allowed, isFalse, reason: actor.actorType.wireName);
      }
    });

    test('expired scope denies before resource-specific checks', () {
      final scope = ActorScope.devices(
        deviceIds: const ['device-1'],
        expiresAt: now.subtract(const Duration(seconds: 1)),
      );

      final decision = policy.canAccessResource(
        actor: driver,
        scope: scope,
        resourceType: OperationResourceType.device,
        resourceId: 'device-1',
        now: now,
      );

      expect(decision.allowed, isFalse);
      expect(decision.reason, contains('expired'));
    });

    test('blank resourceId throws before allow / deny', () {
      expect(
        () => policy.canAccessResource(
          actor: owner,
          scope: ActorScope.fullOwner(ownerId: 'owner-1'),
          resourceType: OperationResourceType.device,
          resourceId: ' ',
          now: now,
        ),
        throwsArgumentError,
      );
    });
  });

  group('OperationScopeDecision', () {
    test('toMap includes stable wire fields', () {
      final decision = OperationScopeDecision.deny(
        resourceType: OperationResourceType.auditLog,
        resourceId: 'audit-1',
        reason: 'no audit scope',
      );

      expect(decision.toMap(), {
        'allowed': false,
        'reason': 'no audit scope',
        'resource_type': 'audit_log',
        'resource_id': 'audit-1',
      });
    });

    test('deny reason cannot be empty', () {
      expect(
        () => OperationScopeDecision.deny(
          resourceType: OperationResourceType.device,
          resourceId: 'device-1',
          reason: '',
        ),
        throwsArgumentError,
      );
    });
  });
}

ActorScope _testCombinedScope({
  String? ownerId,
  String? actorId,
  Iterable<String> allowedDeviceIds = const [],
  Iterable<String> allowedProjectIds = const [],
  Iterable<String> allowedTimingRecordIds = const [],
  Iterable<String> allowedExternalPackageIds = const [],
  String? scopeSource,
  String? grantId,
  DateTime? expiresAt,
}) {
  return ActorScope.fromMap({
    'full_owner': false,
    'owner_id': ownerId,
    'actor_id': actorId,
    'allowed_device_ids': allowedDeviceIds.toList(),
    'allowed_project_ids': allowedProjectIds.toList(),
    'allowed_timing_record_ids': allowedTimingRecordIds.toList(),
    'allowed_external_package_ids': allowedExternalPackageIds.toList(),
    'scope_source': scopeSource,
    'grant_id': grantId,
    'expires_at': expiresAt?.toIso8601String(),
  });
}
