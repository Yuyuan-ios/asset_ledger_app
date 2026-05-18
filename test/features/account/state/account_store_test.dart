import 'package:asset_ledger/data/models/account_project_merge_group.dart';
import 'package:asset_ledger/data/models/account_project_merge_group_with_members.dart';
import 'package:asset_ledger/data/models/account_project_merge_member.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/project_id.dart';
import 'package:asset_ledger/data/models/project_write_off.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/repositories/account_project_merge_repository.dart';
import 'package:asset_ledger/data/repositories/project_write_off_repository.dart';
import 'package:asset_ledger/data/services/account_project_merge_service.dart';
import 'package:asset_ledger/features/account/model/account_view_model.dart';
import 'package:asset_ledger/features/account/state/account_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccountStore active merge groups', () {
    test(
      'keeps original output when no active merge groups are loaded',
      () async {
        final store = AccountStore(
          mergeService: AccountProjectMergeService(
            repository: _FakeMergeRepository(activeGroups: const []),
          ),
        );

        await store.loadAll();

        final result = store.compute(
          timingRecords: _timingRecords,
          devices: _devices,
          rates: const [],
          payments: const [],
        );

        expect(result.projects.map((project) => project.projectKey).toList(), [
          '李杰||鲜滩',
          '李杰||尚义',
        ]);
        expect(
          result.projects.every(
            (project) => project.kind == AccountProjectKind.normal,
          ),
          isTrue,
        );
      },
    );

    test(
      'passes loaded active merge groups into account aggregation',
      () async {
        final store = AccountStore(
          mergeService: AccountProjectMergeService(
            repository: _FakeMergeRepository(
              activeGroups: const [
                AccountProjectMergeGroupWithMembers(
                  group: AccountProjectMergeGroup(
                    id: 1,
                    contact: '李杰',
                    createdAt: '2026-05-15T00:00:00.000Z',
                  ),
                  members: [
                    AccountProjectMergeMember(
                      id: 1,
                      groupId: 1,
                      projectKey: '李杰||尚义',
                      contact: '李杰',
                      site: '尚义',
                      sortOrder: 0,
                      createdAt: '2026-05-15T00:00:00.000Z',
                    ),
                    AccountProjectMergeMember(
                      id: 2,
                      groupId: 1,
                      projectKey: '李杰||鲜滩',
                      contact: '李杰',
                      site: '鲜滩',
                      sortOrder: 1,
                      createdAt: '2026-05-15T00:00:00.000Z',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );

        await store.loadAll();

        final result = store.compute(
          timingRecords: _timingRecords,
          devices: _devices,
          rates: const [],
          payments: const [],
        );

        expect(result.projects, hasLength(1));
        final merged = result.projects.single;
        expect(merged.projectKey, 'merge:1');
        expect(merged.kind, AccountProjectKind.merged);
        expect(merged.displayName, '李杰 + 合并2项目');
        expect(merged.memberProjectKeys, ['李杰||尚义', '李杰||鲜滩']);
        expect(merged.includedSitesText, '含：尚义、鲜滩');
      },
    );

    test(
      'uses BaseStore error state when loading merge groups fails',
      () async {
        final store = AccountStore(
          mergeService: AccountProjectMergeService(
            repository: _FakeMergeRepository(error: StateError('merge failed')),
          ),
        );

        await expectLater(store.loadAll(), throwsStateError);

        expect(store.loading, isFalse);
        expect(store.error, contains('merge failed'));
        expect(store.activeMergeGroups, isEmpty);
      },
    );

    test('uses loaded write-offs when computing summaries', () async {
      final store = AccountStore(
        mergeService: AccountProjectMergeService(
          repository: _FakeMergeRepository(activeGroups: const []),
        ),
        writeOffRepository: _FakeWriteOffRepository(
          items: [
            ProjectWriteOff(
              id: 'write-off-1',
              projectId: ProjectId.legacyFromKey('李杰||鲜滩'),
              amount: 1000,
              reason: ProjectWriteOffReason.settlement.dbValue,
              writeOffDate: '2026-05-16',
              createdAt: '2026-05-16T00:00:00.000Z',
              updatedAt: '2026-05-16T00:00:00.000Z',
            ),
          ],
        ),
      );

      await store.loadAll();

      final result = store.compute(
        timingRecords: _timingRecords,
        devices: _devices,
        rates: const [],
        payments: const [],
      );

      final xiantan = result.projects.firstWhere(
        (project) => project.projectKey == '李杰||鲜滩',
      );

      expect(store.writeOffs, hasLength(1));
      expect(xiantan.receivable, 1000);
      expect(xiantan.writeOff, 1000);
      expect(xiantan.remaining, 0);
      expect(result.totalWriteOff, 1000);
      expect(result.totalRemaining, 1000);
    });

    test('refreshes account totals after a write-off is deleted', () async {
      final writeOffItems = <ProjectWriteOff>[
        ProjectWriteOff(
          id: 'write-off-1',
          projectId: ProjectId.legacyFromKey('李杰||鲜滩'),
          amount: 1000,
          reason: ProjectWriteOffReason.settlement.dbValue,
          writeOffDate: '2026-05-16',
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        ),
      ];
      final store = AccountStore(
        mergeService: AccountProjectMergeService(
          repository: _FakeMergeRepository(activeGroups: const []),
        ),
        writeOffRepository: _FakeWriteOffRepository(items: writeOffItems),
      );

      await store.loadAll();
      final before = store.compute(
        timingRecords: _timingRecords,
        devices: _devices,
        rates: const [],
        payments: const [],
      );

      writeOffItems.clear();
      await store.loadAll();
      final after = store.compute(
        timingRecords: _timingRecords,
        devices: _devices,
        rates: const [],
        payments: const [],
      );

      expect(before.totalReceivable, 2000);
      expect(before.totalWriteOff, 1000);
      expect(before.totalRemaining, 1000);
      expect(after.totalReceivable, 2000);
      expect(after.totalWriteOff, 0);
      expect(after.totalRemaining, 2000);
    });
  });
}

const _timingRecords = [
  TimingRecord(
    id: 1,
    deviceId: 1,
    startDate: 20260312,
    contact: '李杰',
    site: '尚义',
    type: TimingType.hours,
    startMeter: 0,
    endMeter: 10,
    hours: 10,
    income: 0,
  ),
  TimingRecord(
    id: 2,
    deviceId: 1,
    startDate: 20260323,
    contact: '李杰',
    site: '鲜滩',
    type: TimingType.hours,
    startMeter: 10,
    endMeter: 20,
    hours: 10,
    income: 0,
  ),
];

const _devices = [
  Device(
    id: 1,
    name: 'HITACHI 1#',
    brand: 'HITACHI',
    defaultUnitPrice: 100,
    baseMeterHours: 0,
  ),
];

class _FakeMergeRepository implements AccountProjectMergeRepository {
  _FakeMergeRepository({this.activeGroups = const [], this.error});

  final List<AccountProjectMergeGroupWithMembers> activeGroups;
  final Object? error;

  @override
  Future<List<AccountProjectMergeGroupWithMembers>>
  listActiveGroupsWithMembers() async {
    final error = this.error;
    if (error != null) throw error;
    return activeGroups;
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

class _FakeWriteOffRepository implements ProjectWriteOffRepository {
  _FakeWriteOffRepository({required this.items});

  final List<ProjectWriteOff> items;

  @override
  Future<List<ProjectWriteOff>> listAll() async => List.of(items);

  @override
  Future<int> clearAllForRestore() {
    throw UnimplementedError();
  }

  @override
  Future<int> deleteById(String id) {
    throw UnimplementedError();
  }

  @override
  Future<void> insert(ProjectWriteOff item) {
    throw UnimplementedError();
  }

  @override
  Future<List<ProjectWriteOff>> listByProjectId(String projectId) {
    throw UnimplementedError();
  }

  @override
  Future<double> sumByProjectId(String projectId) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, double>> sumByProjectIds(Iterable<String> projectIds) {
    throw UnimplementedError();
  }

  @override
  Future<int> update(ProjectWriteOff item) {
    throw UnimplementedError();
  }
}
