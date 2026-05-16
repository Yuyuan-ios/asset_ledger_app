import 'package:asset_ledger/data/models/account_project_merge_group.dart';
import 'package:asset_ledger/data/models/account_project_merge_group_with_members.dart';
import 'package:asset_ledger/data/models/account_project_merge_member.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/repositories/account_project_merge_repository.dart';
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
  Future<List<AccountProjectMergeMember>> listMembersByGroupId(int groupId) {
    throw UnimplementedError();
  }
}
