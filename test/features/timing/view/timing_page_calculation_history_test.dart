import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/fuel_log.dart';
import 'package:asset_ledger/data/models/maintenance_record.dart';
import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/repositories/device_repository.dart';
import 'package:asset_ledger/data/repositories/fuel_repository.dart';
import 'package:asset_ledger/data/repositories/maintenance_repository.dart';
import 'package:asset_ledger/data/repositories/project_rate_repository.dart';
import 'package:asset_ledger/data/repositories/timing_repository.dart';
import 'package:asset_ledger/features/account/state/project_rate_store.dart';
import 'package:asset_ledger/features/device/state/device_store.dart';
import 'package:asset_ledger/features/fuel/state/fuel_store.dart';
import 'package:asset_ledger/features/maintenance/state/maintenance_store.dart';
import 'package:asset_ledger/features/timing/calculator/model/timing_calculation_history.dart';
import 'package:asset_ledger/features/timing/calculator/repository/timing_calculation_history_repository.dart';
import 'package:asset_ledger/features/timing/state/timing_store.dart';
import 'package:asset_ledger/features/timing/view/timing_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('loads existing calculation histories when editing a record', (
    WidgetTester tester,
  ) async {
    final historyRepository = _FakeCalculationHistoryRepository(
      histories: [_history()],
    );

    await _pumpTimingPage(tester, historyRepository: historyRepository);

    await tester.tap(find.text('甲方·一号工地'));
    await tester.pumpAndSettle();

    expect(historyRepository.findCalls, [7]);
    expect(find.text('编辑计时'), findsOneWidget);

    await tester.tap(find.byTooltip('工时计算依据'));
    await tester.pumpAndSettle();

    expect(find.textContaining('[已保存]'), findsOneWidget);
    expect(find.text('8 + 8 = 16.0 h'), findsOneWidget);
  });

  testWidgets('does not query calculation histories for new records', (
    WidgetTester tester,
  ) async {
    final historyRepository = _FakeCalculationHistoryRepository();

    await _pumpTimingPage(tester, historyRepository: historyRepository);

    await tester.tap(find.text('+ 新建'));
    await tester.pumpAndSettle();

    expect(historyRepository.findCalls, isEmpty);
    expect(find.text('新建计时'), findsOneWidget);
  });

  testWidgets('does not query or show calculator histories for rent records', (
    WidgetTester tester,
  ) async {
    final historyRepository = _FakeCalculationHistoryRepository(
      histories: [_history()],
    );

    await _pumpTimingPage(
      tester,
      timingRepository: _FakeTimingRepository(
        seed: [_record(type: TimingType.rent)],
      ),
      historyRepository: historyRepository,
    );

    await tester.tap(find.text('甲方·一号工地'));
    await tester.pumpAndSettle();

    expect(historyRepository.findCalls, isEmpty);
    expect(find.text('编辑计时'), findsOneWidget);
    expect(find.byTooltip('工时计算依据'), findsNothing);
  });

  testWidgets('history load failure does not block opening the editor', (
    WidgetTester tester,
  ) async {
    final historyRepository = _FakeCalculationHistoryRepository(
      shouldThrow: true,
    );

    await _pumpTimingPage(tester, historyRepository: historyRepository);

    await tester.tap(find.text('甲方·一号工地'));
    await tester.pumpAndSettle();

    expect(historyRepository.findCalls, [7]);
    expect(find.text('编辑计时'), findsOneWidget);
    expect(find.byTooltip('工时计算依据'), findsOneWidget);
  });

  testWidgets('canceling the editor does not save staged histories', (
    WidgetTester tester,
  ) async {
    final timingRepository = _FakeTimingRepository(seed: [_record()]);

    await _pumpTimingPage(
      tester,
      timingRepository: timingRepository,
      historyRepository: _FakeCalculationHistoryRepository(),
    );

    await tester.tap(find.text('甲方·一号工地'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();

    expect(timingRepository.saveCalls, 0);
    expect(timingRepository.savedCalculationHistories, isEmpty);
  });
}

Future<void> _pumpTimingPage(
  WidgetTester tester, {
  _FakeTimingRepository? timingRepository,
  required TimingCalculationHistoryRepository historyRepository,
}) async {
  tester.view.physicalSize = const Size(800, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final deviceRepository = _FakeDeviceRepository(seed: [_device()]);
  final resolvedTimingRepository =
      timingRepository ?? _FakeTimingRepository(seed: [_record()]);
  final fuelRepository = _FakeFuelRepository();
  final maintenanceRepository = _FakeMaintenanceRepository();
  final rateRepository = _FakeProjectRateRepository();

  final deviceStore = DeviceStore(deviceRepository);
  final timingStore = TimingStore(resolvedTimingRepository);
  final fuelStore = FuelStore(fuelRepository);
  final maintenanceStore = MaintenanceStore(maintenanceRepository);
  final rateStore = ProjectRateStore(rateRepository);

  await deviceStore.loadAll();
  await timingStore.loadAll();
  await fuelStore.loadAll();
  await maintenanceStore.loadAll();
  await rateStore.loadAll();

  await tester.pumpWidget(
    MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<DeviceStore>.value(value: deviceStore),
          ChangeNotifierProvider<TimingStore>.value(value: timingStore),
          ChangeNotifierProvider<FuelStore>.value(value: fuelStore),
          ChangeNotifierProvider<MaintenanceStore>.value(
            value: maintenanceStore,
          ),
          ChangeNotifierProvider<ProjectRateStore>.value(value: rateStore),
        ],
        child: TimingPage(calculationHistoryRepository: historyRepository),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Device _device() {
  return const Device(
    id: 1,
    name: 'SANY 1#',
    brand: 'SANY',
    defaultUnitPrice: 100,
    baseMeterHours: 0,
  );
}

TimingRecord _record({TimingType type = TimingType.hours}) {
  return TimingRecord(
    id: 7,
    deviceId: 1,
    startDate: 20260514,
    contact: '甲方',
    site: '一号工地',
    type: type,
    startMeter: 0,
    endMeter: 16,
    hours: 16,
    income: 1600,
  );
}

TimingCalculationHistory _history() {
  return TimingCalculationHistory(
    id: 'saved-h1',
    timingRecordId: 7,
    createdAt: DateTime.utc(2026, 5, 13, 18, 20),
    expression: '8+8',
    result: 16.0,
    ticketCount: 2,
  );
}

class _FakeCalculationHistoryRepository
    implements TimingCalculationHistoryRepository {
  _FakeCalculationHistoryRepository({
    this.histories = const [],
    this.shouldThrow = false,
  });

  final List<TimingCalculationHistory> histories;
  final bool shouldThrow;
  final List<int> findCalls = [];

  @override
  Future<List<TimingCalculationHistory>> findByTimingRecordId(
    int timingRecordId,
  ) async {
    findCalls.add(timingRecordId);
    if (shouldThrow) throw Exception('load failed');
    return histories
        .where((history) => history.timingRecordId == timingRecordId)
        .toList();
  }

  @override
  Future<void> insertMany(
    int timingRecordId,
    List<TimingCalculationHistory> histories,
  ) async {}

  @override
  Future<void> deleteByTimingRecordId(int timingRecordId) async {}
}

class _FakeTimingRepository implements TimingRepository {
  _FakeTimingRepository({required List<TimingRecord> seed})
    : _records = List.of(seed);

  final List<TimingRecord> _records;
  final List<List<TimingCalculationHistory>> savedCalculationHistories = [];
  var saveCalls = 0;

  @override
  Future<List<TimingRecord>> listAll() async => List.of(_records);

  @override
  Future<int> insert(TimingRecord record) async => 1;

  @override
  Future<int> update(TimingRecord record) async => 1;

  @override
  Future<TimingRecord> saveWithCalculationHistories(
    TimingRecord record, {
    List<TimingCalculationHistory> calculationHistories = const [],
  }) async {
    saveCalls++;
    savedCalculationHistories.add(List.of(calculationHistories));
    return record.id == null ? record.copyWith(id: 1) : record;
  }

  @override
  Future<int> deleteById(int id) async => 1;

  @override
  Future<int> deleteByIds(Iterable<int> ids) async => ids.length;

  @override
  Future<int> deleteByDeviceId(int deviceId) async => 1;
}

class _FakeDeviceRepository implements DeviceRepository {
  _FakeDeviceRepository({required List<Device> seed}) : _devices = seed;

  final List<Device> _devices;

  @override
  Future<List<Device>> listAll() async => List.of(_devices);

  @override
  Future<List<Device>> listActive() async {
    return _devices.where((device) => device.isActive).toList();
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
  Future<int> insert(Device device) async => 1;

  @override
  Future<int> update(Device device) async => 1;

  @override
  Future<int> setActive(int id, bool active) async => 1;

  @override
  Future<int> deleteById(int id) async => 1;
}

class _FakeFuelRepository implements FuelRepository {
  @override
  Future<List<FuelLog>> listAll() async => const [];

  @override
  Future<int> insert(FuelLog log) async => 1;

  @override
  Future<int> update(FuelLog log) async => 1;

  @override
  Future<int> deleteById(int id) async => 1;

  @override
  Future<int> deleteByDeviceId(int deviceId) async => 1;
}

class _FakeMaintenanceRepository implements MaintenanceRepository {
  @override
  Future<List<MaintenanceRecord>> listAll() async => const [];

  @override
  Future<int> insert(MaintenanceRecord record) async => 1;

  @override
  Future<void> update(MaintenanceRecord record) async {}

  @override
  Future<void> deleteById(int id) async {}
}

class _FakeProjectRateRepository implements ProjectRateRepository {
  @override
  Future<List<ProjectDeviceRate>> listAll() async => const [];

  @override
  Future<int> upsert(ProjectDeviceRate rate) async => 1;

  @override
  Future<int> delete(
    String projectKey,
    int deviceId, {
    bool isBreaking = false,
  }) async {
    return 1;
  }

  @override
  Future<int> deleteByProjectKey(String projectKey) async => 1;
}
