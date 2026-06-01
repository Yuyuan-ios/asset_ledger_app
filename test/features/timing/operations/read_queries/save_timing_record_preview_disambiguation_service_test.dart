import 'package:asset_ledger/core/operations/operation_access_control.dart';
import 'package:asset_ledger/core/operations/operation_actor_scope.dart';
import 'package:asset_ledger/core/operations/operation_actor_type.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/timing_calculation_history.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/repositories/device_repository.dart';
import 'package:asset_ledger/data/repositories/timing_repository.dart';
import 'package:asset_ledger/features/timing/operations/read_queries/save_timing_record_preview_disambiguation_service.dart';
import 'package:asset_ledger/features/timing/operations/read_queries/timing_operation_read_query_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 6, 1);

  group('SaveTimingRecordDisambiguationStatus', () {
    test('wireName round-trips', () {
      for (final status in SaveTimingRecordDisambiguationStatus.values) {
        expect(
          SaveTimingRecordDisambiguationStatus.fromWireName(status.wireName),
          status,
        );
        expect(
          SaveTimingRecordDisambiguationStatus.tryParse(status.wireName),
          status,
        );
      }

      expect(
        SaveTimingRecordDisambiguationStatus.notFound.wireName,
        'not_found',
      );
      expect(
        SaveTimingRecordDisambiguationStatus.insufficientInput.wireName,
        'insufficient_input',
      );
      expect(
        () => SaveTimingRecordDisambiguationStatus.fromWireName('missing'),
        throwsArgumentError,
      );
    });
  });

  group('SaveTimingRecordPreviewDisambiguationService', () {
    test(
      'returns insufficientInput when no structured hint is provided',
      () async {
        final service = _service();

        final result = await service.disambiguate(
          _request(
            context: _context(actor: _owner(), scope: _ownerScope(), now: now),
          ),
        );

        expect(
          result.status,
          SaveTimingRecordDisambiguationStatus.insufficientInput,
        );
        expect(result.candidates, isEmpty);
        expect(result.isResolved, isFalse);
        expect(result.singleCandidate, isNull);
      },
    );

    test('resolves a unique device keyword candidate', () async {
      final service = _service(
        devices: [
          _device(1, 'Hitachi 1#'),
          _device(2, 'SANY 2#', brand: 'SANY'),
        ],
      );

      final result = await service.disambiguate(
        _request(
          context: _context(actor: _owner(), scope: _ownerScope(), now: now),
          deviceKeyword: 'hita',
        ),
      );

      expect(result.status, SaveTimingRecordDisambiguationStatus.resolved);
      expect(
        result.singleCandidate?.type,
        SaveTimingRecordDisambiguationCandidateType.device,
      );
      expect(result.singleCandidate?.id, '1');
      expect(result.singleCandidate?.displayLabel, 'Hitachi 1#');
      expect(result.singleCandidate?.confidence, 0.9);
      expect(result.singleCandidate?.reason, '匹配设备关键词');
      expect(result.redacted, isFalse);
    });

    test('returns ambiguous for multiple device keyword candidates', () async {
      final service = _service(
        devices: [_device(1, 'Hitachi A'), _device(2, 'Hitachi B')],
      );

      final result = await service.disambiguate(
        _request(
          context: _context(actor: _owner(), scope: _ownerScope(), now: now),
          deviceKeyword: 'hitachi',
        ),
      );

      expect(result.status, SaveTimingRecordDisambiguationStatus.ambiguous);
      expect(result.candidates.map((item) => item.id), ['1', '2']);
      expect(result.singleCandidate, isNull);
    });

    test('returns notFound for device keyword with no scoped match', () async {
      final service = _service(devices: [_device(1, 'Hitachi A')]);

      final result = await service.disambiguate(
        _request(
          context: _context(actor: _owner(), scope: _ownerScope(), now: now),
          deviceKeyword: 'sany',
        ),
      );

      expect(result.status, SaveTimingRecordDisambiguationStatus.notFound);
      expect(result.candidates, isEmpty);
    });

    test('resolves a timing record by id', () async {
      final service = _service(
        devices: [_device(1, 'Hitachi 1#')],
        records: [_record(id: 10, deviceId: 1)],
      );

      final result = await service.disambiguate(
        _request(
          context: _context(actor: _owner(), scope: _ownerScope(), now: now),
          timingRecordId: '10',
        ),
      );

      expect(result.status, SaveTimingRecordDisambiguationStatus.resolved);
      expect(
        result.singleCandidate?.type,
        SaveTimingRecordDisambiguationCandidateType.timingRecord,
      );
      expect(result.singleCandidate?.id, '10');
      expect(
        result.singleCandidate?.displayLabel,
        '2026-05-31 · Hitachi 1# · 7.5 小时',
      );
      expect(result.singleCandidate?.confidence, 1.0);
      expect(result.singleCandidate?.reason, '匹配计时记录 ID');
    });

    test('resolves a timing record by device and date', () async {
      final service = _service(
        devices: [_device(1, 'Hitachi 1#')],
        records: [
          _record(id: 10, deviceId: 1, startDate: 20260530),
          _record(id: 11, deviceId: 1, startDate: 20260531),
        ],
      );

      final result = await service.disambiguate(
        _request(
          context: _context(actor: _owner(), scope: _ownerScope(), now: now),
          deviceId: 1,
          recordDate: DateTime(2026, 5, 31),
        ),
      );

      expect(result.status, SaveTimingRecordDisambiguationStatus.resolved);
      expect(result.singleCandidate?.id, '11');
      expect(result.singleCandidate?.reason, '匹配设备和日期范围');
    });

    test(
      'returns ambiguous for multiple records on same device and date',
      () async {
        final service = _service(
          devices: [_device(1, 'Hitachi 1#')],
          records: [
            _record(id: 10, deviceId: 1, startDate: 20260531),
            _record(id: 11, deviceId: 1, startDate: 20260531),
          ],
        );

        final result = await service.disambiguate(
          _request(
            context: _context(actor: _owner(), scope: _ownerScope(), now: now),
            deviceId: 1,
            recordDate: DateTime(2026, 5, 31),
          ),
        );

        expect(result.status, SaveTimingRecordDisambiguationStatus.ambiguous);
        expect(result.candidates.map((item) => item.id), ['11', '10']);
        expect(result.singleCandidate, isNull);
      },
    );

    test(
      'returns forbidden and propagates warning for expired scope',
      () async {
        final service = _service(devices: [_device(1, 'Hitachi 1#')]);

        final result = await service.disambiguate(
          _request(
            context: _context(
              actor: _owner(),
              scope: ActorScope.fullOwner(expiresAt: now),
              now: now,
            ),
            deviceKeyword: 'hitachi',
          ),
        );

        expect(result.status, SaveTimingRecordDisambiguationStatus.forbidden);
        expect(result.candidates, isEmpty);
        expect(result.warnings, contains('scope expired'));
        expect(result.scopeLimited, isTrue);
      },
    );

    test('returns forbidden for agent without delegated scope', () async {
      final service = _service(devices: [_device(1, 'Hitachi 1#')]);

      final result = await service.disambiguate(
        _request(
          context: _context(
            actor: ActorContext(
              actorType: OperationActorType.agent,
              actorId: 'agent-1',
            ),
            scope: _ownerScope(),
            now: now,
          ),
          deviceKeyword: 'hitachi',
        ),
      );

      expect(result.status, SaveTimingRecordDisambiguationStatus.forbidden);
      expect(result.candidates, isEmpty);
      expect(result.redacted, isTrue);
    });

    test('driver timing candidates do not leak project/contact/site', () async {
      final service = _service(
        devices: [_device(1, 'Hitachi 1#')],
        records: [
          _record(
            id: 10,
            deviceId: 1,
            contact: '张老板',
            site: '秘密工地',
            projectId: 'project-secret',
          ),
        ],
      );

      final result = await service.disambiguate(
        _request(
          context: _context(
            actor: _driver(),
            scope: ActorScope.devices(
              deviceIds: const ['1'],
              actorId: 'driver-1',
            ),
            now: now,
          ),
          deviceId: 1,
          recordDate: DateTime(2026, 5, 31),
        ),
      );

      expect(result.status, SaveTimingRecordDisambiguationStatus.resolved);
      expect(result.redacted, isTrue);
      final text = result.toMap().toString();
      expect(text, isNot(contains('张老板')));
      expect(text, isNot(contains('秘密工地')));
      expect(text, isNot(contains('project-secret')));
      expect(text, isNot(contains('丁队')));
    });

    test(
      'partner timing candidates do not leak project/contact/site',
      () async {
        final service = _service(
          devices: [_device(1, 'Shared SANY')],
          records: [
            _record(
              id: 10,
              deviceId: 1,
              contact: '老板甲方',
              site: '老板工地',
              projectId: 'project-boss-only',
            ),
          ],
        );

        final result = await service.disambiguate(
          _request(
            context: _context(
              actor: _partner(),
              scope: ActorScope.devices(
                deviceIds: const ['1'],
                actorId: 'partner-1',
              ),
              now: now,
            ),
            deviceId: 1,
            recordDate: DateTime(2026, 5, 31),
          ),
        );

        expect(result.status, SaveTimingRecordDisambiguationStatus.resolved);
        expect(result.redacted, isTrue);
        final text = result.toMap().toString();
        expect(text, isNot(contains('老板甲方')));
        expect(text, isNot(contains('老板工地')));
        expect(text, isNot(contains('project-boss-only')));
      },
    );

    test(
      'device keyword plus date resolves device first then timing record',
      () async {
        final service = _service(
          devices: [
            _device(1, 'Hitachi 1#'),
            _device(2, 'SANY 2#', brand: 'SANY'),
          ],
          records: [
            _record(id: 10, deviceId: 1, startDate: 20260531),
            _record(id: 11, deviceId: 2, startDate: 20260531),
          ],
        );

        final result = await service.disambiguate(
          _request(
            context: _context(actor: _owner(), scope: _ownerScope(), now: now),
            deviceKeyword: 'Hitachi',
            recordDate: DateTime(2026, 5, 31),
          ),
        );

        expect(result.status, SaveTimingRecordDisambiguationStatus.resolved);
        expect(
          result.singleCandidate?.type,
          SaveTimingRecordDisambiguationCandidateType.timingRecord,
        );
        expect(result.singleCandidate?.id, '10');
        expect(result.singleCandidate?.reason, '匹配设备和日期范围');
      },
    );

    test(
      'device keyword plus date returns device ambiguity before timing query',
      () async {
        final service = _service(
          devices: [_device(1, 'Hitachi A'), _device(2, 'Hitachi B')],
          records: [_record(id: 10, deviceId: 1, startDate: 20260531)],
        );

        final result = await service.disambiguate(
          _request(
            context: _context(actor: _owner(), scope: _ownerScope(), now: now),
            deviceKeyword: 'Hitachi',
            recordDate: DateTime(2026, 5, 31),
          ),
        );

        expect(result.status, SaveTimingRecordDisambiguationStatus.ambiguous);
        expect(result.candidates.map((item) => item.type).toSet(), {
          SaveTimingRecordDisambiguationCandidateType.device,
        });
      },
    );
  });
}

SaveTimingRecordPreviewDisambiguationService _service({
  List<Device> devices = const [],
  List<TimingRecord> records = const [],
}) {
  return SaveTimingRecordPreviewDisambiguationService(
    readQueryService: TimingOperationReadQueryService(
      deviceRepository: _FakeDeviceRepository(devices),
      timingRepository: _FakeTimingRepository(records),
    ),
  );
}

SaveTimingRecordDisambiguationRequest _request({
  required TimingOperationReadQueryContext context,
  String? deviceKeyword,
  String? timingRecordId,
  DateTime? recordDate,
  DateTime? from,
  DateTime? to,
  int? deviceId,
  int limit = 5,
}) {
  return SaveTimingRecordDisambiguationRequest(
    context: context,
    deviceKeyword: deviceKeyword,
    timingRecordId: timingRecordId,
    recordDate: recordDate,
    from: from,
    to: to,
    deviceId: deviceId,
    limit: limit,
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

ActorScope _ownerScope() => ActorScope.fullOwner(ownerId: 'owner-1');

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
  return TimingRecord(
    id: id,
    deviceId: deviceId,
    startDate: startDate,
    projectId: projectId,
    contact: contact,
    site: site,
    type: type,
    startMeter: 100,
    endMeter: 100 + hours,
    hours: hours,
    income: hours * 100,
  );
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
  Future<TimingRecord> saveWithCalculationHistories(
    TimingRecord record, {
    List<TimingCalculationHistory> calculationHistories = const [],
  }) async {
    throw UnsupportedError('read-only fake');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
