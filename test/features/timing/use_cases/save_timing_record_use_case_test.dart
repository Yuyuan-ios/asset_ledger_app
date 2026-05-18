import 'package:asset_ledger/data/models/account_project_merge_group.dart';
import 'package:asset_ledger/data/models/account_project_merge_group_with_members.dart';
import 'package:asset_ledger/data/models/account_project_merge_member.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/repositories/account_project_merge_repository.dart';
import 'package:asset_ledger/data/repositories/project_repository.dart';
import 'package:asset_ledger/data/repositories/timing_repository.dart';
import 'package:asset_ledger/data/services/account_project_merge_service.dart';
import 'package:asset_ledger/data/services/project_resolver.dart';
import 'package:asset_ledger/features/timing/calculator/model/timing_calculation_history.dart';
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

    test(
      'editing same projectId does not dissolve even if contact changes',
      () async {
        final timingRepository = _FakeTimingRepository();
        final mergeRepository = _FakeMergeRepository(
          activeProjectId: 'project:a',
        );
        final useCase = _useCase(timingRepository, mergeRepository);

        final result = await useCase.execute(
          editing: _record(projectId: 'project:a', contact: '甲方'),
          record: _record(projectId: 'project:a', contact: '甲方新名称'),
        );

        expect(result.needsMergeDissolveRetry, isFalse);
        expect(mergeRepository.dissolveCalls, 0);
        expect(timingRepository.saved.single.projectId, 'project:a');
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
      mergeService: AccountProjectMergeService(repository: mergeRepository),
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
  String contact = '甲方',
  String site = '一号工地',
}) {
  return TimingRecord(
    id: id,
    projectId: projectId,
    deviceId: 1,
    startDate: 20260514,
    contact: contact,
    site: site,
    type: TimingType.hours,
    startMeter: 0,
    endMeter: 8,
    hours: 8,
    income: 800,
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
