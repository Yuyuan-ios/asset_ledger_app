import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/external_import_batch.dart';
import 'package:asset_ledger/data/models/external_work_record.dart';
import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:asset_ledger/data/models/project_id.dart';
import 'package:asset_ledger/data/models/timing_calculation_history.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/repositories/account_payment_repository.dart';
import 'package:asset_ledger/data/repositories/device_repository.dart';
import 'package:asset_ledger/data/repositories/external_import_repository.dart';
import 'package:asset_ledger/data/repositories/external_work_record_repository.dart';
import 'package:asset_ledger/data/repositories/project_rate_repository.dart';
import 'package:asset_ledger/data/repositories/timing_repository.dart';
import 'package:asset_ledger/features/account/state/account_filter_store.dart';
import 'package:asset_ledger/features/account/state/account_payment_store.dart';
import 'package:asset_ledger/features/account/state/account_store.dart';
import 'package:asset_ledger/features/account/state/project_rate_store.dart';
import 'package:asset_ledger/features/account/view/account_page.dart';
import 'package:asset_ledger/features/device/state/device_store.dart';
import 'package:asset_ledger/features/timing/state/timing_external_work_store.dart';
import 'package:asset_ledger/features/timing/state/timing_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'AccountPage splits owned projects and independent external work tabs',
    (tester) async {
      final timingStore = TimingStore(_FakeTimingRepository());
      final deviceStore = DeviceStore(_FakeDeviceRepository());
      final paymentStore = AccountPaymentStore(_FakePaymentRepository());
      final rateStore = ProjectRateStore(_FakeRateRepository());
      final accountStore = AccountStore();
      final externalWorkStore = TimingExternalWorkStore(
        importRepository: _FakeExternalImportRepository(),
        recordRepository: _FakeExternalWorkRecordRepository(),
      );

      await Future.wait([
        timingStore.loadAll(),
        deviceStore.loadAll(),
        paymentStore.loadAll(),
        rateStore.loadAll(),
        accountStore.loadAll(),
        externalWorkStore.loadAll(),
      ]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<TimingStore>.value(value: timingStore),
            ChangeNotifierProvider<DeviceStore>.value(value: deviceStore),
            ChangeNotifierProvider<AccountPaymentStore>.value(
              value: paymentStore,
            ),
            ChangeNotifierProvider<ProjectRateStore>.value(value: rateStore),
            ChangeNotifierProvider<AccountStore>.value(value: accountStore),
            ChangeNotifierProvider<TimingExternalWorkStore>.value(
              value: externalWorkStore,
            ),
            ChangeNotifierProvider<AccountFilterStore>(
              create: (_) => AccountFilterStore(),
            ),
          ],
          child: const MaterialApp(home: AccountPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('项目(1)'), findsOneWidget);
      expect(find.text('外协项目(1)'), findsNothing);
      expect(find.text('李杰 · 新村').hitTestable(), findsOneWidget);
      expect(find.text('外协项目').hitTestable(), findsNothing);
      expect(find.text('余远 · 鲜滩、尚义').hitTestable(), findsNothing);
      expect(find.text('王强 · 已关联工地'), findsNothing);
      expect(find.text('总应收'), findsOneWidget);
      // §6.4/§6.5 隔离红线：总览总应收只含本地设备应收 ¥1000,
      // 外协设备应收一律不混入(外协金额在外协独立分区单独展示)。
      expect(find.text('¥1000'), findsWidgets);
      expect(find.text('¥14518'), findsNothing);

      await tester.drag(find.byType(TabBarView), const Offset(-500, 0));
      await tester.pumpAndSettle();

      // 已关联外协包仍显示在外协页 → 共 2 个外协卡片（含链条角标）。
      expect(find.text('外协项目(2)'), findsOneWidget);
      expect(find.text('项目(1)'), findsNothing);
      expect(find.text('李杰 · 新村').hitTestable(), findsNothing);
      expect(find.text('外协项目').hitTestable(), findsNothing);
      expect(find.text('余远 · 鲜滩、尚义').hitTestable(), findsOneWidget);
      expect(find.text('王强 · 已关联工地').hitTestable(), findsOneWidget);
      expect(find.text('外协应付'), findsNWidgets(2));
      expect(find.text('应收项目款'), findsNWidgets(2));
      expect(find.text('客户应收'), findsNothing);
      expect(find.text('¥12618').hitTestable(), findsOneWidget);
      expect(find.text('待设置'), findsNWidgets(2));
      expect(find.text('待计算'), findsNWidgets(2));
      // 仅已关联外协卡片显示链条角标。
      expect(
        find.byKey(const Key('account-external-work-card-link-badge')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('account-page-bottom-navigation-spacer')),
        findsOneWidget,
      );

      await tester.drag(find.byType(TabBarView), const Offset(500, 0));
      await tester.pumpAndSettle();

      expect(find.text('项目(1)'), findsOneWidget);
      expect(find.text('李杰 · 新村').hitTestable(), findsOneWidget);
      expect(find.text('外协项目').hitTestable(), findsNothing);
    },
  );

  testWidgets('AccountPage project detail uses external-work augmented total', (
    tester,
  ) async {
    final timingStore = TimingStore(_FakeTimingRepository());
    final deviceStore = DeviceStore(_FakeDeviceRepository());
    final paymentStore = AccountPaymentStore(_FakePaymentRepository());
    final rateStore = ProjectRateStore(_FakeRateRepository());
    final accountStore = AccountStore();
    final externalWorkStore = TimingExternalWorkStore(
      importRepository: _FakeExternalImportRepository(),
      recordRepository: _FakeExternalWorkRecordRepository(),
    );

    await Future.wait([
      timingStore.loadAll(),
      deviceStore.loadAll(),
      paymentStore.loadAll(),
      rateStore.loadAll(),
      accountStore.loadAll(),
      externalWorkStore.loadAll(),
    ]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TimingStore>.value(value: timingStore),
          ChangeNotifierProvider<DeviceStore>.value(value: deviceStore),
          ChangeNotifierProvider<AccountPaymentStore>.value(
            value: paymentStore,
          ),
          ChangeNotifierProvider<ProjectRateStore>.value(value: rateStore),
          ChangeNotifierProvider<AccountStore>.value(value: accountStore),
          ChangeNotifierProvider<TimingExternalWorkStore>.value(
            value: externalWorkStore,
          ),
          ChangeNotifierProvider<AccountFilterStore>(
            create: (_) => AccountFilterStore(),
          ),
        ],
        child: const MaterialApp(home: AccountPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('李杰 · 新村').hitTestable());
    await tester.pumpAndSettle();

    expect(find.text('项目详情'), findsOneWidget);
    // 隔离红线：项目详情总额只含我方应收,不混入已关联外协包金额。
    expect(find.text('项目总额 ¥1000'), findsOneWidget);
    expect(find.text('项目总额 ¥1900'), findsNothing);
  });

  testWidgets(
    'AccountPage project detail keeps local total without linked external work',
    (tester) async {
      final timingStore = TimingStore(_FakeTimingRepository());
      final deviceStore = DeviceStore(_FakeDeviceRepository());
      final paymentStore = AccountPaymentStore(_FakePaymentRepository());
      final rateStore = ProjectRateStore(_FakeRateRepository());
      final accountStore = AccountStore();
      final externalWorkStore = TimingExternalWorkStore(
        importRepository: _FakeExternalImportRepository(),
        recordRepository: _FakeExternalWorkRecordRepository(
          linkToLocalProject: false,
        ),
      );

      await Future.wait([
        timingStore.loadAll(),
        deviceStore.loadAll(),
        paymentStore.loadAll(),
        rateStore.loadAll(),
        accountStore.loadAll(),
        externalWorkStore.loadAll(),
      ]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<TimingStore>.value(value: timingStore),
            ChangeNotifierProvider<DeviceStore>.value(value: deviceStore),
            ChangeNotifierProvider<AccountPaymentStore>.value(
              value: paymentStore,
            ),
            ChangeNotifierProvider<ProjectRateStore>.value(value: rateStore),
            ChangeNotifierProvider<AccountStore>.value(value: accountStore),
            ChangeNotifierProvider<TimingExternalWorkStore>.value(
              value: externalWorkStore,
            ),
            ChangeNotifierProvider<AccountFilterStore>(
              create: (_) => AccountFilterStore(),
            ),
          ],
          child: const MaterialApp(home: AccountPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('李杰 · 新村').hitTestable());
      await tester.pumpAndSettle();

      expect(find.text('项目详情'), findsOneWidget);
      expect(find.text('项目总额 ¥1000'), findsOneWidget);
      expect(find.text('项目总额 ¥1900'), findsNothing);
    },
  );
}

class _FakeTimingRepository implements TimingRepository {
  @override
  Future<List<TimingRecord>> listAll() async {
    return const [
      TimingRecord(
        id: 1,
        deviceId: 1,
        startDate: 20260501,
        contact: '李杰',
        site: '新村',
        type: TimingType.hours,
        startMeter: 0,
        endMeter: 10,
        hours: 10,
        income: 0,
      ),
    ];
  }

  @override
  Future<int> insert(TimingRecord record) async => 1;

  @override
  Future<int> update(TimingRecord record) async => 1;

  @override
  Future<TimingRecord> saveWithCalculationHistories(
    TimingRecord record, {
    List<TimingCalculationHistory> calculationHistories = const [],
  }) async => record;

  @override
  Future<int> deleteById(int id) async => 1;

  @override
  Future<int> deleteByIds(Iterable<int> ids) async => ids.length;

  @override
  Future<int> deleteByDeviceId(int deviceId) async => 1;
}

class _FakeDeviceRepository implements DeviceRepository {
  @override
  Future<List<Device>> listAll() async {
    return [
      Device(
        id: 1,
        name: 'HITACHI 1#',
        brand: 'HITACHI',
        defaultUnitPrice: 100,
        baseMeterHours: 0,
      ),
    ];
  }

  @override
  Future<List<Device>> listActive() => listAll();

  @override
  Future<Device?> getByIdOrNull(int id) async => (await listAll()).first;

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

class _FakePaymentRepository implements AccountPaymentRepository {
  @override
  Future<List<AccountPayment>> listAll() async => const [];

  @override
  Future<int> insert(AccountPayment payment) async => 1;

  @override
  Future<void> insertAllInTransaction(List<AccountPayment> payments) async {}

  @override
  Future<List<AccountPayment>> listByMergeBatchId(String batchId) async =>
      const [];

  @override
  Future<int> deleteByMergeBatchId(String batchId) async => 0;

  @override
  Future<void> replaceMergeBatchInTransaction({
    required String batchId,
    required List<AccountPayment> newRows,
  }) async {}

  @override
  Future<int> update(AccountPayment payment) async => 1;

  @override
  Future<int> deleteById(int id) async => 1;
}

class _FakeRateRepository implements ProjectRateRepository {
  @override
  Future<List<ProjectDeviceRate>> listAll() async => const [];

  @override
  Future<int> upsert(ProjectDeviceRate rate) async => 1;

  @override
  Future<int> delete(
    String projectKey,
    int deviceId, {
    String? projectId,
    bool isBreaking = false,
  }) async => 1;

  @override
  Future<int> deleteByProjectKey(String projectKey) async => 1;
}

class _FakeExternalImportRepository implements ExternalImportRepository {
  @override
  Future<void> insertBatch(ExternalImportBatch batch) async {}

  @override
  Future<ExternalImportBatch?> findBatchById(String id) async {
    for (final batch in await listBatches()) {
      if (batch.id == id) return batch;
    }
    return null;
  }

  @override
  Future<List<ExternalImportBatch>> listBatches() async {
    return [
      _batch(
        id: 'external-unlinked',
        sourceDisplayName: '余远',
        siteSummary: '鲜滩+尚义',
      ),
      _batch(
        id: 'external-linked',
        sourceDisplayName: '王强',
        siteSummary: '已关联工地',
      ),
    ];
  }
}

class _FakeExternalWorkRecordRepository
    implements ExternalWorkRecordRepository {
  _FakeExternalWorkRecordRepository({this.linkToLocalProject = true});

  final bool linkToLocalProject;

  @override
  Future<void> insertRecord(ExternalWorkRecord record) async {}

  @override
  Future<void> insertRecords(List<ExternalWorkRecord> records) async {}

  @override
  Future<List<ExternalWorkRecord>> listByBatchId(String batchId) async {
    switch (batchId) {
      case 'external-unlinked':
        return [
          _record(
            id: 'external-record-a',
            batchId: batchId,
            site: '鲜滩',
            workDate: 20260503,
            amountFen: 61800,
          ),
          _record(
            id: 'external-record-b',
            batchId: batchId,
            site: '尚义',
            workDate: 20260504,
            amountFen: 1200000,
          ),
        ];
      case 'external-linked':
        return [
          _record(
            id: 'external-record-c',
            batchId: batchId,
            site: '已关联工地',
            workDate: 20260505,
            amountFen: 90000,
            linkedProjectId: linkToLocalProject
                ? ProjectId.legacyFromParts(contact: '李杰', site: '新村')
                : null,
          ),
        ];
      default:
        return const [];
    }
  }

  @override
  Future<List<ExternalWorkRecord>> listByLinkedProjectId(
    String projectId,
  ) async => const [];

  @override
  Future<int> deleteById(String recordId) async => 0;

  @override
  Future<int> deleteByBatchId(String batchId) async => 0;

  @override
  Future<int> linkBatchToProject({
    required String importBatchId,
    required String projectId,
    required String updatedAt,
  }) async => 0;

  @override
  Future<int> linkBatchToProjectWithSettlementReset({
    required String importBatchId,
    required String projectId,
    required String updatedAt,
  }) async => 0;

  @override
  Future<int> unlinkBatch({
    required String importBatchId,
    required String updatedAt,
  }) async => 0;

  @override
  Future<String?> getLinkedProjectId(String importBatchId) async => null;

  @override
  Future<int> updateLocalFields({
    required String recordId,
    int? localUnitPriceFen,
    Object? linkedProjectId = _externalSentinel,
    ExternalWorkRecordStatus? status,
    Object? note = _externalSentinel,
    required String updatedAt,
  }) async => 0;
}

ExternalImportBatch _batch({
  required String id,
  required String sourceDisplayName,
  required String siteSummary,
}) {
  return ExternalImportBatch(
    id: id,
    sourceShareId: 'share-$id',
    sourceDisplayName: sourceDisplayName,
    recordCount: 1,
    totalHoursMilli: 1000,
    totalAmountFen: 10000,
    siteSummary: siteSummary,
    importedAt: '2026-05-24T00:00:00.000',
    createdAt: '2026-05-24T00:00:00.000',
    updatedAt: '2026-05-24T00:00:00.000',
  );
}

ExternalWorkRecord _record({
  required String id,
  required String batchId,
  required String site,
  required int workDate,
  required int amountFen,
  String? linkedProjectId,
}) {
  return ExternalWorkRecord.imported(
    id: id,
    importBatchId: batchId,
    sourceShareId: 'share-$batchId',
    sourceRecordUuid: 'source-$id',
    sourceInstallationUuid: 'installation-$id',
    originFingerprint: 'fingerprint-$id',
    collaboratorName: '余远',
    contactSnapshot: '余远',
    siteSnapshot: site,
    workDate: workDate,
    hoursMilli: 1000,
    amountFen: amountFen,
    linkedProjectId: linkedProjectId,
    createdAt: '2026-05-24T00:00:00.000',
    updatedAt: '2026-05-24T00:00:00.000',
  );
}

const _externalSentinel = Object();
