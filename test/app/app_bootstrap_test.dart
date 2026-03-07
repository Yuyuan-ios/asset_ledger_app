import 'package:asset_ledger/app/app_bootstrap.dart';
import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/fuel_log.dart';
import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/repositories/account_payment_repository.dart';
import 'package:asset_ledger/data/repositories/device_repository.dart';
import 'package:asset_ledger/data/repositories/fuel_repository.dart';
import 'package:asset_ledger/data/repositories/project_rate_repository.dart';
import 'package:asset_ledger/data/repositories/timing_repository.dart';
import 'package:asset_ledger/features/account/state/account_payment_store.dart';
import 'package:asset_ledger/features/account/state/project_rate_store.dart';
import 'package:asset_ledger/features/device/state/device_store.dart';
import 'package:asset_ledger/features/fuel/state/fuel_store.dart';
import 'package:asset_ledger/features/timing/state/timing_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppBootstrap.preload loads all needed stores without BuildContext', () async {
    final deviceRepository = _FakeDeviceRepository();
    final timingRepository = _FakeTimingRepository();
    final fuelRepository = _FakeFuelRepository();
    final paymentRepository = _FakeAccountPaymentRepository();
    final rateRepository = _FakeProjectRateRepository();

    final deviceStore = DeviceStore(deviceRepository);
    final timingStore = TimingStore(timingRepository);
    final fuelStore = FuelStore(fuelRepository);
    final paymentStore = AccountPaymentStore(paymentRepository);
    final projectRateStore = ProjectRateStore(rateRepository);

    await AppBootstrap.preload(
      deviceStore: deviceStore,
      timingStore: timingStore,
      fuelStore: fuelStore,
      paymentStore: paymentStore,
      projectRateStore: projectRateStore,
    );

    expect(deviceRepository.listAllCalls, 1);
    expect(timingRepository.listAllCalls, 1);
    expect(fuelRepository.listAllCalls, 1);
    expect(paymentRepository.listAllCalls, 1);
    expect(rateRepository.listAllCalls, 1);
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

class _FakeAccountPaymentRepository implements AccountPaymentRepository {
  int listAllCalls = 0;

  @override
  Future<List<AccountPayment>> listAll() async {
    listAllCalls++;
    return const [];
  }

  @override
  Future<int> insert(AccountPayment payment) async => 1;

  @override
  Future<int> update(AccountPayment payment) async => 1;

  @override
  Future<int> deleteById(int id) async => 1;
}

class _FakeProjectRateRepository implements ProjectRateRepository {
  int listAllCalls = 0;

  @override
  Future<List<ProjectDeviceRate>> listAll() async {
    listAllCalls++;
    return const [];
  }

  @override
  Future<int> upsert(ProjectDeviceRate rate) async => 1;

  @override
  Future<int> delete(
    String projectKey,
    int deviceId, {
    bool isBreaking = false,
  }) async => 1;

  @override
  Future<int> deleteByProjectKey(String projectKey) async => 1;
}
