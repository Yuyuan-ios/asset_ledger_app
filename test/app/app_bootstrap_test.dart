import 'dart:async';

import 'package:asset_ledger/app/app_bootstrap.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/fuel_log.dart';
import 'package:asset_ledger/data/models/maintenance_record.dart';
import 'package:asset_ledger/data/models/account_project_merge_group.dart';
import 'package:asset_ledger/data/models/account_project_merge_group_with_members.dart';
import 'package:asset_ledger/data/models/account_project_merge_member.dart';
import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/repositories/account_project_merge_repository.dart';
import 'package:asset_ledger/data/repositories/device_repository.dart';
import 'package:asset_ledger/data/repositories/fuel_repository.dart';
import 'package:asset_ledger/data/repositories/maintenance_repository.dart';
import 'package:asset_ledger/data/repositories/project_rate_repository.dart';
import 'package:asset_ledger/data/repositories/timing_repository.dart';
import 'package:asset_ledger/data/services/account_project_merge_service.dart';
import 'package:asset_ledger/features/account/state/account_store.dart';
import 'package:asset_ledger/features/account/state/project_rate_store.dart';
import 'package:asset_ledger/data/models/timing_calculation_history.dart';
import 'package:asset_ledger/features/device/state/device_store.dart';
import 'package:asset_ledger/features/fuel/state/fuel_store.dart';
import 'package:asset_ledger/features/maintenance/state/maintenance_store.dart';
import 'package:asset_ledger/features/timing/state/timing_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'AppBootstrap.preload loads startup stores without BuildContext',
    () async {
      final deviceRepository = _FakeDeviceRepository();
      final timingRepository = _FakeTimingRepository();
      final fuelRepository = _FakeFuelRepository();
      final maintenanceRepository = _FakeMaintenanceRepository();
      final rateRepository = _FakeProjectRateRepository();
      final mergeRepository = _FakeMergeRepository();

      final deviceStore = DeviceStore(deviceRepository);
      final timingStore = TimingStore(timingRepository);
      final fuelStore = FuelStore(fuelRepository);
      final maintenanceStore = MaintenanceStore(maintenanceRepository);
      final projectRateStore = ProjectRateStore(rateRepository);
      final accountStore = AccountStore(
        mergeService: AccountProjectMergeService(repository: mergeRepository),
      );

      await AppBootstrap.preload(
        deviceStore: deviceStore,
        timingStore: timingStore,
        fuelStore: fuelStore,
        maintenanceStore: maintenanceStore,
        projectRateStore: projectRateStore,
        accountStore: accountStore,
      );

      expect(deviceRepository.listAllCalls, 1);
      expect(timingRepository.listAllCalls, 1);
      expect(fuelRepository.listAllCalls, 1);
      expect(maintenanceRepository.listAllCalls, 1);
      expect(rateRepository.listAllCalls, 1);
      expect(mergeRepository.listActiveGroupsWithMembersCalls, 1);
    },
  );

  test('AppBootstrap.preload starts startup loads in parallel', () async {
    final gate = Completer<void>();
    final deviceRepository = _BlockingDeviceRepository(gate.future);
    final timingRepository = _BlockingTimingRepository(gate.future);
    final fuelRepository = _BlockingFuelRepository(gate.future);
    final maintenanceRepository = _BlockingMaintenanceRepository(gate.future);
    final rateRepository = _BlockingProjectRateRepository(gate.future);
    final mergeRepository = _BlockingMergeRepository(gate.future);

    final preloadFuture = AppBootstrap.preload(
      deviceStore: DeviceStore(deviceRepository),
      timingStore: TimingStore(timingRepository),
      fuelStore: FuelStore(fuelRepository),
      maintenanceStore: MaintenanceStore(maintenanceRepository),
      projectRateStore: ProjectRateStore(rateRepository),
      accountStore: AccountStore(
        mergeService: AccountProjectMergeService(repository: mergeRepository),
      ),
    );

    await Future<void>.delayed(Duration.zero);

    expect(deviceRepository.listAllCalls, 1);
    expect(timingRepository.listAllCalls, 1);
    expect(fuelRepository.listAllCalls, 1);
    expect(maintenanceRepository.listAllCalls, 1);
    expect(rateRepository.listAllCalls, 1);
    expect(mergeRepository.listActiveGroupsWithMembersCalls, 1);

    gate.complete();
    await preloadFuture;
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
  Future<TimingRecord> saveWithCalculationHistories(
    TimingRecord record, {
    List<TimingCalculationHistory> calculationHistories = const [],
  }) async {
    if (record.id == null) return record.copyWith(id: 1);
    return record;
  }

  @override
  Future<int> deleteById(int id) async => 1;

  @override
  Future<int> deleteByIds(Iterable<int> ids) async => ids.length;

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

class _BlockingDeviceRepository extends _FakeDeviceRepository {
  _BlockingDeviceRepository(this._gate);

  final Future<void> _gate;

  @override
  Future<List<Device>> listAll() async {
    listAllCalls++;
    await _gate;
    return const [];
  }
}

class _BlockingTimingRepository extends _FakeTimingRepository {
  _BlockingTimingRepository(this._gate);

  final Future<void> _gate;

  @override
  Future<List<TimingRecord>> listAll() async {
    listAllCalls++;
    await _gate;
    return const [];
  }
}

class _BlockingFuelRepository extends _FakeFuelRepository {
  _BlockingFuelRepository(this._gate);

  final Future<void> _gate;

  @override
  Future<List<FuelLog>> listAll() async {
    listAllCalls++;
    await _gate;
    return const [];
  }
}

class _FakeMaintenanceRepository implements MaintenanceRepository {
  int listAllCalls = 0;

  @override
  Future<List<MaintenanceRecord>> listAll() async {
    listAllCalls++;
    return const [];
  }

  @override
  Future<int> insert(MaintenanceRecord record) async => 1;

  @override
  Future<void> update(MaintenanceRecord record) async {}

  @override
  Future<void> deleteById(int id) async {}
}

class _BlockingMaintenanceRepository extends _FakeMaintenanceRepository {
  _BlockingMaintenanceRepository(this._gate);

  final Future<void> _gate;

  @override
  Future<List<MaintenanceRecord>> listAll() async {
    listAllCalls++;
    await _gate;
    return const [];
  }
}

class _BlockingProjectRateRepository extends _FakeProjectRateRepository {
  _BlockingProjectRateRepository(this._gate);

  final Future<void> _gate;

  @override
  Future<List<ProjectDeviceRate>> listAll() async {
    listAllCalls++;
    await _gate;
    return const [];
  }
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
    String? projectId,
    bool isBreaking = false,
  }) async => 1;

  @override
  Future<int> deleteByProjectKey(String projectKey) async => 1;
}

class _FakeMergeRepository implements AccountProjectMergeRepository {
  int listActiveGroupsWithMembersCalls = 0;

  @override
  Future<List<AccountProjectMergeGroupWithMembers>>
  listActiveGroupsWithMembers() async {
    listActiveGroupsWithMembersCalls++;
    return const [];
  }

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
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AccountProjectMergeGroup?> getGroupById(int groupId) {
    throw UnimplementedError();
  }

  @override
  Future<List<AccountProjectMergeGroup>> listActiveGroups() {
    throw UnimplementedError();
  }

  @override
  Future<List<AccountProjectMergeMember>> listActiveMembers() {
    throw UnimplementedError();
  }

  @override
  Future<List<AccountProjectMergeMember>> listActiveMembersByProjectKeys(
    List<String> projectKeys,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<List<AccountProjectMergeMember>> listActiveMembersByProjectIds(
    List<String> projectIds,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<List<AccountProjectMergeMember>> listMembersByGroupId(int groupId) {
    throw UnimplementedError();
  }
}

class _BlockingMergeRepository extends _FakeMergeRepository {
  _BlockingMergeRepository(this._gate);

  final Future<void> _gate;

  @override
  Future<List<AccountProjectMergeGroupWithMembers>>
  listActiveGroupsWithMembers() async {
    listActiveGroupsWithMembersCalls++;
    await _gate;
    return const [];
  }
}
