import 'package:asset_ledger/data/models/account_project_merge_member.dart';
import 'package:asset_ledger/data/models/project_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccountProjectMergeMember', () {
    test('toMap and fromMap use storage field names and defaults', () {
      const member = AccountProjectMergeMember(
        id: 9,
        groupId: 3,
        projectKey: '李杰||尚义',
        contact: '李杰',
        site: '尚义',
        sortOrder: 1,
        createdAt: '2026-05-15T01:02:03.000Z',
        isActive: false,
      );

      expect(member.toMap(), {
        'id': 9,
        'group_id': 3,
        'project_id': ProjectId.legacyFromKey('李杰||尚义'),
        'project_key': '李杰||尚义',
        'contact': '李杰',
        'site': '尚义',
        'sort_order': 1,
        'created_at': '2026-05-15T01:02:03.000Z',
        'is_active': 0,
      });

      final rebuilt = AccountProjectMergeMember.fromMap({
        'id': 10,
        'group_id': 4,
        'project_key': '王涛||高桥',
        'contact': '王涛',
        'site': '高桥',
        'created_at': '2026-05-16T01:02:03.000Z',
      });

      expect(rebuilt.id, 10);
      expect(rebuilt.groupId, 4);
      expect(rebuilt.effectiveProjectId, ProjectId.legacyFromKey('王涛||高桥'));
      expect(rebuilt.projectKey, '王涛||高桥');
      expect(rebuilt.contact, '王涛');
      expect(rebuilt.site, '高桥');
      expect(rebuilt.sortOrder, 0);
      expect(rebuilt.createdAt, '2026-05-16T01:02:03.000Z');
      expect(rebuilt.isActive, isTrue);
    });
  });
}
