import 'package:asset_ledger/features/account/model/account_view_model.dart';
import 'package:asset_ledger/features/account/state/account_filter_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccountFilterStore', () {
    test('matches merged projects by display name and included sites', () {
      final store = AccountFilterStore();
      const merged = AccountProjectVM(
        projectKey: 'merge:1',
        displayName: '李杰 + 合并2项目',
        kind: AccountProjectKind.merged,
        mergeGroupId: 1,
        memberProjectKeys: ['李杰||尚义', '李杰||鲜滩'],
        includedSites: ['尚义', '鲜滩'],
        includedSitesText: '含：尚义、鲜滩',
        minYmd: 20260312,
        deviceIds: [1],
        hoursByDevice: {1: 10},
        rentIncomeTotal: 0,
        minRate: 100,
        isMultiDevice: false,
        isMultiMode: false,
        receivable: 1000,
        received: 0,
        remaining: 1000,
        ratio: 0,
        payments: [],
      );
      const normal = AccountProjectVM(
        projectKey: '王涛||高桥',
        displayName: '王涛 + 高桥',
        minYmd: 20260313,
        deviceIds: [1],
        hoursByDevice: {1: 10},
        rentIncomeTotal: 0,
        minRate: 100,
        isMultiDevice: false,
        isMultiMode: false,
        receivable: 1000,
        received: 0,
        remaining: 1000,
        ratio: 0,
        payments: [],
      );

      store.setProjectFilterKeyword('鲜滩');

      expect(store.filterProjects(const [merged, normal]), [merged]);

      store.setProjectFilterKeyword('李杰');

      expect(store.filterProjects(const [merged, normal]), [merged]);
    });
  });
}
