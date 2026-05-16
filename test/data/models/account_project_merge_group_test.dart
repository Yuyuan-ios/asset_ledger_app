import 'package:asset_ledger/data/models/account_project_merge_group.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccountProjectMergeGroup', () {
    test('toMap and fromMap use storage field names and defaults', () {
      const group = AccountProjectMergeGroup(
        id: 7,
        contact: '李杰',
        createdAt: '2026-05-15T01:02:03.000Z',
        updatedAt: '2026-05-15T01:02:04.000Z',
        isActive: false,
        dissolvedAt: '2026-05-15T01:02:05.000Z',
        sourceType: 'local',
      );

      expect(group.toMap(), {
        'id': 7,
        'contact': '李杰',
        'created_at': '2026-05-15T01:02:03.000Z',
        'updated_at': '2026-05-15T01:02:04.000Z',
        'is_active': 0,
        'dissolved_at': '2026-05-15T01:02:05.000Z',
        'source_type': 'local',
      });

      final rebuilt = AccountProjectMergeGroup.fromMap({
        'id': 8,
        'contact': '王涛',
        'created_at': '2026-05-16T01:02:03.000Z',
      });

      expect(rebuilt.id, 8);
      expect(rebuilt.contact, '王涛');
      expect(rebuilt.createdAt, '2026-05-16T01:02:03.000Z');
      expect(rebuilt.updatedAt, isNull);
      expect(rebuilt.isActive, isTrue);
      expect(rebuilt.dissolvedAt, isNull);
      expect(rebuilt.sourceType, 'local');
    });
  });
}
