import 'package:asset_ledger/features/account/view/dialogs/account_project_merge_sheet_data.dart';
import 'package:asset_ledger/features/account/view/dialogs/account_project_merge_sheet_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MergeProjectSheetStore', () {
    test(
      'can confirm after selecting two unmerged projects for one contact',
      () {
        final store = MergeProjectSheetStore(groups: _groups);

        store.toggleProject(_groups[0].unmergedItems[0], '李杰');
        expect(store.canConfirm, isFalse);

        store.toggleProject(_groups[0].unmergedItems[1], '李杰');

        expect(store.selectedContact, '李杰');
        expect(store.selectedProjectIds, {
          'project:lijie-xincun',
          'project:lijie-gaoqiao',
        });
        expect(store.selectedProjectKeys, {'李杰||新村', '李杰||高桥'});
        expect(store.canConfirm, isTrue);
      },
    );

    test('cannot confirm with only one selected project', () {
      final store = MergeProjectSheetStore(groups: _groups);

      store.toggleProject(_groups[0].unmergedItems[0], '李杰');

      expect(store.selectedProjectIds, {'project:lijie-xincun'});
      expect(store.selectedProjectKeys, {'李杰||新村'});
      expect(store.canConfirm, isFalse);
    });

    test('clears prior selection when switching contact', () {
      final store = MergeProjectSheetStore(groups: _groups);

      store.toggleProject(_groups[0].unmergedItems[0], '李杰');
      store.toggleProject(_groups[0].unmergedItems[1], '李杰');
      store.toggleProject(_groups[1].unmergedItems[0], '王涛');

      expect(store.selectedContact, '王涛');
      expect(store.selectedProjectIds, {'project:wangtao-1'});
      expect(store.selectedProjectKeys, {'王涛||一号'});
      expect(store.canConfirm, isFalse);
    });

    test('does not select merged projects', () {
      final store = MergeProjectSheetStore(groups: _groups);

      store.toggleProject(_groups[0].mergedItems[0], '李杰');

      expect(store.selectedContact, isNull);
      expect(store.selectedProjectIds, isEmpty);
      expect(store.selectedProjectKeys, isEmpty);
      expect(store.canConfirm, isFalse);
    });
  });
}

const _groups = [
  MergeProjectSheetContactGroup(
    contact: '李杰',
    unmergedItems: [
      MergeProjectSheetItem(
        projectId: 'project:lijie-xincun',
        projectKey: '李杰||新村',
        displayName: '李杰 + 新村',
        isMerged: false,
      ),
      MergeProjectSheetItem(
        projectId: 'project:lijie-gaoqiao',
        projectKey: '李杰||高桥',
        displayName: '李杰 + 高桥',
        isMerged: false,
      ),
    ],
    mergedItems: [
      MergeProjectSheetItem(
        projectId: 'project:lijie-shangyi',
        projectKey: '李杰||尚义',
        displayName: '李杰 + 尚义',
        isMerged: true,
      ),
    ],
  ),
  MergeProjectSheetContactGroup(
    contact: '王涛',
    unmergedItems: [
      MergeProjectSheetItem(
        projectId: 'project:wangtao-1',
        projectKey: '王涛||一号',
        displayName: '王涛 + 一号',
        isMerged: false,
      ),
      MergeProjectSheetItem(
        projectId: 'project:wangtao-2',
        projectKey: '王涛||二号',
        displayName: '王涛 + 二号',
        isMerged: false,
      ),
    ],
    mergedItems: [],
  ),
];
