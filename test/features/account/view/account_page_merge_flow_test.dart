import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:asset_ledger/data/models/account_project_merge_group.dart';
import 'package:asset_ledger/data/models/account_project_merge_group_with_members.dart';
import 'package:asset_ledger/data/models/account_project_merge_member.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/repositories/account_payment_repository.dart';
import 'package:asset_ledger/data/repositories/account_project_merge_repository.dart';
import 'package:asset_ledger/data/repositories/device_repository.dart';
import 'package:asset_ledger/data/repositories/project_rate_repository.dart';
import 'package:asset_ledger/data/repositories/timing_repository.dart';
import 'package:asset_ledger/data/services/account_project_merge_service.dart';
import 'package:asset_ledger/features/account/application/controllers/account_action_controller.dart';
import 'package:asset_ledger/features/account/domain/repositories/project_settlement_repository.dart';
import 'package:asset_ledger/features/account/state/account_filter_store.dart';
import 'package:asset_ledger/features/account/state/account_payment_store.dart';
import 'package:asset_ledger/features/account/state/account_store.dart';
import 'package:asset_ledger/features/account/state/project_rate_store.dart';
import 'package:asset_ledger/features/account/use_cases/project_settlement_use_case.dart';
import 'package:asset_ledger/features/account/view/account_page.dart';
import 'package:asset_ledger/features/device/state/device_store.dart';
import 'package:asset_ledger/data/models/timing_calculation_history.dart';
import 'package:asset_ledger/features/timing/state/timing_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'AccountPage creates merge group and refreshes active merge groups',
    (tester) async {
      final mergeRepository = _FakeMergeRepository();
      final mergeService = AccountProjectMergeService(
        repository: mergeRepository,
        now: () => DateTime.utc(2026, 5, 15),
      );
      final accountStore = AccountStore(mergeService: mergeService);
      final timingStore = TimingStore(_FakeTimingRepository());
      final deviceStore = DeviceStore(_FakeDeviceRepository());
      final paymentRepository = _FakePaymentRepository();
      final paymentStore = AccountPaymentStore(paymentRepository);
      final rateStore = ProjectRateStore(_FakeRateRepository());

      await Future.wait([
        timingStore.loadAll(),
        deviceStore.loadAll(),
        paymentStore.loadAll(),
        rateStore.loadAll(),
        accountStore.loadAll(),
      ]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AccountProjectMergeService>.value(value: mergeService),
            Provider<AccountPaymentRepository>.value(value: paymentRepository),
            _accountActionControllerProvider(paymentRepository, mergeService),
            ChangeNotifierProvider<TimingStore>.value(value: timingStore),
            ChangeNotifierProvider<DeviceStore>.value(value: deviceStore),
            ChangeNotifierProvider<AccountPaymentStore>.value(
              value: paymentStore,
            ),
            ChangeNotifierProvider<ProjectRateStore>.value(value: rateStore),
            ChangeNotifierProvider<AccountStore>.value(value: accountStore),
            ChangeNotifierProvider<AccountFilterStore>(
              create: (_) => AccountFilterStore(),
            ),
          ],
          child: const MaterialApp(home: AccountPage()),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('合并'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).at(0));
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();

      expect(mergeRepository.createdContact, '李杰');
      expect(
        mergeRepository.createdProjectKeys,
        unorderedEquals(['李杰||新村', '李杰||高桥']),
      );
      expect(mergeRepository.listActiveGroupsWithMembersCalls, greaterThan(1));
      expect(accountStore.activeMergeGroups, hasLength(1));
      expect(find.text('李杰•合并2项目'), findsOneWidget);
    },
  );

  testWidgets('AccountPage dissolves merge group from merged project detail', (
    tester,
  ) async {
    final mergeRepository = _FakeMergeRepository(activeGroup: true);
    final mergeService = AccountProjectMergeService(
      repository: mergeRepository,
      now: () => DateTime.utc(2026, 5, 15),
    );
    final accountStore = AccountStore(mergeService: mergeService);
    final timingStore = TimingStore(_FakeTimingRepository());
    final deviceStore = DeviceStore(_FakeDeviceRepository());
    final paymentRepository = _FakePaymentRepository();
    final paymentStore = AccountPaymentStore(paymentRepository);
    final rateStore = ProjectRateStore(_FakeRateRepository());

    await Future.wait([
      timingStore.loadAll(),
      deviceStore.loadAll(),
      paymentStore.loadAll(),
      rateStore.loadAll(),
      accountStore.loadAll(),
    ]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AccountProjectMergeService>.value(value: mergeService),
          Provider<AccountPaymentRepository>.value(value: paymentRepository),
          _accountActionControllerProvider(paymentRepository, mergeService),
          ChangeNotifierProvider<TimingStore>.value(value: timingStore),
          ChangeNotifierProvider<DeviceStore>.value(value: deviceStore),
          ChangeNotifierProvider<AccountPaymentStore>.value(
            value: paymentStore,
          ),
          ChangeNotifierProvider<ProjectRateStore>.value(value: rateStore),
          ChangeNotifierProvider<AccountStore>.value(value: accountStore),
          ChangeNotifierProvider<AccountFilterStore>(
            create: (_) => AccountFilterStore(),
          ),
        ],
        child: const MaterialApp(home: AccountPage()),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('李杰•合并2项目'), findsOneWidget);
    expect(find.text('李杰•新村'), findsNothing);

    await tester.tap(find.text('李杰•合并2项目'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('解除合并'));
    await tester.pumpAndSettle();

    expect(find.text('解除合并？'), findsOneWidget);
    expect(find.text('李杰 + 新村'), findsOneWidget);
    expect(find.text('李杰 + 高桥'), findsOneWidget);

    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();
    expect(mergeRepository.dissolveGroupCalls, 0);
    expect(find.text('解除合并'), findsOneWidget);

    await tester.tap(find.text('解除合并'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('解除合并').last);
    await tester.pumpAndSettle();

    expect(mergeRepository.dissolveGroupCalls, 1);
    expect(mergeRepository.dissolvedGroupId, 1);
    expect(mergeRepository.listActiveGroupsWithMembersCalls, greaterThan(1));
    expect(accountStore.activeMergeGroups, isEmpty);
    expect(find.text('已解除合并'), findsOneWidget);
    expect(find.text('解除合并'), findsNothing);
    expect(find.text('李杰•合并2项目'), findsNothing);
    expect(find.text('李杰•新村'), findsOneWidget);
    expect(find.text('李杰•高桥'), findsOneWidget);
  });

  testWidgets(
    'AccountPage keeps detail open and shows error when dissolve fails',
    (tester) async {
      final mergeRepository = _FakeMergeRepository(
        activeGroup: true,
        failDissolve: true,
      );
      final mergeService = AccountProjectMergeService(
        repository: mergeRepository,
        now: () => DateTime.utc(2026, 5, 15),
      );
      final accountStore = AccountStore(mergeService: mergeService);
      final timingStore = TimingStore(_FakeTimingRepository());
      final deviceStore = DeviceStore(_FakeDeviceRepository());
      final paymentRepository = _FakePaymentRepository();
      final paymentStore = AccountPaymentStore(paymentRepository);
      final rateStore = ProjectRateStore(_FakeRateRepository());

      await Future.wait([
        timingStore.loadAll(),
        deviceStore.loadAll(),
        paymentStore.loadAll(),
        rateStore.loadAll(),
        accountStore.loadAll(),
      ]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AccountProjectMergeService>.value(value: mergeService),
            Provider<AccountPaymentRepository>.value(value: paymentRepository),
            _accountActionControllerProvider(paymentRepository, mergeService),
            ChangeNotifierProvider<TimingStore>.value(value: timingStore),
            ChangeNotifierProvider<DeviceStore>.value(value: deviceStore),
            ChangeNotifierProvider<AccountPaymentStore>.value(
              value: paymentStore,
            ),
            ChangeNotifierProvider<ProjectRateStore>.value(value: rateStore),
            ChangeNotifierProvider<AccountStore>.value(value: accountStore),
            ChangeNotifierProvider<AccountFilterStore>(
              create: (_) => AccountFilterStore(),
            ),
          ],
          child: const MaterialApp(home: AccountPage()),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('李杰•合并2项目'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('解除合并'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('解除合并').last);
      await tester.pumpAndSettle();

      expect(mergeRepository.dissolveGroupCalls, 1);
      expect(find.textContaining('解除合并失败：'), findsOneWidget);
      expect(find.text('解除合并？'), findsOneWidget);
      expect(find.text('李杰 + 合并2项目'), findsWidgets);
    },
  );

  testWidgets(
    'AccountPage creates merged payment allocations and refreshes detail',
    (tester) async {
      final mergeRepository = _FakeMergeRepository(activeGroup: true);
      final mergeService = AccountProjectMergeService(
        repository: mergeRepository,
        now: () => DateTime.utc(2026, 5, 15),
      );
      final accountStore = AccountStore(mergeService: mergeService);
      final timingStore = TimingStore(_FakeTimingRepository());
      final deviceStore = DeviceStore(_FakeDeviceRepository());
      final paymentRepository = _FakePaymentRepository();
      final paymentStore = AccountPaymentStore(paymentRepository);
      final rateStore = ProjectRateStore(_FakeRateRepository());

      await Future.wait([
        timingStore.loadAll(),
        deviceStore.loadAll(),
        paymentStore.loadAll(),
        rateStore.loadAll(),
        accountStore.loadAll(),
      ]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AccountProjectMergeService>.value(value: mergeService),
            Provider<AccountPaymentRepository>.value(value: paymentRepository),
            _accountActionControllerProvider(paymentRepository, mergeService),
            ChangeNotifierProvider<TimingStore>.value(value: timingStore),
            ChangeNotifierProvider<DeviceStore>.value(value: deviceStore),
            ChangeNotifierProvider<AccountPaymentStore>.value(
              value: paymentStore,
            ),
            ChangeNotifierProvider<ProjectRateStore>.value(value: rateStore),
            ChangeNotifierProvider<AccountStore>.value(value: accountStore),
            ChangeNotifierProvider<AccountFilterStore>(
              create: (_) => AccountFilterStore(),
            ),
          ],
          child: const MaterialApp(home: AccountPage()),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('李杰•合并2项目'));
      await tester.pumpAndSettle();
      final addPaymentButton = find.widgetWithText(InkWell, '+ 新增收款');
      await tester.ensureVisible(addPaymentButton);
      await tester.pumpAndSettle();
      await tester.tap(addPaymentButton);
      await tester.pumpAndSettle();
      await tester.enterText(_textFieldByLabel('金额（整数）'), '1500');
      await tester.enterText(_textFieldByLabel('备注（可填）'), '微信收款');
      await tester.tap(find.widgetWithText(FilledButton, '确定').last);
      await tester.pumpAndSettle();

      expect(paymentRepository.insertAllCalls, 1);
      expect(paymentRepository.records.map((row) => row.projectKey).toList(), [
        '李杰||新村',
        '李杰||高桥',
      ]);
      expect(paymentRepository.records.map((row) => row.amount).toList(), [
        1000,
        500,
      ]);
      expect(
        paymentRepository.records.every(
          (row) =>
              row.sourceType == AccountPayment.sourceTypeMergeAllocation &&
              row.mergeGroupId == 1 &&
              row.mergeBatchId != null &&
              row.mergeBatchTotalAmount == 1500 &&
              row.mergeBatchNote == '微信收款',
        ),
        isTrue,
      );
      expect(find.text('保存成功'), findsOneWidget);
      expect(find.textContaining('合并分摊'), findsOneWidget);
      expect(find.textContaining('已收 75.0%'), findsWidgets);
    },
  );

  testWidgets(
    'AccountPage hides project detail footer while keeping inline actions reachable',
    (tester) async {
      final mergeRepository = _FakeMergeRepository();
      final mergeService = AccountProjectMergeService(
        repository: mergeRepository,
        now: () => DateTime.utc(2026, 5, 15),
      );
      final accountStore = AccountStore(mergeService: mergeService);
      final timingStore = TimingStore(_FakeTimingRepository());
      final deviceStore = DeviceStore(_FakeDeviceRepository());
      final paymentRepository = _FakePaymentRepository(
        seed: [
          for (var index = 0; index < 24; index += 1)
            AccountPayment(
              id: index + 1,
              projectKey: '李杰||新村',
              ymd: 20260501 + index,
              amount: 10,
              note: '第$index笔',
            ),
        ],
      );
      final paymentStore = AccountPaymentStore(paymentRepository);
      final rateStore = ProjectRateStore(_FakeRateRepository());

      await Future.wait([
        timingStore.loadAll(),
        deviceStore.loadAll(),
        paymentStore.loadAll(),
        rateStore.loadAll(),
        accountStore.loadAll(),
      ]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AccountProjectMergeService>.value(value: mergeService),
            Provider<AccountPaymentRepository>.value(value: paymentRepository),
            _accountActionControllerProvider(paymentRepository, mergeService),
            ChangeNotifierProvider<TimingStore>.value(value: timingStore),
            ChangeNotifierProvider<DeviceStore>.value(value: deviceStore),
            ChangeNotifierProvider<AccountPaymentStore>.value(
              value: paymentStore,
            ),
            ChangeNotifierProvider<ProjectRateStore>.value(value: rateStore),
            ChangeNotifierProvider<AccountStore>.value(value: accountStore),
            ChangeNotifierProvider<AccountFilterStore>(
              create: (_) => AccountFilterStore(),
            ),
          ],
          child: const MaterialApp(home: AccountPage()),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('李杰•新村'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('项目详情'), findsOneWidget);
      expect(
        find.byKey(const Key('project-detail-share-button')),
        findsOneWidget,
      );
      final titleRect = tester.getRect(find.text('项目详情'));
      final shareRect = tester.getRect(
        find.byKey(const Key('project-detail-share-button')),
      );
      final closeRect = tester.getRect(find.byIcon(Icons.close).last);
      expect(shareRect.left, greaterThan(titleRect.right));
      expect(shareRect.right, lessThan(closeRect.left));
      expect(find.text('+ 新增收款'), findsOneWidget);
      expect(find.widgetWithText(TextButton, '+ 新增收款'), findsNothing);
      expect(find.widgetWithText(FilledButton, '确定'), findsNothing);
      expect(find.widgetWithText(TextButton, '取消'), findsNothing);

      final addPaymentButton = find.widgetWithText(InkWell, '+ 新增收款');
      await tester.ensureVisible(addPaymentButton);
      await tester.pumpAndSettle();
      await tester.tap(addPaymentButton);
      await tester.pumpAndSettle();

      expect(_textFieldByLabel('金额（整数）'), findsOneWidget);
      await tester.tap(find.text('取消').last);
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(SingleChildScrollView).last,
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();

      expect(find.text('项目详情'), findsNothing);
    },
  );

  testWidgets('AccountPage edits a merged payment batch by replacing rows', (
    tester,
  ) async {
    final mergeRepository = _FakeMergeRepository(activeGroup: true);
    final mergeService = AccountProjectMergeService(
      repository: mergeRepository,
      now: () => DateTime.utc(2026, 5, 15),
    );
    final accountStore = AccountStore(mergeService: mergeService);
    final timingStore = TimingStore(_FakeTimingRepository());
    final deviceStore = DeviceStore(_FakeDeviceRepository());
    final paymentRepository = _FakePaymentRepository(
      seed: [
        _mergeAllocation(id: 1, projectKey: '李杰||新村', amount: 1000),
        _mergeAllocation(id: 2, projectKey: '李杰||高桥', amount: 500),
      ],
    );
    final paymentStore = AccountPaymentStore(paymentRepository);
    final rateStore = ProjectRateStore(_FakeRateRepository());

    await Future.wait([
      timingStore.loadAll(),
      deviceStore.loadAll(),
      paymentStore.loadAll(),
      rateStore.loadAll(),
      accountStore.loadAll(),
    ]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AccountProjectMergeService>.value(value: mergeService),
          Provider<AccountPaymentRepository>.value(value: paymentRepository),
          _accountActionControllerProvider(paymentRepository, mergeService),
          ChangeNotifierProvider<TimingStore>.value(value: timingStore),
          ChangeNotifierProvider<DeviceStore>.value(value: deviceStore),
          ChangeNotifierProvider<AccountPaymentStore>.value(
            value: paymentStore,
          ),
          ChangeNotifierProvider<ProjectRateStore>.value(value: rateStore),
          ChangeNotifierProvider<AccountStore>.value(value: accountStore),
          ChangeNotifierProvider<AccountFilterStore>(
            create: (_) => AccountFilterStore(),
          ),
        ],
        child: const MaterialApp(home: AccountPage()),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('李杰•合并2项目'));
    await tester.pumpAndSettle();
    final editButton = find.byIcon(Icons.edit_outlined);
    await tester.ensureVisible(editButton);
    await tester.pumpAndSettle();
    await tester.tap(editButton);
    await tester.pumpAndSettle();

    expect(find.text('编辑收款'), findsOneWidget);
    expect(find.text('2026.05.15'), findsWidgets);
    expect(
      tester.widget<TextField>(_textFieldByLabel('金额（整数）')).controller?.text,
      '1500',
    );
    expect(
      tester.widget<TextField>(_textFieldByLabel('备注（可填）')).controller?.text,
      '微信收款',
    );

    await tester.enterText(_textFieldByLabel('金额（整数）'), '1200');
    await tester.enterText(_textFieldByLabel('备注（可填）'), '改收款');
    await tester.tap(find.widgetWithText(FilledButton, '确定').last);
    await tester.pumpAndSettle();

    expect(paymentRepository.replaceBatchCalls, 1);
    final batchRows = await paymentRepository.listByMergeBatchId('batch-1');
    expect(batchRows.map((row) => row.projectKey).toList(), [
      '李杰||新村',
      '李杰||高桥',
    ]);
    expect(batchRows.map((row) => row.amount).toList(), [1000, 200]);
    expect(batchRows.map((row) => row.mergeBatchId).toSet(), {'batch-1'});
    expect(batchRows.map((row) => row.createdAt).toSet(), {
      '2026-05-16T01:03:00.000Z',
    });
    expect(find.text('已保存'), findsOneWidget);
    expect(find.text('2026.05.15'), findsOneWidget);
    expect(find.text('¥1200'), findsWidgets);
    expect(find.text('合并分摊'), findsOneWidget);
    expect(find.text('备注：改收款'), findsOneWidget);
  });

  testWidgets('AccountPage deletes a merged payment batch only', (
    tester,
  ) async {
    final mergeRepository = _FakeMergeRepository(activeGroup: true);
    final mergeService = AccountProjectMergeService(
      repository: mergeRepository,
      now: () => DateTime.utc(2026, 5, 15),
    );
    final accountStore = AccountStore(mergeService: mergeService);
    final timingStore = TimingStore(_FakeTimingRepository());
    final deviceStore = DeviceStore(_FakeDeviceRepository());
    final paymentRepository = _FakePaymentRepository(
      seed: [
        _mergeAllocation(id: 1, projectKey: '李杰||新村', amount: 1000),
        _mergeAllocation(id: 2, projectKey: '李杰||高桥', amount: 500),
        const AccountPayment(
          id: 3,
          projectKey: '李杰||新村',
          ymd: 20260515,
          amount: 88,
          sourceType: AccountPayment.sourceTypeManual,
          mergeBatchId: 'batch-1',
        ),
      ],
    );
    final paymentStore = AccountPaymentStore(paymentRepository);
    final rateStore = ProjectRateStore(_FakeRateRepository());

    await Future.wait([
      timingStore.loadAll(),
      deviceStore.loadAll(),
      paymentStore.loadAll(),
      rateStore.loadAll(),
      accountStore.loadAll(),
    ]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AccountProjectMergeService>.value(value: mergeService),
          Provider<AccountPaymentRepository>.value(value: paymentRepository),
          _accountActionControllerProvider(paymentRepository, mergeService),
          ChangeNotifierProvider<TimingStore>.value(value: timingStore),
          ChangeNotifierProvider<DeviceStore>.value(value: deviceStore),
          ChangeNotifierProvider<AccountPaymentStore>.value(
            value: paymentStore,
          ),
          ChangeNotifierProvider<ProjectRateStore>.value(value: rateStore),
          ChangeNotifierProvider<AccountStore>.value(value: accountStore),
          ChangeNotifierProvider<AccountFilterStore>(
            create: (_) => AccountFilterStore(),
          ),
        ],
        child: const MaterialApp(home: AccountPage()),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('李杰•合并2项目'));
    await tester.pumpAndSettle();
    final deleteButton = find.byIcon(Icons.delete_outline);
    await tester.ensureVisible(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();

    expect(paymentRepository.deleteBatchCalls, 1);
    expect(await paymentRepository.listByMergeBatchId('batch-1'), isEmpty);
    expect(paymentRepository.records, hasLength(1));
    expect(
      paymentRepository.records.single.sourceType,
      AccountPayment.sourceTypeManual,
    );
    expect(paymentRepository.records.single.amount, 88);
    expect(find.text('已删除'), findsOneWidget);
    expect(find.textContaining('合并分摊'), findsNothing);
  });
}

Finder _textFieldByLabel(String label) {
  return find.byWidgetPredicate((widget) {
    return widget is TextField && widget.decoration?.labelText == label;
  });
}

Provider<AccountActionController> _accountActionControllerProvider(
  AccountPaymentRepository paymentRepository,
  AccountProjectMergeService mergeService,
) {
  return Provider<AccountActionController>.value(
    value: AccountActionController(
      paymentRepository: paymentRepository,
      mergeService: mergeService,
      settlementUseCase: ProjectSettlementUseCase(
        repository: _FakeProjectSettlementRepository(),
      ),
    ),
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
      TimingRecord(
        id: 2,
        deviceId: 1,
        startDate: 20260502,
        contact: '李杰',
        site: '高桥',
        type: TimingType.hours,
        startMeter: 10,
        endMeter: 20,
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
    return const [
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
  _FakePaymentRepository({List<AccountPayment> seed = const []}) {
    for (final payment in seed) {
      records.add(payment);
      final id = payment.id;
      if (id != null && id >= _nextId) _nextId = id + 1;
    }
  }

  final records = <AccountPayment>[];
  int insertAllCalls = 0;
  int replaceBatchCalls = 0;
  int deleteBatchCalls = 0;
  int _nextId = 1;

  @override
  Future<List<AccountPayment>> listAll() async => List.of(records);

  @override
  Future<int> insert(AccountPayment payment) async {
    final id = payment.id ?? _nextId++;
    records.add(payment.copyWith(id: id));
    return id;
  }

  @override
  Future<void> insertAllInTransaction(List<AccountPayment> payments) async {
    insertAllCalls++;
    for (final payment in payments) {
      await insert(payment);
    }
  }

  @override
  Future<List<AccountPayment>> listByMergeBatchId(String batchId) async {
    final rows = records.where((row) {
      return row.sourceType == AccountPayment.sourceTypeMergeAllocation &&
          row.mergeBatchId == batchId;
    }).toList()..sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));
    return rows;
  }

  @override
  Future<int> deleteByMergeBatchId(String batchId) async {
    deleteBatchCalls++;
    final before = records.length;
    records.removeWhere((row) {
      return row.sourceType == AccountPayment.sourceTypeMergeAllocation &&
          row.mergeBatchId == batchId;
    });
    return before - records.length;
  }

  @override
  Future<void> replaceMergeBatchInTransaction({
    required String batchId,
    required List<AccountPayment> newRows,
  }) async {
    replaceBatchCalls++;
    records.removeWhere((row) {
      return row.sourceType == AccountPayment.sourceTypeMergeAllocation &&
          row.mergeBatchId == batchId;
    });
    for (final payment in newRows) {
      await insert(payment);
    }
  }

  @override
  Future<int> update(AccountPayment payment) async => 1;

  @override
  Future<int> deleteById(int id) async => 1;
}

class _FakeProjectSettlementRepository implements ProjectSettlementRepository {
  @override
  Future<ProjectSettlementResult> settle(ProjectSettlementRequest request) {
    final receivedAfter = request.paymentAmount;
    final writeOffAfter = request.writeOffAmount;
    return Future.value(
      ProjectSettlementResult(
        projectId: request.projectId,
        receivable: request.receivable,
        receivedBefore: 0,
        writeOffBefore: 0,
        remainingBefore: request.receivable,
        paymentAmount: request.paymentAmount,
        writeOffAmount: request.writeOffAmount,
        receivedAfter: receivedAfter,
        writeOffAfter: writeOffAfter,
        remainingAfter: request.receivable - receivedAfter - writeOffAfter,
        settled:
            request.receivable - receivedAfter - writeOffAfter <=
            projectSettlementEpsilon,
      ),
    );
  }

  @override
  Future<DeleteProjectWriteOffResult> deleteWriteOff(
    DeleteProjectWriteOffRequest request,
  ) {
    return Future.value(
      DeleteProjectWriteOffResult(
        projectId: request.projectId,
        writeOffId: request.writeOffId,
        deletedAmount: 0,
        receivable: request.receivable,
        received: 0,
        writeOffBefore: 0,
        writeOffAfter: 0,
        remainingAfter: request.receivable,
        restoredActive: request.receivable > projectSettlementEpsilon,
      ),
    );
  }

  @override
  Future<RevokeProjectSettlementStatusResult> revokeSettlementStatus(
    RevokeProjectSettlementStatusRequest request,
  ) {
    return Future.value(
      RevokeProjectSettlementStatusResult(
        projectId: request.projectId,
        restoredActive: true,
      ),
    );
  }
}

AccountPayment _mergeAllocation({
  required int id,
  required String projectKey,
  required double amount,
}) {
  return AccountPayment(
    id: id,
    projectKey: projectKey,
    ymd: 20260515,
    amount: amount,
    note: '微信收款 / 合并分摊(从2026.05.15收款¥1500)',
    sourceType: AccountPayment.sourceTypeMergeAllocation,
    mergeGroupId: 1,
    mergeBatchId: 'batch-1',
    mergeBatchTotalAmount: 1500,
    mergeBatchNote: '微信收款',
    createdAt: '2026-05-16T01:03:00.000Z',
  );
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

class _FakeMergeRepository implements AccountProjectMergeRepository {
  _FakeMergeRepository({bool activeGroup = false, this.failDissolve = false}) {
    if (activeGroup) {
      _created = _activeGroupWithMembers();
    }
  }

  int listActiveGroupsWithMembersCalls = 0;
  int dissolveGroupCalls = 0;
  int? dissolvedGroupId;
  final bool failDissolve;
  String? createdContact;
  List<String> createdProjectKeys = const [];
  AccountProjectMergeGroupWithMembers? _created;

  @override
  Future<List<AccountProjectMergeGroupWithMembers>>
  listActiveGroupsWithMembers() async {
    listActiveGroupsWithMembersCalls++;
    final created = _created;
    if (created == null) return const [];
    if (!created.group.isActive) return const [];
    return [created];
  }

  @override
  Future<AccountProjectMergeGroupWithMembers> createGroupWithMembers({
    required AccountProjectMergeGroup group,
    required List<AccountProjectMergeMember> members,
  }) async {
    createdContact = group.contact;
    createdProjectKeys = members.map((member) => member.projectKey).toList();
    _created = AccountProjectMergeGroupWithMembers(
      group: group.copyWith(id: 1),
      members: [
        for (var index = 0; index < members.length; index += 1)
          members[index].copyWith(id: index + 1, groupId: 1),
      ],
    );
    return _created!;
  }

  @override
  Future<List<AccountProjectMergeMember>> listActiveMembersByProjectKeys(
    List<String> projectKeys,
  ) async => const [];

  @override
  Future<List<AccountProjectMergeMember>> listActiveMembersByProjectIds(
    List<String> projectIds,
  ) async {
    final projectIdSet = projectIds.map((id) => id.trim()).toSet();
    final created = _created;
    if (created == null) return const [];
    return created.members.where((member) {
      return member.isActive &&
          projectIdSet.contains(member.effectiveProjectId);
    }).toList();
  }

  @override
  Future<void> dissolveGroup({
    required int groupId,
    required String dissolvedAt,
  }) async {
    dissolveGroupCalls++;
    dissolvedGroupId = groupId;
    if (failDissolve) {
      throw StateError('测试解除失败');
    }

    final created = _created;
    if (created == null || created.group.id != groupId) return;
    _created = AccountProjectMergeGroupWithMembers(
      group: created.group.copyWith(
        isActive: false,
        dissolvedAt: dissolvedAt,
        updatedAt: dissolvedAt,
      ),
      members: [
        for (final member in created.members) member.copyWith(isActive: false),
      ],
    );
  }

  @override
  Future<AccountProjectMergeGroup?> getGroupById(int groupId) async {
    final created = _created;
    if (created == null || created.group.id != groupId) return null;
    return created.group;
  }

  @override
  Future<List<AccountProjectMergeGroup>> listActiveGroups() {
    final created = _created;
    if (created == null || !created.group.isActive) return Future.value([]);
    return Future.value([created.group]);
  }

  @override
  Future<List<AccountProjectMergeMember>> listActiveMembers() {
    final created = _created;
    if (created == null) return Future.value([]);
    return Future.value(
      created.members.where((member) => member.isActive).toList(),
    );
  }

  @override
  Future<List<AccountProjectMergeMember>> listMembersByGroupId(int groupId) {
    final created = _created;
    if (created == null || created.group.id != groupId) {
      return Future.value([]);
    }
    return Future.value(created.members);
  }

  AccountProjectMergeGroupWithMembers _activeGroupWithMembers() {
    const createdAt = '2026-05-15T00:00:00.000Z';
    return AccountProjectMergeGroupWithMembers(
      group: const AccountProjectMergeGroup(
        id: 1,
        contact: '李杰',
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
      members: const [
        AccountProjectMergeMember(
          id: 1,
          groupId: 1,
          projectKey: '李杰||新村',
          contact: '李杰',
          site: '新村',
          sortOrder: 0,
          createdAt: createdAt,
        ),
        AccountProjectMergeMember(
          id: 2,
          groupId: 1,
          projectKey: '李杰||高桥',
          contact: '李杰',
          site: '高桥',
          sortOrder: 1,
          createdAt: createdAt,
        ),
      ],
    );
  }
}
