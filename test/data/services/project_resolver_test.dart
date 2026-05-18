import 'package:asset_ledger/data/models/project.dart';
import 'package:asset_ledger/data/repositories/project_repository.dart';
import 'package:asset_ledger/data/services/project_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProjectResolver', () {
    test('matches a unique active project by contact and site', () async {
      final repository = _FakeProjectRepository([
        _project(id: 'project:active', contact: '甲方', site: '一号工地'),
      ]);
      final resolver = _resolver(repository);

      final result = await resolver.resolveOrCreate(
        contact: ' 甲方 ',
        site: ' 一号工地 ',
      );

      expect(result.created, isFalse);
      expect(result.projectId, 'project:active');
      expect(repository.inserted, isEmpty);
    });

    test('settled projects do not participate in automatic matching', () async {
      final repository = _FakeProjectRepository([
        _project(
          id: 'project:settled',
          contact: '甲方',
          site: '一号工地',
          status: ProjectStatus.settled,
          settledAt: '2026-05-01T00:00:00.000Z',
        ),
      ]);
      final resolver = _resolver(repository);

      final result = await resolver.resolveOrCreate(
        contact: '甲方',
        site: '一号工地',
      );

      expect(result.created, isTrue);
      expect(result.projectId, isNot('project:settled'));
      expect(repository.inserted.single.status, ProjectStatus.active);
    });

    test(
      'same contact and site creates a new project after old one settled',
      () async {
        final repository = _FakeProjectRepository([
          _project(
            id: 'project:old',
            contact: '甲方',
            site: '同一工地',
            status: ProjectStatus.settled,
            settledAt: '2026-05-01T00:00:00.000Z',
          ),
        ]);
        final resolver = _resolver(repository);

        final result = await resolver.resolveOrCreate(
          contact: '甲方',
          site: '同一工地',
        );

        expect(result.created, isTrue);
        expect(result.projectId, startsWith('project:'));
        expect(result.projectId, isNot('project:old'));
        expect(repository.inserted.single.contact, '甲方');
        expect(repository.inserted.single.site, '同一工地');
      },
    );
  });
}

ProjectResolver _resolver(_FakeProjectRepository repository) {
  return ProjectResolver(
    projectRepository: repository,
    now: () => DateTime.utc(2026, 5, 17),
  );
}

Project _project({
  required String id,
  required String contact,
  required String site,
  ProjectStatus status = ProjectStatus.active,
  String? settledAt,
}) {
  return Project(
    id: id,
    contact: contact,
    site: site,
    status: status,
    settledAt: settledAt,
    createdAt: '2026-05-17T00:00:00.000Z',
    updatedAt: '2026-05-17T00:00:00.000Z',
  );
}

class _FakeProjectRepository implements ProjectRepository {
  _FakeProjectRepository(this.projects);

  final List<Project> projects;
  final inserted = <Project>[];

  @override
  Future<List<Project>> listAll() async => [...projects, ...inserted];

  @override
  Future<Project?> findById(String id) async {
    for (final project in [...projects, ...inserted]) {
      if (project.id == id) return project;
    }
    return null;
  }

  @override
  Future<List<Project>> findActiveByContactSite({
    required String contact,
    required String site,
  }) async {
    return [...projects, ...inserted]
        .where((project) {
          return project.contact == contact.trim() &&
              project.site == site.trim() &&
              project.status == ProjectStatus.active;
        })
        .toList(growable: false);
  }

  @override
  Future<void> insert(Project project) async {
    inserted.add(project);
  }

  @override
  Future<Project> findOrCreateLegacyProject({
    required String contact,
    required String site,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> upsert(Project project) async {
    inserted.add(project);
  }
}
