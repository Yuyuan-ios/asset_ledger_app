import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:asset_ledger/data/models/account_project_merge_group_with_members.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/fuel_log.dart';
import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:asset_ledger/data/models/project_write_off.dart';
import 'package:asset_ledger/data/models/timing_calculation_history.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/repositories/account_payment_repository.dart';
import 'package:asset_ledger/data/repositories/device_repository.dart';
import 'package:asset_ledger/data/repositories/fuel_repository.dart';
import 'package:asset_ledger/data/repositories/project_rate_repository.dart';
import 'package:asset_ledger/data/repositories/timing_repository.dart';
import 'package:asset_ledger/features/account/state/account_payment_store.dart';
import 'package:asset_ledger/features/account/state/account_store.dart';
import 'package:asset_ledger/features/account/state/project_rate_store.dart';
import 'package:asset_ledger/features/device/domain/services/device_business_ledger.dart';
import 'package:asset_ledger/features/device/state/device_store.dart';
import 'package:asset_ledger/features/fuel/state/fuel_store.dart';
import 'package:asset_ledger/features/fuel/view/fuel_page_view_data.dart';
import 'package:asset_ledger/features/timing/state/timing_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'builds fuel lifecycle segments from device business ledger results',
    () async {
      final devices = [
        _device(
          id: 1,
          name: 'SANY 1#',
          initialCostFen: 80000,
          estimatedResidualFen: 60000,
        ),
        _device(id: 2, name: 'CAT 2#'),
      ];
      final fuelStore = FuelStore(
        _FakeFuelRepository([_fuel(deviceId: 1), _fuel(deviceId: 2)]),
      );
      final deviceStore = DeviceStore(_FakeDeviceRepository(devices));
      final timingStore = TimingStore(_FakeTimingRepository(const []));
      final paymentStore = AccountPaymentStore(
        _FakeAccountPaymentRepository(const []),
      );
      final rateStore = ProjectRateStore(_FakeProjectRateRepository(const []));
      final accountStore = AccountStore();
      final ledgerUseCase = _FakeDeviceBusinessLedgerUseCase([
        _ledger(deviceId: 1, receivedFen: 60000),
        _ledger(deviceId: 2, receivedFen: 60000),
      ]);

      await Future.wait([
        fuelStore.loadAll(),
        deviceStore.loadAll(),
        timingStore.loadAll(),
        paymentStore.loadAll(),
        rateStore.loadAll(),
        accountStore.loadAll(),
      ]);

      final viewData = buildFuelPageViewData(
        fuelStore: fuelStore,
        deviceStore: deviceStore,
        timingStore: timingStore,
        paymentStore: paymentStore,
        rateStore: rateStore,
        accountStore: accountStore,
        supplierFilter: '',
        inactiveDeviceIndexLabel: '已停用',
        deviceBusinessLedgerUseCase: ledgerUseCase,
      );
      final result = viewData.lifecyclePaybackByDeviceId[1]!;

      expect(viewData.byDevice.keys, containsAll(<int>[1, 2]));
      expect(viewData.lifecyclePaybackByDeviceId.containsKey(2), isFalse);
      expect(result.visualTotalFen, 120000);
      expect(result.receivedPrincipalSegmentRatio, closeTo(1 / 6, 0.0001));
      expect(result.estimatedResidualSegmentRatio, 0.5);
      expect(result.surplusSegmentRatio, closeTo(1 / 3, 0.0001));
      expect(result.paybackGapSegmentRatio, 0);
    },
  );
}

Device _device({
  required int id,
  required String name,
  int? initialCostFen,
  int? estimatedResidualFen,
}) {
  return Device(
    id: id,
    name: name,
    brand: name.split(' ').first,
    defaultUnitPrice: 100,
    baseMeterHours: 0,
    lifecycleInitialCostFen: initialCostFen,
    lifecycleEstimatedResidualFen: estimatedResidualFen,
  );
}

FuelLog _fuel({required int deviceId}) {
  return FuelLog(
    deviceId: deviceId,
    date: 20260601,
    supplier: 'A',
    liters: 10,
    cost: 100,
  );
}

DeviceBusinessLedger _ledger({
  required int deviceId,
  required int receivedFen,
}) {
  return DeviceBusinessLedger(
    deviceId: deviceId,
    deviceName: 'Device $deviceId',
    incomeFen: 0,
    unitTotals: const [],
    projects: [
      DeviceBusinessProjectHistory(
        projectId: 'p$deviceId',
        projectName: 'Project $deviceId',
        minYmd: 20260601,
        receivableFen: receivedFen,
        receivedFen: receivedFen,
        writeOffFen: 0,
        remainingFen: 0,
        paymentStatus: DeviceBusinessPaymentStatus.paid,
        unitTotals: const [],
      ),
    ],
  );
}

class _FakeDeviceBusinessLedgerUseCase implements DeviceBusinessLedgerUseCase {
  const _FakeDeviceBusinessLedgerUseCase(this.ledgers);

  final List<DeviceBusinessLedger> ledgers;

  @override
  List<DeviceBusinessLedger> execute({
    required List<TimingRecord> timingRecords,
    required List<Device> devices,
    required List<ProjectDeviceRate> rates,
    required List<AccountPayment> payments,
    List<ProjectWriteOff> writeOffs = const [],
    List<AccountProjectMergeGroupWithMembers> activeMergeGroups = const [],
    Set<String> settledProjectIds = const {},
    int? summaryYear,
  }) {
    return ledgers;
  }
}

class _FakeFuelRepository implements FuelRepository {
  const _FakeFuelRepository(this.logs);

  final List<FuelLog> logs;

  @override
  Future<List<FuelLog>> listAll() async => List.of(logs);

  @override
  Future<int> insert(FuelLog log) => throw UnimplementedError();

  @override
  Future<int> update(FuelLog log) => throw UnimplementedError();

  @override
  Future<int> deleteById(int id) => throw UnimplementedError();

  @override
  Future<int> deleteByDeviceId(int deviceId) => throw UnimplementedError();
}

class _FakeDeviceRepository implements DeviceRepository {
  const _FakeDeviceRepository(this.devices);

  final List<Device> devices;

  @override
  Future<List<Device>> listAll() async => List.of(devices);

  @override
  Future<List<Device>> listActive() async {
    return devices.where((device) => device.isActive).toList();
  }

  @override
  Future<Device?> getByIdOrNull(int id) async {
    for (final device in devices) {
      if (device.id == id) return device;
    }
    return null;
  }

  @override
  Future<Device?> findById(int id) => getByIdOrNull(id);

  @override
  Future<int> insert(Device device) => throw UnimplementedError();

  @override
  Future<int> update(Device device) => throw UnimplementedError();

  @override
  Future<int> setActive(int id, bool active) => throw UnimplementedError();

  @override
  Future<int> deleteById(int id) => throw UnimplementedError();
}

class _FakeTimingRepository implements TimingRepository {
  const _FakeTimingRepository(this.records);

  final List<TimingRecord> records;

  @override
  Future<List<TimingRecord>> listAll() async => List.of(records);

  @override
  Future<int> insert(TimingRecord record) => throw UnimplementedError();

  @override
  Future<int> update(TimingRecord record) => throw UnimplementedError();

  @override
  Future<TimingRecord> saveWithCalculationHistories(
    TimingRecord record, {
    List<TimingCalculationHistory> calculationHistories = const [],
  }) {
    throw UnimplementedError();
  }

  @override
  Future<int> deleteById(int id) => throw UnimplementedError();

  @override
  Future<int> deleteByIds(Iterable<int> ids) => throw UnimplementedError();

  @override
  Future<int> deleteByDeviceId(int deviceId) => throw UnimplementedError();
}

class _FakeAccountPaymentRepository implements AccountPaymentRepository {
  const _FakeAccountPaymentRepository(this.records);

  final List<AccountPayment> records;

  @override
  Future<List<AccountPayment>> listAll() async => List.of(records);

  @override
  Future<int> insert(AccountPayment payment) => throw UnimplementedError();

  @override
  Future<void> insertAllInTransaction(List<AccountPayment> payments) {
    throw UnimplementedError();
  }

  @override
  Future<List<AccountPayment>> listByMergeBatchId(String batchId) {
    throw UnimplementedError();
  }

  @override
  Future<int> deleteByMergeBatchId(String batchId) {
    throw UnimplementedError();
  }

  @override
  Future<void> replaceMergeBatchInTransaction({
    required String batchId,
    required List<AccountPayment> newRows,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<int> update(AccountPayment payment) => throw UnimplementedError();

  @override
  Future<int> deleteById(int id) => throw UnimplementedError();
}

class _FakeProjectRateRepository implements ProjectRateRepository {
  const _FakeProjectRateRepository(this.rates);

  final List<ProjectDeviceRate> rates;

  @override
  Future<List<ProjectDeviceRate>> listAll() async => List.of(rates);

  @override
  Future<int> upsert(ProjectDeviceRate rate) => throw UnimplementedError();

  @override
  Future<int> delete(
    String projectKey,
    int deviceId, {
    String? projectId,
    bool isBreaking = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<int> deleteByProjectKey(String projectKey) {
    throw UnimplementedError();
  }
}
