import 'package:asset_ledger/features/account/view/dialogs/account_project_merge_sheet_data.dart';
import 'package:asset_ledger/features/account/view/dialogs/account_project_merge_sheet_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MergeProjectSheetStore', () {
    test(
      'can confirm after selecting two unmerged projects for one contact',
      () {
        final store = MergeProjectSheetStore(groups: _groups);

        store.toggleProject('李杰||新村', '李杰');
        expect(store.canConfirm, isFalse);

        store.toggleProject('李杰||高桥', '李杰');

        expect(store.selectedContact, '李杰');
        expect(store.selectedProjectKeys, {'李杰||新村', '李杰||高桥'});
        expect(store.canConfirm, isTrue);
      },
    );

    test('cannot confirm with only one selected project', () {
      final store = MergeProjectSheetStore(groups: _groups);

      store.toggleProject('李杰||新村', '李杰');

      expect(store.selectedProjectKeys, {'李杰||新村'});
      expect(store.canConfirm, isFalse);
    });

    test('clears prior selection when switching contact', () {
      final store = MergeProjectSheetStore(groups: _groups);

      store.toggleProject('李杰||新村', '李杰');
      store.toggleProject('李杰||高桥', '李杰');
      store.toggleProject('王涛||一号', '王涛');

      expect(store.selectedContact, '王涛');
      expect(store.selectedProjectKeys, {'王涛||一号'});
      expect(store.canConfirm, isFalse);
    });

    test('does not select merged projects', () {
      final store = MergeProjectSheetStore(groups: _groups);

      store.toggleProject('李杰||尚义', '李杰');

      expect(store.selectedContact, isNull);
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
        projectKey: '李杰||新村',
        displayName: '李杰 + 新村',
        isMerged: false,
      ),
      MergeProjectSheetItem(
        projectKey: '李杰||高桥',
        displayName: '李杰 + 高桥',
        isMerged: false,
      ),
    ],
    mergedItems: [
      MergeProjectSheetItem(
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
        projectKey: '王涛||一号',
        displayName: '王涛 + 一号',
        isMerged: false,
      ),
      MergeProjectSheetItem(
        projectKey: '王涛||二号',
        displayName: '王涛 + 二号',
        isMerged: false,
      ),
    ],
    mergedItems: [],
  ),
];
