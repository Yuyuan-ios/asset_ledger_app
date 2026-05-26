import 'package:asset_ledger/app/adapters/account_merge_dissolve_adapter.dart';
import 'package:asset_ledger/data/models/account_project_merge_group.dart';
import 'package:asset_ledger/data/models/account_project_merge_group_with_members.dart';
import 'package:asset_ledger/data/models/account_project_merge_member.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/repositories/account_project_merge_repository.dart';
import 'package:asset_ledger/data/repositories/project_repository.dart';
import 'package:asset_ledger/data/repositories/timing_repository.dart';
import 'package:asset_ledger/data/services/account_service.dart';
import 'package:asset_ledger/data/services/account_project_merge_service.dart';
import 'package:asset_ledger/data/services/project_resolver.dart';
import 'package:asset_ledger/data/models/timing_calculation_history.dart';
import 'package:asset_ledger/features/timing/state/timing_store.dart';
import 'package:asset_ledger/features/timing/use_cases/save_timing_record_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SaveTimingRecordUseCase', () {
    test(
      'creates timing record with project_id and does not dissolve',
      () async {
        final timingRepository = _FakeTimingRepository();
        final mergeRepository = _FakeMergeRepository();
        final harness = _useCase(timingRepository, mergeRepository);

        final result = await harness.useCase.execute(
          editing: null,
          record: _record(id: null, projectId: ''),
        );

        expect(result.needsMergeDissolveRetry, isFalse);
        expect(mergeRepository.dissolveCalls, 0);
        expect(timingRepository.saved.single.projectId, startsWith('project:'));
        expect(harness.projectRepository.findActiveCalls, 1);
        expect(harness.projectRepository.inserted, hasLength(1));
      },
    );

    test('editing non-identity fields keeps the existing projectId', () async {
      final timingRepository = _FakeTimingRepository();
      final mergeRepository = _FakeMergeRepository(
        activeProjectId: 'project:a',
      );
      final harness = _useCase(timingRepository, mergeRepository);

      final result = await harness.execute(
        editing: _record(projectId: 'project:a', hours: 8),
        record: _record(projectId: 'project:a', hours: 9.5),
      );

      expect(result.needsMergeDissolveRetry, isFalse);
      expect(mergeRepository.dissolveCalls, 0);
      expect(timingRepository.saved.single.projectId, 'project:a');
      expect(harness.projectRepository.findActiveCalls, 0);
    });

    test(
      'editing contact reassigns only the saved record to the new project',
      () async {
        final timingRepository = _FakeTimingRepository();
        final mergeRepository = _FakeMergeRepository(
          activeProjectId: 'project:liyang-tianmeile',
        );
        final harness = _useCase(timingRepository, mergeRepository);

        final result = await harness.execute(
          editing: _record(
            id: 1,
            projectId: 'project:liyang-tianmeile',
            contact: '李洋',
            site: '天眉乐',
            deviceId: 1,
            hours: 9.6,
          ),
          record: _record(
            id: 1,
            projectId: 'project:liyang-tianmeile',
            contact: '张俊',
            site: '天眉乐',
            deviceId: 2,
            hours: 8,
          ),
        );

        final saved = timingRepository.saved.single;
        expect(saved.projectId, isNot('project:liyang-tianmeile'));
        expect(saved.contact, '张俊');
        expect(saved.site, '天眉乐');
        expect(harness.projectRepository.findActiveCalls, 1);
        expect(harness.projectRepository.inserted.single.contact, '张俊');
        expect(result.mergeDissolved, isTrue);
        expect(mergeRepository.dissolveCalls, 1);

        final unchangedOtherRecord = _record(
          id: 2,
          projectId: 'project:liyang-tianmeile',
          contact: '李洋',
          site: '天眉乐',
          deviceId: 1,
          hours: 9.6,
        );
        final projects = AccountService.buildProjects(
          timingRecords: [saved, unchangedOtherRecord],
        );

        expect(projects, hasLength(2));
        final movedProject = projects[saved.projectId]!;
        expect(movedProject.contact, '张俊');
        expect(movedProject.site, '天眉乐');
        expect(movedProject.hoursByDevice, {2: 8});

        final originalProject = projects['project:liyang-tianmeile']!;
        expect(originalProject.contact, '李洋');
        expect(originalProject.site, '天眉乐');
        expect(originalProject.hoursByDevice, {1: 9.6});
      },
    );

    test(
      'editing site reassigns the saved record to the new project',
      () async {
        final timingRepository = _FakeTimingRepository();
        final mergeRepository = _FakeMergeRepository();
        final harness = _useCase(timingRepository, mergeRepository);

        await harness.execute(
          editing: _record(
            projectId: 'project:old-site',
            contact: '李洋',
            site: '天眉乐',
          ),
          record: _record(
            projectId: 'project:old-site',
            contact: '李洋',
            site: '五里山',
          ),
        );

        final saved = timingRepository.saved.single;
        expect(saved.projectId, isNot('project:old-site'));
        expect(saved.contact, '李洋');
        expect(saved.site, '五里山');
        expect(harness.projectRepository.inserted.single.site, '五里山');
      },
    );

    test(
      'editing identity uses an existing active project when one matches',
      () async {
        final timingRepository = _FakeTimingRepository();
        final mergeRepository = _FakeMergeRepository();
        final harness = _useCase(timingRepository, mergeRepository);
        harness.projectRepository.inserted.add(
          _project(
            id: 'project:zhangjun-tianmeile',
            contact: '张俊',
            site: '天眉乐',
          ),
        );

        await harness.execute(
          editing: _record(
            projectId: 'project:liyang-tianmeile',
            contact: '李洋',
            site: '天眉乐',
          ),
          record: _record(
            projectId: 'project:liyang-tianmeile',
            contact: '张俊',
            site: '天眉乐',
          ),
        );

        expect(
          timingRepository.saved.single.projectId,
          'project:zhangjun-tianmeile',
        );
        expect(harness.projectRepository.inserted, hasLength(1));
      },
    );

    test('moving to another projectId dissolves the old merge group', () async {
      final timingRepository = _FakeTimingRepository();
      final mergeRepository = _FakeMergeRepository(
        activeProjectId: 'project:a',
      );
      final useCase = _useCase(timingRepository, mergeRepository);

      final result = await useCase.execute(
        editing: _record(projectId: 'project:a'),
        record: _record(projectId: 'project:b'),
      );

      expect(result.mergeDissolved, isTrue);
      expect(result.needsMergeDissolveRetry, isFalse);
      expect(mergeRepository.dissolveCalls, 1);
      expect(mergeRepository.dissolvedGroupIds, [7]);
    });

    test('dissolve failure returns retryable pending result', () async {
      final timingRepository = _FakeTimingRepository();
      final mergeRepository = _FakeMergeRepository(
        activeProjectId: 'project:a',
        failDissolve: true,
      );
      final useCase = _useCase(timingRepository, mergeRepository);

      final result = await useCase.execute(
        editing: _record(projectId: 'project:a'),
        record: _record(projectId: 'project:b'),
      );

      expect(timingRepository.saved, hasLength(1));
      expect(result.needsMergeDissolveRetry, isTrue);
      expect(result.pendingMergeDissolve!.oldProjectId, 'project:a');
      expect(result.pendingMergeDissolve!.newProjectId, 'project:b');
    });
  });
}

_SaveTimingUseCaseHarness _useCase(
  _FakeTimingRepository timingRepository,
  _FakeMergeRepository mergeRepository,
) {
  final projectRepository = _FakeProjectRepository();
  return _SaveTimingUseCaseHarness(
    useCase: SaveTimingRecordUseCase(
      timingStore: TimingStore(timingRepository),
      mergeDissolve: AccountMergeDissolveAdapter(
        AccountProjectMergeService(repository: mergeRepository),
      ),
      projectResolver: ProjectResolver(
        projectRepository: projectRepository,
        now: () => DateTime.utc(2026, 5, 17),
      ),
    ),
    projectRepository: projectRepository,
  );
}

class _SaveTimingUseCaseHarness {
  const _SaveTimingUseCaseHarness({
    required this.useCase,
    required this.projectRepository,
  });

  final SaveTimingRecordUseCase useCase;
  final _FakeProjectRepository projectRepository;

  Future<SaveTimingRecordResult> execute({
    required TimingRecord? editing,
    required TimingRecord record,
    List<TimingCalculationHistory> calculationHistories = const [],
  }) {
    return useCase.execute(
      editing: editing,
      record: record,
      calculationHistories: calculationHistories,
    );
  }
}

TimingRecord _record({
  int? id = 1,
  String projectId = 'project:a',
  int deviceId = 1,
  String contact = '甲方',
  String site = '一号工地',
  double hours = 8,
}) {
  return TimingRecord(
    id: id,
    projectId: projectId,
    deviceId: deviceId,
    startDate: 20260514,
    contact: contact,
    site: site,
    type: TimingType.hours,
    startMeter: 0,
    endMeter: hours,
    hours: hours,
    income: 800,
  );
}

Project _project({
  required String id,
  required String contact,
  required String site,
}) {
  return Project(
    id: id,
    contact: contact,
    site: site,
    status: ProjectStatus.active,
    createdAt: '2026-05-17T00:00:00.000Z',
    updatedAt: '2026-05-17T00:00:00.000Z',
    legacyProjectKey: '$contact||$site',
  );
}

class _FakeTimingRepository implements TimingRepository {
  final saved = <TimingRecord>[];

  @override
  Future<List<TimingRecord>> listAll() async => const [];

  @override
  Future<TimingRecord> saveWithCalculationHistories(
    TimingRecord record, {
    List<TimingCalculationHistory> calculationHistories = const [],
  }) async {
    final savedRecord = record.id == null ? record.copyWith(id: 99) : record;
    saved.add(savedRecord);
    return savedRecord;
  }

  @override
  Future<int> insert(TimingRecord record) async => 99;

  @override
  Future<int> update(TimingRecord record) async => 1;

  @override
  Future<int> deleteById(int id) async => 1;

  @override
  Future<int> deleteByDeviceId(int deviceId) async => 1;

  @override
  Future<int> deleteByIds(Iterable<int> ids) async => ids.length;
}

class _FakeProjectRepository implements ProjectRepository {
  int findActiveCalls = 0;
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
    findActiveCalls += 1;
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

class _FakeMergeRepository implements AccountProjectMergeRepository {
  _FakeMergeRepository({this.activeProjectId, this.failDissolve = false});

  final String? activeProjectId;
  final bool failDissolve;
  int dissolveCalls = 0;
  final dissolvedGroupIds = <int>[];

  @override
  Future<List<AccountProjectMergeMember>> listActiveMembersByProjectIds(
    List<String> projectIds,
  ) async {
    if (activeProjectId == null || !projectIds.contains(activeProjectId)) {
      return const [];
    }
    return [
      AccountProjectMergeMember(
        groupId: 7,
        projectId: activeProjectId!,
        projectKey: '甲方||一号工地',
        contact: '甲方',
        site: '一号工地',
        sortOrder: 0,
        createdAt: '2026-05-17T00:00:00.000Z',
      ),
    ];
  }

  @override
  Future<AccountProjectMergeGroup?> getGroupById(int groupId) async {
    return AccountProjectMergeGroup(
      id: groupId,
      contact: '甲方',
      createdAt: '2026-05-17T00:00:00.000Z',
    );
  }

  @override
  Future<void> dissolveGroup({
    required int groupId,
    required String dissolvedAt,
  }) async {
    dissolveCalls += 1;
    if (failDissolve) throw StateError('dissolve failed');
    dissolvedGroupIds.add(groupId);
  }

  @override
  Future<AccountProjectMergeGroupWithMembers> createGroupWithMembers({
    required AccountProjectMergeGroup group,
    required List<AccountProjectMergeMember> members,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<AccountProjectMergeGroup>> listActiveGroups() {
    throw UnimplementedError();
  }

  @override
  Future<List<AccountProjectMergeGroupWithMembers>>
  listActiveGroupsWithMembers() {
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
  Future<List<AccountProjectMergeMember>> listMembersByGroupId(int groupId) {
    throw UnimplementedError();
  }
}
