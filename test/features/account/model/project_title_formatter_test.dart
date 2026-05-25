import 'package:asset_ledger/features/account/model/project_title_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProjectTitleFormatter', () {
    test('formats contact and site with middle dot separator', () {
      expect(
        ProjectTitleFormatter.project(contact: '李杰', site: '成都双流工地'),
        '李杰 · 成都双流工地',
      );
      expect(
        ProjectTitleFormatter.project(
          contact: 'John Smith',
          site: 'Brooklyn Site',
        ),
        'John Smith · Brooklyn Site',
      );
    });

    test('formats merged project title in one place', () {
      expect(
        ProjectTitleFormatter.merged(contact: '李杰', count: 2),
        '李杰 · 合并2项目',
      );
    });

    test('omits dangling separators when one side is blank', () {
      expect(ProjectTitleFormatter.project(contact: '李杰', site: ''), '李杰');
      expect(
        ProjectTitleFormatter.project(contact: '', site: '成都双流工地'),
        '成都双流工地',
      );
      expect(
        ProjectTitleFormatter.project(contact: '', site: ''),
        ProjectTitleFormatter.unnamedProject,
      );
    });

    test('normalizes legacy visible titles and strips linked copy', () {
      final normalized = ProjectTitleFormatter.normalize('李杰•天眉乐 + 关联');

      expect(normalized, '李杰 · 天眉乐');
      expect(normalized, isNot(contains('+')));
      expect(normalized, isNot(contains('•')));
      expect(normalized, isNot(contains('关联')));
    });
  });
}
