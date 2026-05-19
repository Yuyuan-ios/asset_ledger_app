import 'package:asset_ledger/data/models/account_project_merge_group.dart';
import 'package:asset_ledger/data/models/account_project_merge_group_with_members.dart';
import 'package:asset_ledger/data/models/account_project_merge_member.dart';
import 'package:asset_ledger/features/account/model/account_view_model.dart';
import 'package:asset_ledger/features/account/view/dialogs/account_project_merge_sheet_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildMergeSheetGroups', () {
    test('only returns contact groups with at least two projects', () {
      final groups = buildMergeSheetGroups(
        normalProjects: [
          _project('project:lijie-xincun', '李杰||新村', '李杰 + 新村'),
          _project('project:lijie-gaoqiao', '李杰||高桥', '李杰 + 高桥'),
          _project('project:wangtao-dushan', '王涛||独山', '王涛 + 独山'),
        ],
        activeMergeGroups: const [],
      );

      expect(groups.map((group) => group.contact).toList(), ['李杰']);
      expect(groups.single.unmergedItems.map((item) => item.projectKey), [
        '李杰||新村',
        '李杰||高桥',
      ]);
      expect(groups.single.unmergedItems.map((item) => item.projectId), [
        'project:lijie-xincun',
        'project:lijie-gaoqiao',
      ]);
    });

    test('keeps unmerged items before merged items in each group', () {
      final groups = buildMergeSheetGroups(
        normalProjects: [_project('project:lijie-xincun', '李杰||新村', '李杰 + 新村')],
        activeMergeGroups: const [_activeGroup],
      );

      final group = groups.single;
      expect(group.unmergedItems.map((item) => item.displayName), ['李杰 + 新村']);
      expect(group.mergedItems.map((item) => item.displayName), [
        '李杰 + 尚义',
        '李杰 + 鲜滩',
      ]);
    });

    test('marks active merge members as merged items', () {
      final groups = buildMergeSheetGroups(
        normalProjects: const [],
        activeMergeGroups: const [_activeGroup],
      );

      final mergedItems = groups.single.mergedItems;
      expect(mergedItems.every((item) => item.isMerged), isTrue);
      expect(mergedItems.map((item) => item.projectKey), ['李杰||尚义', '李杰||鲜滩']);
    });

    test('excludes active merge members from unmerged items', () {
      final groups = buildMergeSheetGroups(
        normalProjects: [
          _project('project:lijie-xiantan', '李杰||鲜滩', '李杰 + 鲜滩'),
          _project('project:lijie-new', '李杰||新地址', '李杰 + 新地址'),
        ],
        activeMergeGroups: const [_activeGroup],
      );

      final group = groups.single;
      expect(group.unmergedItems.map((item) => item.projectKey), ['李杰||新地址']);
      expect(group.mergedItems.map((item) => item.projectKey), [
        '李杰||尚义',
        '李杰||鲜滩',
      ]);

      final unmergedKeys = group.unmergedItems.map((item) => item.projectKey);
      final mergedKeys = group.mergedItems.map((item) => item.projectKey);
      expect(unmergedKeys.toSet().intersection(mergedKeys.toSet()), isEmpty);
    });

    test(
      'does not duplicate active members when a group contains stale keys',
      () {
        final groups = buildMergeSheetGroups(
          normalProjects: [
            _project('project:lijie-xiantan', '李杰||鲜滩', '李杰 + 鲜滩'),
            _project('project:lijie-new', '李杰||新地址', '李杰 + 新地址'),
          ],
          activeMergeGroups: const [_activeGroupWithStaleMember],
        );

        final group = groups.single;
        expect(group.unmergedItems.map((item) => item.projectKey), ['李杰||新地址']);
        expect(group.mergedItems.map((item) => item.projectKey), [
          '李杰||鲜滩',
          '李杰||尚义',
        ]);

        final unmergedKeys = group.unmergedItems.map((item) => item.projectKey);
        final mergedKeys = group.mergedItems.map((item) => item.projectKey);
        expect(unmergedKeys.toSet().intersection(mergedKeys.toSet()), isEmpty);
      },
    );

    test('excludes settled project ids from merge candidates', () {
      final groups = buildMergeSheetGroups(
        normalProjects: [
          _project('project:settled', '李杰||尚义', '李杰 + 尚义'),
          _project('project:active-a', '李杰||鲜滩', '李杰 + 鲜滩'),
          _project('project:active-b', '李杰||高桥', '李杰 + 高桥'),
        ],
        activeMergeGroups: const [],
        excludedProjectIds: const {'project:settled'},
      );

      expect(groups, hasLength(1));
      expect(groups.single.unmergedItems.map((item) => item.projectId), [
        'project:active-a',
        'project:active-b',
      ]);
      expect(
        groups.single.unmergedItems.map((item) => item.projectKey),
        isNot(contains('李杰||尚义')),
      );
    });

    test(
      'active projects can rejoin recommendations after exclusion is removed',
      () {
        final projects = [
          _project('project:restored', '李杰||尚义', '李杰 + 尚义'),
          _project('project:active', '李杰||鲜滩', '李杰 + 鲜滩'),
        ];

        final excluded = buildMergeSheetGroups(
          normalProjects: projects,
          activeMergeGroups: const [],
          excludedProjectIds: const {'project:restored'},
        );
        final restored = buildMergeSheetGroups(
          normalProjects: projects,
          activeMergeGroups: const [],
          excludedProjectIds: const {},
        );

        expect(excluded, isEmpty);
        expect(restored.single.unmergedItems.map((item) => item.projectId), [
          'project:restored',
          'project:active',
        ]);
      },
    );

    test(
      'does not connect active replacement projects to settled old projects',
      () {
        final groups = buildMergeSheetGroups(
          normalProjects: [
            _project('project:settled-old', '李杰||尚义', '李杰 + 尚义'),
            _project('project:active-new', '李杰||尚义', '李杰 + 尚义'),
            _project('project:active-other', '李杰||鲜滩', '李杰 + 鲜滩'),
          ],
          activeMergeGroups: const [],
          excludedProjectIds: const {'project:settled-old'},
        );

        expect(groups.single.unmergedItems.map((item) => item.projectId), [
          'project:active-new',
          'project:active-other',
        ]);
      },
    );

    test('does not include a contact with only one project', () {
      final groups = buildMergeSheetGroups(
        normalProjects: [_project('project:zhaoliu', '赵六||尚义', '赵六 + 尚义')],
        activeMergeGroups: const [],
      );

      expect(groups, isEmpty);
    });
  });
}

AccountProjectVM _project(
  String projectId,
  String projectKey,
  String displayName,
) {
  return AccountProjectVM(
    projectId: projectId,
    projectKey: projectKey,
    displayName: displayName,
    minYmd: 20260515,
    deviceIds: const [],
    hoursByDevice: const {},
    rentIncomeTotal: 0,
    minRate: null,
    isMultiDevice: false,
    isMultiMode: false,
    receivable: 0,
    received: 0,
    remaining: 0,
    ratio: null,
    payments: const [],
  );
}

const _activeGroupWithStaleMember = AccountProjectMergeGroupWithMembers(
  group: AccountProjectMergeGroup(
    id: 2,
    contact: '李杰',
    createdAt: '2026-05-15T00:00:00.000Z',
  ),
  members: [
    AccountProjectMergeMember(
      id: 3,
      groupId: 2,
      projectKey: '李杰||鲜滩',
      contact: '李杰',
      site: '鲜滩',
      sortOrder: 0,
      createdAt: '2026-05-15T00:00:00.000Z',
    ),
    AccountProjectMergeMember(
      id: 4,
      groupId: 2,
      projectKey: '李杰||尚义',
      contact: '李杰',
      site: '尚义',
      sortOrder: 1,
      createdAt: '2026-05-15T00:00:00.000Z',
    ),
  ],
);

const _activeGroup = AccountProjectMergeGroupWithMembers(
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
);
