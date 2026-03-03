import 'dart:io';

import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/fuel_log.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/core/errors/store_failure.dart';
import 'package:asset_ledger/core/utils/base_store.dart';
import 'package:asset_ledger/data/repositories/device_repository.dart';
import 'package:asset_ledger/data/repositories/fuel_repository.dart';
import 'package:asset_ledger/data/repositories/timing_repository.dart';
import 'package:asset_ledger/features/device/state/device_store.dart';
import 'package:asset_ledger/features/fuel/state/fuel_store.dart';
import 'package:asset_ledger/features/timing/state/timing_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  group('FuelStore write strategy', () {
    test('patches local state for insert update and delete without reloading', () async {
      final repository = _CountingFuelRepository(
        seed: [
          const FuelLog(
            id: 2,
            deviceId: 1,
            date: 20260302,
            supplier: 'B',
            liters: 10,
            cost: 80,
          ),
        ],
      );
      final store = FuelStore(repository);

      await store.loadAll();
      expect(repository.listAllCalls, 1);

      await store.insert(
        const FuelLog(
          deviceId: 1,
          date: 20260305,
          supplier: 'A',
          liters: 20,
          cost: 160,
        ),
      );
      expect(repository.listAllCalls, 1);
      expect(store.logs.map((item) => item.id).toList(), [10, 2]);

      await store.update(
        const FuelLog(
          id: 2,
          deviceId: 1,
          date: 20260306,
          supplier: 'B2',
          liters: 12,
          cost: 96,
        ),
      );
      expect(repository.listAllCalls, 1);
      expect(store.logs.map((item) => item.id).toList(), [2, 10]);
      expect(store.logs.first.supplier, 'B2');

      await store.deleteById(10);
      expect(repository.listAllCalls, 1);
      expect(store.logs.map((item) => item.id).toList(), [2]);
    });
  });

  group('TimingStore write strategy', () {
    test('patches local state for save and delete without reloading', () async {
      final repository = _CountingTimingRepository(
        seed: [
          const TimingRecord(
            id: 4,
            deviceId: 2,
            startDate: 20260302,
            contact: 'A',
            site: 'Yard',
            type: TimingType.hours,
            startMeter: 0,
            endMeter: 1,
            hours: 1,
            income: 100,
          ),
        ],
      );
      final store = TimingStore(repository);

      await store.loadAll();
      expect(repository.listAllCalls, 1);

      await store.save(
        const TimingRecord(
          deviceId: 3,
          startDate: 20260305,
          contact: 'B',
          site: 'Yard',
          type: TimingType.hours,
          startMeter: 1,
          endMeter: 3,
          hours: 2,
          income: 200,
        ),
      );
      expect(repository.listAllCalls, 1);
      expect(store.records.map((item) => item.id).toList(), [11, 4]);

      await store.save(
        const TimingRecord(
          id: 4,
          deviceId: 2,
          startDate: 20260306,
          contact: 'A2',
          site: 'Yard',
          type: TimingType.hours,
          startMeter: 0,
          endMeter: 2,
          hours: 2,
          income: 250,
        ),
      );
      expect(repository.listAllCalls, 1);
      expect(store.records.map((item) => item.id).toList(), [4, 11]);
      expect(store.records.first.contact, 'A2');

      await store.deleteByDeviceId(3);
      expect(repository.listAllCalls, 1);
      expect(store.records.map((item) => item.id).toList(), [4]);
    });
  });

  group('DeviceStore write strategy', () {
    test('still reloads after insert through writeAndReload', () async {
      final repository = _CountingDeviceRepository();
      final store = DeviceStore(repository);

      await store.insert(
        const Device(
          name: '',
          brand: 'SANY',
          defaultUnitPrice: 100,
          baseMeterHours: 0,
        ),
      );

      expect(repository.listAllCalls, 2);
      expect(repository.insertCalls, 1);
      expect(store.allDevices, isNotEmpty);
      expect(store.allDevices.first.name, 'SANY 1#');
    });

    test('exposes load state for id lookups', () async {
      final repository = _CountingDeviceRepository();
      final store = DeviceStore(repository);

      expect(store.hasLoaded, isFalse);
      expect(store.tryFindById(1), isNull);
      expect(() => store.findById(1), throwsStateError);

      await store.loadAll();

      expect(store.hasLoaded, isTrue);
    });
  });

  group('BaseStore failure mapping', () {
    test('maps validation errors and resets loading state', () async {
      final store = _HarnessStore();

      await expectLater(
        store.runAction(() => throw ArgumentError('brand 不能为空')),
        throwsArgumentError,
      );

      expect(store.loading, isFalse);
      expect(store.error, 'brand 不能为空');
      expect(store.failure?.type, StoreFailureType.validation);
    });

    test('maps file system and database errors to stable messages', () async {
      final store = _HarnessStore();

      await expectLater(
        store.runAction(
          () => throw FileSystemException('copy failed', '/tmp/a.png'),
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(store.loading, isFalse);
      expect(store.error, '文件操作失败，请检查文件是否可用');
      expect(store.failure?.type, StoreFailureType.fileSystem);

      await expectLater(
        store.runAction(() => throw _FakeDatabaseException('write failed')),
        throwsA(isA<DatabaseException>()),
      );
      expect(store.loading, isFalse);
      expect(store.error, '数据库操作失败，请稍后重试');
      expect(store.failure?.type, StoreFailureType.database);
    });
  });
}

class _CountingFuelRepository implements FuelRepository {
  _CountingFuelRepository({required List<FuelLog> seed}) : _logs = List.of(seed);

  final List<FuelLog> _logs;
  int listAllCalls = 0;
  int _nextId = 10;

  @override
  Future<List<FuelLog>> listAll() async {
    listAllCalls++;
    return List.of(_logs);
  }

  @override
  Future<int> insert(FuelLog log) async {
    final inserted = log.copyWith(id: _nextId++);
    _logs.add(inserted);
    _sort();
    return inserted.id!;
  }

  @override
  Future<int> update(FuelLog log) async {
    final index = _logs.indexWhere((item) => item.id == log.id);
    _logs[index] = log;
    _sort();
    return 1;
  }

  @override
  Future<int> deleteById(int id) async {
    _logs.removeWhere((item) => item.id == id);
    return 1;
  }

  @override
  Future<int> deleteByDeviceId(int deviceId) async {
    _logs.removeWhere((item) => item.deviceId == deviceId);
    return 1;
  }

  void _sort() {
    _logs.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      return (b.id ?? 0).compareTo(a.id ?? 0);
    });
  }
}

class _CountingTimingRepository implements TimingRepository {
  _CountingTimingRepository({required List<TimingRecord> seed})
    : _records = List.of(seed);

  final List<TimingRecord> _records;
  int listAllCalls = 0;
  int _nextId = 11;

  @override
  Future<List<TimingRecord>> listAll() async {
    listAllCalls++;
    return List.of(_records);
  }

  @override
  Future<int> insert(TimingRecord record) async {
    final inserted = record.copyWith(id: _nextId++);
    _records.add(inserted);
    _sort();
    return inserted.id!;
  }

  @override
  Future<int> update(TimingRecord record) async {
    final index = _records.indexWhere((item) => item.id == record.id);
    _records[index] = record;
    _sort();
    return 1;
  }

  @override
  Future<int> deleteById(int id) async {
    _records.removeWhere((item) => item.id == id);
    return 1;
  }

  @override
  Future<int> deleteByDeviceId(int deviceId) async {
    _records.removeWhere((item) => item.deviceId == deviceId);
    return 1;
  }

  void _sort() {
    _records.sort((a, b) {
      final byDate = b.startDate.compareTo(a.startDate);
      if (byDate != 0) return byDate;
      return (b.id ?? 0).compareTo(a.id ?? 0);
    });
  }
}

class _CountingDeviceRepository implements DeviceRepository {
  final List<Device> _devices = [];
  int listAllCalls = 0;
  int insertCalls = 0;
  int _nextId = 1;

  @override
  Future<List<Device>> listAll() async {
    listAllCalls++;
    return List.of(_devices);
  }

  @override
  Future<List<Device>> listActive() async {
    return _devices.where((item) => item.isActive).toList();
  }

  @override
  Future<Device?> getByIdOrNull(int id) async {
    for (final device in _devices) {
      if (device.id == id) return device;
    }
    return null;
  }

  @override
  Future<Device?> findById(int id) => getByIdOrNull(id);

  @override
  Future<int> insert(Device device) async {
    insertCalls++;
    final inserted = device.copyWith(id: _nextId++);
    _devices.add(inserted);
    return inserted.id!;
  }

  @override
  Future<int> update(Device device) async => 1;

  @override
  Future<int> setActive(int id, bool active) async => 1;

  @override
  Future<int> deleteById(int id) async => 1;
}

class _HarnessStore extends BaseStore {
  Future<void> runAction(Future<void> Function() action) async {
    await run(action);
  }
}

class _FakeDatabaseException implements DatabaseException {
  _FakeDatabaseException(this.message);

  final String message;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  @override
  String toString() => message;
}
