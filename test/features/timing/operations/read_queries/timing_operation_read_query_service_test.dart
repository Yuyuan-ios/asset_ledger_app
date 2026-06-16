import 'package:asset_ledger/core/operations/operation_access_control.dart';
import 'package:asset_ledger/core/operations/operation_actor_scope.dart';
import 'package:asset_ledger/core/operations/operation_actor_type.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/repositories/device_repository.dart';
import 'package:asset_ledger/data/repositories/timing_repository.dart';
import 'package:asset_ledger/features/timing/operations/read_queries/timing_operation_read_query_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 6, 1);

  group('TimingOperationReadQueryService.queryDevices', () {
    test('owner full scope reads all device DTOs without redaction', () async {
      final service = _service(
        devices: [
          _device(1, 'Hitachi 1#', brand: 'Hitachi', model: 'ZX200'),
          _device(2, 'SANY 2#', brand: 'SANY'),
        ],
      );

      final result = await service.queryDevices(
        context: _context(
          actor: _owner(),
          scope: ActorScope.fullOwner(),
          now: now,
        ),
      );

      expect(result.items.map((item) => item.id), ['1', '2']);
      expect(result.items.first.displayName, 'Hitachi 1#');
      expect(result.items.first.brandOrModel, 'Hitachi ZX200');
      expect(result.items.first.active, isTrue);
      expect(result.items.first.enabled, isTrue);
      expect(result.redacted, isFalse);
      expect(result.scopeLimited, isFalse);
      expect(result.hasMore, isFalse);
      expect(result.warnings, isEmpty);
      expect(result.items.first, isNot(isA<Device>()));
    });

    test('owner limited scope reads only scoped devices', () async {
      final service = _service(
        devices: [_device(1, 'Hitachi 1#'), _device(2, 'SANY 2#')],
      );

      final result = await service.queryDevices(
        context: _context(
          actor: _owner(),
          scope: ActorScope.devices(deviceIds: const ['2']),
          now: now,
        ),
      );

      expect(result.items.map((item) => item.id), ['2']);
      expect(result.redacted, isFalse);
      expect(result.scopeLimited, isTrue);
    });

    test('driver reads assigned devices only', () async {
      final service = _service(
        devices: [_device(1, 'Hitachi 1#'), _device(2, 'SANY 2#')],
      );

      final result = await service.queryDevices(
        context: _context(
          actor: _driver(),
          scope: ActorScope.devices(deviceIds: const ['1']),
          now: now,
        ),
      );

      expect(result.items.map((item) => item.id), ['1']);
      expect(result.items.single.redacted, isTrue);
      expect(result.redacted, isTrue);
      expect(result.scopeLimited, isTrue);
    });

    test('partner reads shared devices only', () async {
      final service = _service(
        devices: [_device(1, 'Hitachi 1#'), _device(2, 'SANY 2#')],
      );

      final result = await service.queryDevices(
        context: _context(
          actor: _partner(),
          scope: ActorScope.devices(deviceIds: const ['2']),
          now: now,
        ),
      );

      expect(result.items.map((item) => item.id), ['2']);
      expect(result.items.single.redacted, isTrue);
    });

    test('agent without delegated scope reads nothing', () async {
      final service = _service(devices: [_device(1, 'Hitachi 1#')]);

      final result = await service.queryDevices(
        context: _context(
          actor: ActorContext(
            actorType: OperationActorType.agent,
            actorId: 'agent-1',
          ),
          scope: ActorScope.fullOwner(),
          now: now,
        ),
      );

      expect(result.items, isEmpty);
      expect(result.hasMore, isFalse);
    });

    test('expired scope returns empty result with warning', () async {
      final service = _service(devices: [_device(1, 'Hitachi 1#')]);

      final result = await service.queryDevices(
        context: _context(
          actor: _owner(),
          scope: ActorScope.fullOwner(expiresAt: now),
          now: now,
        ),
      );

      expect(result.items, isEmpty);
      expect(result.scopeLimited, isTrue);
      expect(result.warnings, contains('scope expired'));
    });

    test('keyword filter matches visible device label and brand', () async {
      final service = _service(
        devices: [
          _device(1, 'Hitachi 1#', brand: 'Hitachi'),
          _device(2, 'SANY 2#', brand: 'SANY'),
        ],
      );

      final result = await service.queryDevices(
        context: _context(
          actor: _owner(),
          scope: ActorScope.fullOwner(),
          now: now,
        ),
        input: const DeviceQueryInput(keyword: 'sany'),
      );

      expect(result.items.map((item) => item.id), ['2']);
    });

    test('limit is applied after scope filtering and sets hasMore', () async {
      final service = _service(
        devices: [_device(1, 'A'), _device(2, 'B'), _device(3, 'C')],
      );

      final result = await service.queryDevices(
        context: _context(
          actor: _driver(),
          scope: ActorScope.devices(deviceIds: const ['1', '2', '3']),
          now: now,
        ),
        input: const DeviceQueryInput(limit: 2),
      );

      expect(result.items.map((item) => item.id), ['1', '2']);
      expect(result.hasMore, isTrue);
    });
  });

  group('TimingOperationReadQueryService.queryTimingRecords', () {
    test('owner full scope reads timing basics with project fields', () async {
      final service = _service(
        devices: [_device(1, 'Hitachi 1#')],
        records: [
          _record(
            id: 10,
            deviceId: 1,
            startDate: 20260531,
            projectId: 'project-a',
            contact: '丁队',
            site: '五里山',
          ),
        ],
      );

      final result = await service.queryTimingRecords(
        context: _context(
          actor: _owner(),
          scope: ActorScope.fullOwner(),
          now: now,
        ),
      );

      final item = result.items.single;
      expect(item.id, '10');
      expect(item.deviceName, 'Hitachi 1#');
      expect(item.workDate, '2026-05-31');
      expect(item.hours, 7.5);
      expect(item.startMeter, 100);
      expect(item.endMeter, 107.5);
      expect(item.type, 'hours');
      expect(item.projectId, 'project-a');
      expect(item.projectLabel, '丁队 · 五里山');
      expect(item.contact, '丁队');
      expect(item.site, '五里山');
      expect(item.redacted, isFalse);
      expect(result.redacted, isFalse);
      expect(result.scopeLimited, isFalse);
      expect(item, isNot(isA<TimingRecord>()));
    });

    test(
      'driver reads records on assigned device with project fields hidden',
      () async {
        final service = _service(
          devices: [_device(1, 'Hitachi 1#'), _device(2, 'SANY 2#')],
          records: [
            _record(id: 10, deviceId: 1, projectId: 'project-a'),
            _record(id: 11, deviceId: 2, projectId: 'project-b'),
          ],
        );

        final result = await service.queryTimingRecords(
          context: _context(
            actor: _driver(),
            scope: ActorScope.devices(deviceIds: const ['1']),
            now: now,
          ),
        );

        final item = result.items.single;
        expect(item.id, '10');
        expect(item.deviceName, 'Hitachi 1#');
        expect(item.projectId, isNull);
        expect(item.projectLabel, isNull);
        expect(item.contact, isNull);
        expect(item.site, isNull);
        expect(item.redacted, isTrue);
        expect(result.redacted, isTrue);
      },
    );

    test('driver reads explicitly assigned timing record by id', () async {
      final service = _service(
        devices: [_device(1, 'Hitachi 1#'), _device(2, 'SANY 2#')],
        records: [_record(id: 10, deviceId: 1), _record(id: 11, deviceId: 2)],
      );

      final result = await service.queryTimingRecords(
        context: _context(
          actor: _driver(),
          scope: ActorScope.timingRecords(timingRecordIds: const ['11']),
          now: now,
        ),
      );

      expect(result.items.map((item) => item.id), ['11']);
    });

    test('driver denied outside device and record scope', () async {
      final service = _service(
        devices: [_device(1, 'Hitachi 1#')],
        records: [_record(id: 10, deviceId: 1)],
      );

      final result = await service.queryTimingRecords(
        context: _context(
          actor: _driver(),
          scope: ActorScope.devices(deviceIds: const ['2']),
          now: now,
        ),
      );

      expect(result.items, isEmpty);
    });

    test(
      'partner reads shared device records with project fields hidden',
      () async {
        final service = _service(
          devices: [_device(1, 'Hitachi 1#'), _device(2, 'SANY 2#')],
          records: [_record(id: 10, deviceId: 1), _record(id: 11, deviceId: 2)],
        );

        final result = await service.queryTimingRecords(
          context: _context(
            actor: _partner(),
            scope: ActorScope.devices(deviceIds: const ['2']),
            now: now,
          ),
        );

        final item = result.items.single;
        expect(item.id, '11');
        expect(item.projectId, isNull);
        expect(item.projectLabel, isNull);
        expect(item.contact, isNull);
        expect(item.site, isNull);
        expect(item.redacted, isTrue);
      },
    );

    test('partner denied outside shared device scope', () async {
      final service = _service(
        devices: [_device(1, 'Hitachi 1#')],
        records: [_record(id: 10, deviceId: 1)],
      );

      final result = await service.queryTimingRecords(
        context: _context(
          actor: _partner(),
          scope: ActorScope.devices(deviceIds: const ['2']),
          now: now,
        ),
      );

      expect(result.items, isEmpty);
    });

    test('agent-as-driver follows driver timing scope', () async {
      final service = _service(
        devices: [_device(1, 'Hitachi 1#'), _device(2, 'SANY 2#')],
        records: [_record(id: 10, deviceId: 1), _record(id: 11, deviceId: 2)],
      );

      final result = await service.queryTimingRecords(
        context: _context(
          actor: ActorContext(
            actorType: OperationActorType.agent,
            actorId: 'agent-1',
            delegatedActorType: OperationActorType.driver,
            delegatedActorId: 'driver-1',
          ),
          scope: ActorScope.devices(deviceIds: const ['1']),
          now: now,
        ),
      );

      expect(result.items.map((item) => item.id), ['10']);
      expect(result.items.single.redacted, isTrue);
    });

    test('system and unknown actors read empty timing results', () async {
      final service = _service(
        devices: [_device(1, 'Hitachi 1#')],
        records: [_record(id: 10, deviceId: 1)],
      );

      final system = await service.queryTimingRecords(
        context: _context(
          actor: ActorContext(actorType: OperationActorType.system),
          scope: ActorScope.fullOwner(),
          now: now,
        ),
      );
      final unknown = await service.queryTimingRecords(
        context: _context(
          actor: ActorContext(actorType: OperationActorType.unknown),
          scope: ActorScope.fullOwner(),
          now: now,
        ),
      );

      expect(system.items, isEmpty);
      expect(unknown.items, isEmpty);
    });

    test('date range filters records inclusively', () async {
      final service = _service(
        devices: [_device(1, 'Hitachi 1#')],
        records: [
          _record(id: 10, deviceId: 1, startDate: 20260501),
          _record(id: 11, deviceId: 1, startDate: 20260515),
          _record(id: 12, deviceId: 1, startDate: 20260601),
        ],
      );

      final result = await service.queryTimingRecords(
        context: _context(
          actor: _owner(),
          scope: ActorScope.fullOwner(),
          now: now,
        ),
        input: TimingRecordQueryInput(
          from: DateTime(2026, 5, 10),
          to: DateTime(2026, 5, 31),
        ),
      );

      expect(result.items.map((item) => item.id), ['11']);
    });

    test('recent query keeps newest order and applies limit', () async {
      final service = _service(
        devices: [_device(1, 'Hitachi 1#')],
        records: [
          _record(id: 10, deviceId: 1, startDate: 20260501),
          _record(id: 11, deviceId: 1, startDate: 20260520),
          _record(id: 12, deviceId: 1, startDate: 20260520),
        ],
      );

      final result = await service.queryTimingRecords(
        context: _context(
          actor: _owner(),
          scope: ActorScope.fullOwner(),
          now: now,
        ),
        input: const TimingRecordQueryInput(recentOnly: true, limit: 2),
      );

      expect(result.items.map((item) => item.id), ['12', '11']);
      expect(result.hasMore, isTrue);
    });
  });
}

TimingOperationReadQueryService _service({
  List<Device> devices = const [],
  List<TimingRecord> records = const [],
}) {
  return TimingOperationReadQueryService(
    deviceRepository: _FakeDeviceRepository(devices),
    timingRepository: _FakeTimingRepository(records),
  );
}

TimingOperationReadQueryContext _context({
  required ActorContext actor,
  required ActorScope scope,
  required DateTime now,
}) {
  return TimingOperationReadQueryContext(actor: actor, scope: scope, now: now);
}

ActorContext _owner() => ActorContext(actorType: OperationActorType.owner);

ActorContext _driver() {
  return ActorContext(
    actorType: OperationActorType.driver,
    actorId: 'driver-1',
  );
}

ActorContext _partner() {
  return ActorContext(
    actorType: OperationActorType.partner,
    actorId: 'partner-1',
  );
}

Device _device(
  int id,
  String name, {
  String brand = 'Hitachi',
  String? model,
  bool active = true,
}) {
  return Device(
    id: id,
    name: name,
    brand: brand,
    model: model,
    defaultUnitPrice: 100,
    baseMeterHours: 0,
    isActive: active,
  );
}

TimingRecord _record({
  required int id,
  required int deviceId,
  int startDate = 20260531,
  String projectId = 'project-a',
  String contact = '丁队',
  String site = '五里山',
  TimingType type = TimingType.hours,
  double hours = 7.5,
}) {
  return TimingRecord.fromMap({
    'id': id,
    'device_id': deviceId,
    'start_date': startDate,
    'project_id': projectId,
    'contact': contact,
    'site': site,
    'type': type.name,
    'start_meter': 100.0,
    'end_meter': 107.5,
    'hours': hours,
    'income_fen': 90000,
    'exclude_from_fuel_eff': 0,
    'is_breaking': 0,
  });
}

class _FakeDeviceRepository implements DeviceRepository {
  const _FakeDeviceRepository(this._devices);

  final List<Device> _devices;

  @override
  Future<List<Device>> listAll() async => List.unmodifiable(_devices);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTimingRepository implements TimingRepository {
  const _FakeTimingRepository(this._records);

  final List<TimingRecord> _records;

  @override
  Future<List<TimingRecord>> listAll() async => List.unmodifiable(_records);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
