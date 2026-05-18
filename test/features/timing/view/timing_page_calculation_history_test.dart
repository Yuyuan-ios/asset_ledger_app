import 'package:asset_ledger/app/adapters/account_merge_dissolve_adapter.dart';
import 'package:asset_ledger/data/models/account_project_merge_group.dart';
import 'package:asset_ledger/data/models/account_project_merge_group_with_members.dart';
import 'package:asset_ledger/data/models/account_project_merge_member.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/fuel_log.dart';
import 'package:asset_ledger/data/models/maintenance_record.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/repositories/account_project_merge_repository.dart';
import 'package:asset_ledger/data/repositories/device_repository.dart';
import 'package:asset_ledger/data/repositories/fuel_repository.dart';
import 'package:asset_ledger/data/repositories/maintenance_repository.dart';
import 'package:asset_ledger/data/repositories/project_repository.dart';
import 'package:asset_ledger/data/repositories/project_rate_repository.dart';
import 'package:asset_ledger/data/repositories/timing_repository.dart';
import 'package:asset_ledger/data/services/account_project_merge_service.dart';
import 'package:asset_ledger/data/services/project_resolver.dart';
import 'package:asset_ledger/features/account/state/project_rate_store.dart';
import 'package:asset_ledger/features/device/state/device_store.dart';
import 'package:asset_ledger/features/fuel/state/fuel_store.dart';
import 'package:asset_ledger/features/maintenance/state/maintenance_store.dart';
import 'package:asset_ledger/data/models/timing_calculation_history.dart';
import 'package:asset_ledger/data/repositories/timing_calculation_history_repository.dart';
import 'package:asset_ledger/features/timing/state/timing_store.dart';
import 'package:asset_ledger/features/timing/use_cases/timing_merge_dissolve_port.dart';
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

    expect(find.textContaining('[已保存]'), findsNothing);
    expect(
      find.textContaining('8 + 8 = 16.0 h', findRichText: true),
      findsOneWidget,
    );
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

  testWidgets(
    'keeps merge group after editing project address on same projectId',
    (WidgetTester tester) async {
      final timingRepository = _FakeTimingRepository(seed: [_record()]);
      final mergeRepository = _FakeAccountProjectMergeRepository(
        group: _mergeGroup(),
        members: _mergeMembers(),
      );

      await _pumpTimingPage(
        tester,
        timingRepository: timingRepository,
        historyRepository: _FakeCalculationHistoryRepository(),
        mergeRepository: mergeRepository,
      );

      await tester.tap(find.text('甲方·一号工地'));
      await tester.pumpAndSettle();

      await tester.enterText(_textFieldWithLabel('使用地址/工地'), '一号工地新址');
      await tester.tap(find.widgetWithText(FilledButton, '确定'));
      await tester.pumpAndSettle();

      expect(timingRepository.saveCalls, 1);
      expect(timingRepository.savedRecords.single.site, '一号工地新址');
      expect(mergeRepository.dissolvedGroupIds, isEmpty);
      expect(mergeRepository.group?.isActive, isTrue);
      expect(
        mergeRepository.members.every((member) => member.isActive),
        isTrue,
      );
    },
  );

  testWidgets(
    'does not show dissolve retry when only project attributes change',
    (WidgetTester tester) async {
      final timingRepository = _FakeTimingRepository(seed: [_record()]);
      final mergeRepository = _FakeAccountProjectMergeRepository(
        group: _mergeGroup(),
        members: _mergeMembers(),
        failDissolveCount: 1,
      );

      await _pumpTimingPage(
        tester,
        timingRepository: timingRepository,
        historyRepository: _FakeCalculationHistoryRepository(),
        mergeRepository: mergeRepository,
      );

      await tester.tap(find.text('甲方·一号工地'));
      await tester.pumpAndSettle();

      await tester.enterText(_textFieldWithLabel('使用地址/工地'), '一号工地新址');
      await tester.tap(find.widgetWithText(FilledButton, '确定'));
      await tester.pumpAndSettle();

      expect(timingRepository.saveCalls, 1);
      expect(mergeRepository.dissolvedGroupIds, isEmpty);
      expect(mergeRepository.group?.isActive, isTrue);
      expect(find.text('合并项目未解除'), findsNothing);
      expect(find.text('编辑计时'), findsNothing);
    },
  );

  testWidgets(
    'keeps merge group when editing hours without project key change',
    (WidgetTester tester) async {
      final timingRepository = _FakeTimingRepository(seed: [_record()]);
      final mergeRepository = _FakeAccountProjectMergeRepository(
        group: _mergeGroup(),
        members: _mergeMembers(),
      );

      await _pumpTimingPage(
        tester,
        timingRepository: timingRepository,
        historyRepository: _FakeCalculationHistoryRepository(),
        mergeRepository: mergeRepository,
      );

      await tester.tap(find.text('甲方·一号工地'));
      await tester.pumpAndSettle();

      await tester.enterText(_textFieldWithLabel('工时（小时）'), '20.0');
      await tester.tap(find.widgetWithText(FilledButton, '确定'));
      await tester.pumpAndSettle();

      expect(timingRepository.saveCalls, 1);
      expect(timingRepository.savedRecords.single.contact, '甲方');
      expect(timingRepository.savedRecords.single.site, '一号工地');
      expect(mergeRepository.dissolvedGroupIds, isEmpty);
      expect(mergeRepository.group?.isActive, isTrue);
    },
  );
}

Future<void> _pumpTimingPage(
  WidgetTester tester, {
  _FakeTimingRepository? timingRepository,
  required TimingCalculationHistoryRepository historyRepository,
  _FakeAccountProjectMergeRepository? mergeRepository,
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
  final projectResolver = ProjectResolver(
    projectRepository: _FakeProjectRepository(),
    now: () => DateTime.utc(2026, 5, 15),
  );

  final deviceStore = DeviceStore(deviceRepository);
  final timingStore = TimingStore(resolvedTimingRepository);
  final fuelStore = FuelStore(fuelRepository);
  final maintenanceStore = MaintenanceStore(maintenanceRepository);
  final rateStore = ProjectRateStore(rateRepository);
  final resolvedMergeRepository =
      mergeRepository ?? _FakeAccountProjectMergeRepository();
  final mergeService = AccountProjectMergeService(
    repository: resolvedMergeRepository,
    now: () => DateTime.utc(2026, 5, 15, 1, 2, 3),
  );

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
          Provider<AccountProjectMergeService>.value(value: mergeService),
          Provider<TimingMergeDissolvePort>.value(
            value: AccountMergeDissolveAdapter(mergeService),
          ),
          Provider<ProjectResolver>.value(value: projectResolver),
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

Finder _textFieldWithLabel(String label) {
  return find.byWidgetPredicate((widget) {
    return widget is TextField && widget.decoration?.labelText == label;
  });
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
  final List<TimingRecord> savedRecords = [];
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
    savedRecords.add(record);
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
    String? projectId,
    bool isBreaking = false,
  }) async {
    return 1;
  }

  @override
  Future<int> deleteByProjectKey(String projectKey) async => 1;
}

class _FakeProjectRepository implements ProjectRepository {
  final inserted = <Project>[];

  @override
  Future<List<Project>> listAll() async => inserted;

  @override
  Future<Project?> findById(String id) async {
    for (final project in inserted) {
      if (project.id == id) return project;
    }
    return null;
  }

  @override
  Future<List<Project>> findActiveByContactSite({
    required String contact,
    required String site,
  }) async {
    return inserted
        .where((project) {
          return project.contact == contact.trim() &&
              project.site == site.trim() &&
              project.status == ProjectStatus.active;
        })
        .toList(growable: false);
  }

  @override
  Future<void> insert(Project project) async {
    inserted.add(project);
  }

  @override
  Future<Project> findOrCreateLegacyProject({
    required String contact,
    required String site,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> upsert(Project project) async {
    inserted.add(project);
  }
}

AccountProjectMergeGroup _mergeGroup() {
  return const AccountProjectMergeGroup(
    id: 1,
    contact: '甲方',
    createdAt: '2026-05-15T00:00:00.000Z',
  );
}

List<AccountProjectMergeMember> _mergeMembers() {
  return const [
    AccountProjectMergeMember(
      id: 1,
      groupId: 1,
      projectKey: '甲方||一号工地',
      contact: '甲方',
      site: '一号工地',
      sortOrder: 0,
      createdAt: '2026-05-15T00:00:00.000Z',
    ),
    AccountProjectMergeMember(
      id: 2,
      groupId: 1,
      projectKey: '甲方||二号工地',
      contact: '甲方',
      site: '二号工地',
      sortOrder: 1,
      createdAt: '2026-05-15T00:00:00.000Z',
    ),
  ];
}

class _FakeAccountProjectMergeRepository
    implements AccountProjectMergeRepository {
  _FakeAccountProjectMergeRepository({
    this.group,
    List<AccountProjectMergeMember> members = const [],
    this.failDissolveCount = 0,
  }) : members = List.of(members);

  AccountProjectMergeGroup? group;
  List<AccountProjectMergeMember> members;
  int failDissolveCount;
  final List<int> dissolvedGroupIds = [];

  @override
  Future<AccountProjectMergeGroupWithMembers> createGroupWithMembers({
    required AccountProjectMergeGroup group,
    required List<AccountProjectMergeMember> members,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> dissolveGroup({
    required int groupId,
    required String dissolvedAt,
  }) async {
    if (failDissolveCount > 0) {
      failDissolveCount -= 1;
      throw StateError('dissolve failed');
    }
    dissolvedGroupIds.add(groupId);
    group = group?.copyWith(isActive: false, dissolvedAt: dissolvedAt);
    members = [
      for (final member in members)
        if (member.groupId == groupId)
          member.copyWith(isActive: false)
        else
          member,
    ];
  }

  @override
  Future<AccountProjectMergeGroup?> getGroupById(int groupId) async {
    final current = group;
    if (current == null || current.id != groupId) return null;
    return current;
  }

  @override
  Future<List<AccountProjectMergeMember>> listActiveMembers() async {
    return members.where((member) => member.isActive).toList();
  }

  @override
  Future<List<AccountProjectMergeMember>> listActiveMembersByProjectKeys(
    List<String> projectKeys,
  ) async {
    final keySet = projectKeys.map((key) => key.trim()).toSet();
    return members.where((member) {
      return member.isActive && keySet.contains(member.projectKey);
    }).toList();
  }

  @override
  Future<List<AccountProjectMergeMember>> listActiveMembersByProjectIds(
    List<String> projectIds,
  ) async {
    final projectIdSet = projectIds.map((id) => id.trim()).toSet();
    return members.where((member) {
      return member.isActive &&
          projectIdSet.contains(member.effectiveProjectId);
    }).toList();
  }

  @override
  Future<List<AccountProjectMergeGroup>> listActiveGroups() async {
    final current = group;
    if (current == null || !current.isActive) return const [];
    return [current];
  }

  @override
  Future<List<AccountProjectMergeGroupWithMembers>>
  listActiveGroupsWithMembers() async {
    final current = group;
    if (current == null || !current.isActive) return const [];
    return [
      AccountProjectMergeGroupWithMembers(
        group: current,
        members: await listActiveMembers(),
      ),
    ];
  }

  @override
  Future<List<AccountProjectMergeMember>> listMembersByGroupId(
    int groupId,
  ) async {
    return members.where((member) => member.groupId == groupId).toList();
  }
}
