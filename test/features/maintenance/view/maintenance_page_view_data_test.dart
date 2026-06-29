import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/maintenance_record.dart';
import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:asset_ledger/data/models/timing_calculation_history.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/repositories/device_repository.dart';
import 'package:asset_ledger/data/repositories/maintenance_repository.dart';
import 'package:asset_ledger/data/repositories/project_rate_repository.dart';
import 'package:asset_ledger/data/repositories/timing_repository.dart';
import 'package:asset_ledger/features/account/state/account_store.dart';
import 'package:asset_ledger/features/account/state/project_rate_store.dart';
import 'package:asset_ledger/features/device/state/device_store.dart';
import 'package:asset_ledger/features/maintenance/state/maintenance_store.dart';
import 'package:asset_ledger/features/maintenance/view/maintenance_page.dart';
import 'package:asset_ledger/features/maintenance/view/maintenance_page_view_data.dart';
import 'package:asset_ledger/features/timing/state/timing_store.dart';
import 'package:asset_ledger/l10n/gen/app_localizations.dart';
import 'package:asset_ledger/tokens/mapper/summary_card_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  test(
    'builds maintenance rate text from device maintenance and receivable',
    () async {
      final maintenanceStore = MaintenanceStore(
        _FakeMaintenanceRepository([
          MaintenanceRecord(
            id: 1,
            deviceId: 1,
            ymd: 20260629,
            item: '维修',
            amount: 200,
          ),
          MaintenanceRecord(
            id: 2,
            deviceId: 2,
            ymd: 20260629,
            item: '维修',
            amount: 100,
          ),
          MaintenanceRecord(
            id: 3,
            deviceId: 1,
            ymd: 20250629,
            item: '去年维修',
            amount: 500,
          ),
        ]),
      );
      final deviceStore = DeviceStore(
        _FakeDeviceRepository([
          Device(
            id: 1,
            name: 'HITACHI 1#',
            brand: 'HITACHI',
            defaultUnitPrice: 100,
            baseMeterHours: 0,
          ),
          Device(
            id: 2,
            name: 'SANY 2#',
            brand: 'SANY',
            defaultUnitPrice: 100,
            baseMeterHours: 0,
          ),
        ]),
      );

      await Future.wait([maintenanceStore.loadAll(), deviceStore.loadAll()]);

      final viewData = buildMaintenancePageViewData(
        maintenanceStore: maintenanceStore,
        deviceStore: deviceStore,
        inactiveDeviceIndexLabel: '已停用',
        deviceReceivableFenByDevice: const {1: 100000, 2: 0},
        nowYmd: 20260629,
      );

      final first = viewData.summary.deviceSummaries[0];
      final second = viewData.summary.deviceSummaries[1];

      expect(first.deviceName, 'HITACHI 1#');
      expect(first.amount, 200);
      expect(first.maintenanceRateText, '20.0%');
      expect(second.deviceName, 'SANY 2#');
      expect(second.amount, 100);
      expect(second.maintenanceRateText, isNull);
    },
  );

  test('maintenanceRateText hides zero and missing denominator rates', () {
    expect(
      maintenanceRateText(maintenanceAmount: 0, receivableFen: 100000),
      isNull,
    );
    expect(
      maintenanceRateText(maintenanceAmount: 10, receivableFen: null),
      isNull,
    );
    expect(
      maintenanceRateText(maintenanceAmount: 10, receivableFen: 0),
      isNull,
    );
    expect(
      maintenanceRateText(maintenanceAmount: 10, receivableFen: 100000),
      '1.0%',
    );
  });

  testWidgets('maintenance page renders rate beside device summary row', (
    tester,
  ) async {
    final maintenanceStore = MaintenanceStore(
      _FakeMaintenanceRepository([
        MaintenanceRecord(
          id: 1,
          deviceId: 1,
          ymd: 20260629,
          item: '维修',
          amount: 200,
        ),
      ]),
    );
    final deviceStore = DeviceStore(
      _FakeDeviceRepository([
        Device(
          id: 1,
          name: 'HITACHI 1#',
          brand: 'HITACHI',
          defaultUnitPrice: 100,
          baseMeterHours: 0,
        ),
      ]),
    );
    final timingStore = TimingStore(
      _FakeTimingRepository([
        TimingRecord(
          id: 1,
          deviceId: 1,
          startDate: 20260601,
          contact: '张三',
          site: '一号工地',
          type: TimingType.hours,
          startMeter: 0,
          endMeter: 10,
          hours: 10,
          income: 1000,
        ),
      ]),
    );
    final rateStore = ProjectRateStore(_FakeProjectRateRepository());
    final accountStore = AccountStore();

    await Future.wait([
      maintenanceStore.loadAll(),
      deviceStore.loadAll(),
      timingStore.loadAll(),
      rateStore.loadAll(),
      accountStore.loadAll(),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<MaintenanceStore>.value(
              value: maintenanceStore,
            ),
            ChangeNotifierProvider<DeviceStore>.value(value: deviceStore),
            ChangeNotifierProvider<TimingStore>.value(value: timingStore),
            ChangeNotifierProvider<ProjectRateStore>.value(value: rateStore),
            ChangeNotifierProvider<AccountStore>.value(value: accountStore),
          ],
          child: const MaintenancePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rateFinder = find.text('20.0%');
    expect(find.text('HITACHI 1#'), findsWidgets);
    expect(rateFinder, findsOneWidget);

    final rateText = tester.widget<Text>(rateFinder);
    final rateCenterY = tester.getCenter(rateFinder).dy;
    final summaryDeviceFinder = _textOnSameRow(
      tester: tester,
      text: 'HITACHI 1#',
      rowCenterY: rateCenterY,
    );
    final summaryAmountFinder = _textOnSameRow(
      tester: tester,
      text: '¥200',
      rowCenterY: rateCenterY,
    );
    final totalCenterY = tester.getCenter(find.text('合计')).dy;
    final totalAmountFinder = _textOnSameRow(
      tester: tester,
      text: '¥200',
      rowCenterY: totalCenterY,
    );
    final deviceText = tester.widget<Text>(summaryDeviceFinder);

    expect(rateText.style?.fontSize, deviceText.style?.fontSize);
    expect(rateText.style?.fontWeight, deviceText.style?.fontWeight);
    expect(
      tester.getTopRight(summaryAmountFinder).dx,
      closeTo(tester.getTopRight(totalAmountFinder).dx, 1),
    );
    expect(
      tester.getTopLeft(rateFinder).dx,
      greaterThan(
        tester.getTopRight(summaryDeviceFinder).dx +
            SummaryCardTokens.rowRateGap -
            1,
      ),
    );
    expect(
      tester.getTopRight(rateFinder).dx,
      lessThan(tester.getTopLeft(summaryAmountFinder).dx - 24),
    );
  });
}

Finder _textOnSameRow({
  required WidgetTester tester,
  required String text,
  required double rowCenterY,
}) {
  for (final element in find.text(text).evaluate()) {
    final finder = find.byElementPredicate((candidate) => candidate == element);
    final centerY = tester.getCenter(finder).dy;
    if ((centerY - rowCenterY).abs() < 1) return finder;
  }
  throw StateError('Text "$text" was not found on row $rowCenterY.');
}

class _FakeMaintenanceRepository implements MaintenanceRepository {
  _FakeMaintenanceRepository(this._records);

  final List<MaintenanceRecord> _records;

  @override
  Future<List<MaintenanceRecord>> listAll() async => _records;

  @override
  Future<int> insert(MaintenanceRecord record) async =>
      throw UnimplementedError();

  @override
  Future<void> update(MaintenanceRecord record) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteById(int id) async => throw UnimplementedError();

  @override
  Future<int> deleteByDeviceId(int deviceId) async =>
      throw UnimplementedError();
}

class _FakeDeviceRepository implements DeviceRepository {
  _FakeDeviceRepository(this._devices);

  final List<Device> _devices;

  @override
  Future<List<Device>> listAll() async => _devices;

  @override
  Future<List<Device>> listActive() async =>
      _devices.where((device) => device.isActive).toList(growable: false);

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
  Future<int> insert(Device device) async => throw UnimplementedError();

  @override
  Future<int> update(Device device) async => throw UnimplementedError();

  @override
  Future<int> setActive(int id, bool active) async =>
      throw UnimplementedError();

  @override
  Future<int> deleteById(int id) async => throw UnimplementedError();
}

class _FakeTimingRepository implements TimingRepository {
  _FakeTimingRepository(this._records);

  final List<TimingRecord> _records;

  @override
  Future<List<TimingRecord>> listAll() async => _records;

  @override
  Future<int> insert(TimingRecord record) async => throw UnimplementedError();

  @override
  Future<int> update(TimingRecord record) async => throw UnimplementedError();

  @override
  Future<TimingRecord> saveWithCalculationHistories(
    TimingRecord record, {
    List<TimingCalculationHistory> calculationHistories = const [],
  }) async => throw UnimplementedError();

  @override
  Future<int> deleteById(int id) async => throw UnimplementedError();

  @override
  Future<int> deleteByIds(Iterable<int> ids) async =>
      throw UnimplementedError();

  @override
  Future<int> deleteByDeviceId(int deviceId) async =>
      throw UnimplementedError();
}

class _FakeProjectRateRepository implements ProjectRateRepository {
  @override
  Future<List<ProjectDeviceRate>> listAll() async => const [];

  @override
  Future<int> upsert(ProjectDeviceRate rate) async =>
      throw UnimplementedError();

  @override
  Future<int> delete(
    String projectKey,
    int deviceId, {
    String? projectId,
    bool isBreaking = false,
  }) async => throw UnimplementedError();

  @override
  Future<int> deleteByProjectKey(String projectKey) async =>
      throw UnimplementedError();
}
