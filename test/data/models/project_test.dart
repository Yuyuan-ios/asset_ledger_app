import 'package:asset_ledger/data/models/project.dart';
import 'package:asset_ledger/data/models/project_id.dart';
import 'package:asset_ledger/data/models/project_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Project', () {
    test('keeps contact and site as attributes instead of identity', () {
      final first = Project(
        id: ProjectId.create(),
        contact: '甲方',
        site: '一号工地',
        createdAt: '2026-05-17T00:00:00.000Z',
        updatedAt: '2026-05-17T00:00:00.000Z',
      );
      final second = Project(
        id: ProjectId.create(),
        contact: '甲方',
        site: '一号工地',
        createdAt: '2026-05-17T00:00:01.000Z',
        updatedAt: '2026-05-17T00:00:01.000Z',
      );

      expect(first.contact, second.contact);
      expect(first.site, second.site);
      expect(first.id, isNot(second.id));
    });

    test('legacy project ids are stable for the same legacy key', () {
      final key = ProjectKey.buildKey(contact: '甲方||分公司', site: '一号工地');

      expect(ProjectId.legacyFromKey(key), ProjectId.legacyFromKey(key));
      expect(
        Project.legacy(
          contact: '甲方||分公司',
          site: '一号工地',
          timestamp: '2026-05-17T00:00:00.000Z',
        ).id,
        ProjectId.legacyFromKey(key),
      );
    });

    test('fromMap fills legacy fields safely for partial rows', () {
      final project = Project.fromMap({'contact': '甲方', 'site': '一号工地'});

      expect(project.contact, '甲方');
      expect(project.site, '一号工地');
      expect(project.status, ProjectStatus.active);
      expect(
        project.id,
        ProjectId.legacyFromParts(contact: '甲方', site: '一号工地'),
      );
      expect(project.legacyProjectKey, '甲方||一号工地');
    });
  });
}
