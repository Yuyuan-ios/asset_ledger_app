import 'package:asset_ledger/core/measure/measure_unit.dart';
import 'package:asset_ledger/core/operations/operation_access_control.dart';
import 'package:asset_ledger/core/operations/operation_actor_scope.dart';
import 'package:asset_ledger/core/operations/operation_actor_type.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/features/sync/use_cases/partner_device_sync_boundary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 6, 12);
  const boundary = PartnerDeviceSyncBoundary();

  group('PartnerDeviceSyncBoundary', () {
    test('partner sync includes authorized devices and records only', () {
      final snapshot = boundary.buildSnapshot(
        context: _context(
          actor: _partner(),
          scope: ActorScope.devices(deviceIds: ['2'], actorId: 'partner-1'),
          now: now,
        ),
        devices: [_device('1', 'Hitachi 1#'), _device('2', 'SANY 2#')],
        timingRecords: [
          _record(id: 'record-1', deviceId: '1'),
          _record(id: 'record-2', deviceId: '2'),
        ],
      );

      expect(snapshot.devices.map((device) => device.id), ['2']);
      expect(snapshot.timingRecords.map((record) => record.id), ['record-2']);
      expect(snapshot.redacted, isTrue);
      expect(snapshot.scopeLimited, isTrue);
      expect(snapshot.warnings, isEmpty);
    });

    test(
      'authorized device snapshot excludes local lifecycle payback fields',
      () {
        const initialCostFen = 987654321;
        const residualFen = 234567890;
        final localDevice = Device(
          id: 2,
          name: 'SANY lifecycle',
          brand: 'SANY',
          model: 'SY215',
          defaultUnitPrice: 100,
          baseMeterHours: 0,
          lifecycleInitialCostFen: initialCostFen,
          lifecycleEstimatedResidualFen: residualFen,
        );

        final snapshot = boundary.buildSnapshot(
          context: _context(
            actor: _partner(),
            scope: ActorScope.devices(deviceIds: ['2'], actorId: 'partner-1'),
            now: now,
          ),
          devices: [
            PartnerDeviceSyncDevice(
              id: localDevice.id.toString(),
              displayName: localDevice.name,
              brandOrModel: localDevice.model,
            ),
          ],
          timingRecords: const [],
        );

        final deviceMap = snapshot.devices.single.toMap();
        expect(
          deviceMap.keys,
          unorderedEquals([
            'device_id',
            'display_name',
            'brand_or_model',
            'active',
          ]),
        );
        expect(deviceMap.containsKey('lifecycle_initial_cost_fen'), isFalse);
        expect(
          deviceMap.containsKey('lifecycle_estimated_residual_fen'),
          isFalse,
        );
        expect(
          deviceMap.toString(),
          isNot(contains(initialCostFen.toString())),
        );
        expect(deviceMap.toString(), isNot(contains(residualFen.toString())));
      },
    );

    test(
      'authorized record snapshot does not carry unrelated project data',
      () {
        final snapshot = boundary.buildSnapshot(
          context: _context(
            actor: _partner(),
            scope: ActorScope.devices(deviceIds: ['2'], actorId: 'partner-1'),
            now: now,
          ),
          devices: [_device('2', 'SANY 2#')],
          timingRecords: [
            _record(
              id: 'record-2',
              deviceId: '2',
              projectId: 'project-secret',
              projectLabel: '丁队 · 五里山',
              contact: '丁队',
              site: '五里山',
              incomeFen: 120000,
              unitPriceFen: 16000,
            ),
          ],
        );

        final recordMap = snapshot.timingRecords.single.toMap();
        expect(recordMap['device_id'], '2');
        expect(recordMap['unit'], 'HOUR');
        expect(recordMap['quantity_scaled'], 7500);
        expect(recordMap.containsKey('project_id'), isFalse);
        expect(recordMap.containsKey('project_label'), isFalse);
        expect(recordMap.containsKey('contact'), isFalse);
        expect(recordMap.containsKey('site'), isFalse);
        expect(recordMap.containsKey('income_fen'), isFalse);
        expect(recordMap.containsKey('unit_price_fen'), isFalse);
      },
    );

    test('partner with empty or mismatched device scope sees nothing', () {
      final emptyScope = boundary.buildSnapshot(
        context: _context(
          actor: _partner(),
          scope: ActorScope.empty(actorId: 'partner-1'),
          now: now,
        ),
        devices: [_device('2', 'SANY 2#')],
        timingRecords: [_record(id: 'record-2', deviceId: '2')],
      );
      final mismatchedScope = boundary.buildSnapshot(
        context: _context(
          actor: _partner(),
          scope: ActorScope.devices(deviceIds: ['9'], actorId: 'partner-1'),
          now: now,
        ),
        devices: [_device('2', 'SANY 2#')],
        timingRecords: [_record(id: 'record-2', deviceId: '2')],
      );

      expect(emptyScope.devices, isEmpty);
      expect(emptyScope.timingRecords, isEmpty);
      expect(mismatchedScope.devices, isEmpty);
      expect(mismatchedScope.timingRecords, isEmpty);
    });

    test('expired scope denies partner sync with warning', () {
      final snapshot = boundary.buildSnapshot(
        context: _context(
          actor: _partner(),
          scope: ActorScope.devices(
            deviceIds: ['2'],
            actorId: 'partner-1',
            expiresAt: now,
          ),
          now: now,
        ),
        devices: [_device('2', 'SANY 2#')],
        timingRecords: [_record(id: 'record-2', deviceId: '2')],
      );

      expect(snapshot.devices, isEmpty);
      expect(snapshot.timingRecords, isEmpty);
      expect(snapshot.warnings, contains('scope expired'));
    });

    test('owner and driver cannot use the partner sync boundary', () {
      final ownerSnapshot = boundary.buildSnapshot(
        context: _context(
          actor: ActorContext(actorType: OperationActorType.owner),
          scope: ActorScope.fullOwner(),
          now: now,
        ),
        devices: [_device('2', 'SANY 2#')],
        timingRecords: [_record(id: 'record-2', deviceId: '2')],
      );
      final driverSnapshot = boundary.buildSnapshot(
        context: _context(
          actor: ActorContext(
            actorType: OperationActorType.driver,
            actorId: 'driver-1',
          ),
          scope: ActorScope.devices(deviceIds: ['2'], actorId: 'driver-1'),
          now: now,
        ),
        devices: [_device('2', 'SANY 2#')],
        timingRecords: [_record(id: 'record-2', deviceId: '2')],
      );

      expect(ownerSnapshot.devices, isEmpty);
      expect(
        ownerSnapshot.warnings,
        contains('partner sync requires partner actor'),
      );
      expect(driverSnapshot.devices, isEmpty);
      expect(
        driverSnapshot.warnings,
        contains('partner sync requires partner actor'),
      );
    });

    test('agent delegated to partner follows the same device boundary', () {
      final snapshot = boundary.buildSnapshot(
        context: _context(
          actor: ActorContext(
            actorType: OperationActorType.agent,
            actorId: 'agent-1',
            delegatedActorType: OperationActorType.partner,
            delegatedActorId: 'partner-1',
          ),
          scope: ActorScope.devices(deviceIds: ['2'], actorId: 'partner-1'),
          now: now,
        ),
        devices: [_device('1', 'Hitachi 1#'), _device('2', 'SANY 2#')],
        timingRecords: [
          _record(id: 'record-1', deviceId: '1'),
          _record(id: 'record-2', deviceId: '2'),
        ],
      );

      expect(snapshot.devices.map((device) => device.id), ['2']);
      expect(snapshot.timingRecords.map((record) => record.id), ['record-2']);
      expect(snapshot.warnings, isEmpty);
    });
  });
}

PartnerDeviceSyncContext _context({
  required ActorContext actor,
  required ActorScope scope,
  required DateTime now,
}) {
  return PartnerDeviceSyncContext(actor: actor, scope: scope, now: now);
}

ActorContext _partner() {
  return ActorContext(
    actorType: OperationActorType.partner,
    actorId: 'partner-1',
  );
}

PartnerDeviceSyncDevice _device(String id, String name) {
  return PartnerDeviceSyncDevice(
    id: id,
    displayName: name,
    brandOrModel: 'SANY SY215',
  );
}

PartnerDeviceSyncTimingRecord _record({
  required String id,
  required String deviceId,
  int workDate = 20260612,
  MeasureUnit unit = MeasureUnit.hour,
  int quantityScaled = 7500,
  String? projectId = 'project-a',
  String? projectLabel = '丁队 · 五里山',
  String? contact = '丁队',
  String? site = '五里山',
  int? incomeFen = 120000,
  int? unitPriceFen = 16000,
}) {
  return PartnerDeviceSyncTimingRecord(
    id: id,
    deviceId: deviceId,
    workDate: workDate,
    unit: unit,
    quantityScaled: quantityScaled,
    startMeterScaled: 100000,
    endMeterScaled: 107500,
    projectId: projectId,
    projectLabel: projectLabel,
    contact: contact,
    site: site,
    incomeFen: incomeFen,
    unitPriceFen: unitPriceFen,
  );
}
