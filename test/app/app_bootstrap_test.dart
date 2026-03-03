import 'package:asset_ledger/app/app_bootstrap.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/fuel_log.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/repositories/device_repository.dart';
import 'package:asset_ledger/data/repositories/fuel_repository.dart';
import 'package:asset_ledger/data/repositories/timing_repository.dart';
import 'package:asset_ledger/features/device/state/device_store.dart';
import 'package:asset_ledger/features/fuel/state/fuel_store.dart';
import 'package:asset_ledger/features/timing/state/timing_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppBootstrap.preload loads device timing and fuel stores without BuildContext', () async {
    final deviceRepository = _FakeDeviceRepository();
    final timingRepository = _FakeTimingRepository();
    final fuelRepository = _FakeFuelRepository();

    final deviceStore = DeviceStore(deviceRepository);
    final timingStore = TimingStore(timingRepository);
    final fuelStore = FuelStore(fuelRepository);

    await AppBootstrap.preload(
      deviceStore: deviceStore,
      timingStore: timingStore,
      fuelStore: fuelStore,
    );

    expect(deviceRepository.listAllCalls, 1);
    expect(timingRepository.listAllCalls, 1);
    expect(fuelRepository.listAllCalls, 1);
  });
}

class _FakeDeviceRepository implements DeviceRepository {
  int listAllCalls = 0;

  @override
  Future<List<Device>> listAll() async {
    listAllCalls++;
    return const [];
  }

  @override
  Future<List<Device>> listActive() async => const [];

  @override
  Future<Device?> getByIdOrNull(int id) async => null;

  @override
  Future<Device?> findById(int id) => getByIdOrNull(id);

  @override
  Future<int> insert(Device device) async => 1;

  @override
  Future<int> update(Device device) async => 1;

  @override
  Future<int> setActive(int id, bool active) async => 1;

  @override
  Future<int> deleteById(int id) async => 1;
}

class _FakeTimingRepository implements TimingRepository {
  int listAllCalls = 0;

  @override
  Future<List<TimingRecord>> listAll() async {
    listAllCalls++;
    return const [];
  }

  @override
  Future<int> insert(TimingRecord record) async => 1;

  @override
  Future<int> update(TimingRecord record) async => 1;

  @override
  Future<int> deleteById(int id) async => 1;

  @override
  Future<int> deleteByDeviceId(int deviceId) async => 1;
}

class _FakeFuelRepository implements FuelRepository {
  int listAllCalls = 0;

  @override
  Future<List<FuelLog>> listAll() async {
    listAllCalls++;
    return const [];
  }

  @override
  Future<int> insert(FuelLog log) async => 1;

  @override
  Future<int> update(FuelLog log) async => 1;

  @override
  Future<int> deleteById(int id) async => 1;

  @override
  Future<int> deleteByDeviceId(int deviceId) async => 1;
}
