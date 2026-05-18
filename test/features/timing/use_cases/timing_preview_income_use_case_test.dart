import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:asset_ledger/data/repositories/project_repository.dart';
import 'package:asset_ledger/data/services/project_resolver.dart';
import 'package:asset_ledger/features/timing/use_cases/timing_preview_income_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TimingPreviewIncomeUseCase', () {
    test('uses active project_id for project rate preview', () async {
      final repository = _FakeProjectRepository([
        _project(id: 'project:uuid', contact: '甲方', site: '一号工地'),
      ]);
      final useCase = _useCase(repository);

      final amount = await useCase.execute(
        editing: null,
        deviceId: 1,
        contact: '甲方',
        site: '一号工地',
        isBreaking: false,
        hours: 1.0,
        devices: [_device()],
        rates: [
          const ProjectDeviceRate(
            projectId: 'project:uuid',
            projectKey: 'legacy-unused',
            deviceId: 1,
            rate: 180,
          ),
        ],
      );

      expect(amount, 180);
      expect(repository.findActiveCalls, 1);
      expect(repository.inserted, isEmpty);
    });

    test(
      'does not create a project when preview has no active match',
      () async {
        final repository = _FakeProjectRepository([]);
        final useCase = _useCase(repository);

        final amount = await useCase.execute(
          editing: null,
          deviceId: 1,
          contact: '甲方',
          site: '新工地',
          isBreaking: false,
          hours: 1.0,
          devices: [_device()],
          rates: [
            const ProjectDeviceRate(
              projectId: 'project:other',
              projectKey: 'legacy-unused',
              deviceId: 1,
              rate: 180,
            ),
          ],
        );

        expect(amount, 100);
        expect(repository.findActiveCalls, 1);
        expect(repository.inserted, isEmpty);
      },
    );

    test(
      'settled projects do not participate in preview rate matching',
      () async {
        final repository = _FakeProjectRepository([
          _project(
            id: 'project:settled',
            contact: '甲方',
            site: '一号工地',
            status: ProjectStatus.settled,
          ),
        ]);
        final useCase = _useCase(repository);

        final amount = await useCase.execute(
          editing: null,
          deviceId: 1,
          contact: '甲方',
          site: '一号工地',
          isBreaking: false,
          hours: 1.0,
          devices: [_device()],
          rates: [
            const ProjectDeviceRate(
              projectId: 'project:settled',
              projectKey: 'legacy-unused',
              deviceId: 1,
              rate: 180,
            ),
          ],
        );

        expect(amount, 100);
        expect(repository.findActiveCalls, 1);
        expect(repository.inserted, isEmpty);
      },
    );
  });
}

TimingPreviewIncomeUseCase _useCase(_FakeProjectRepository repository) {
  return TimingPreviewIncomeUseCase(
    projectResolver: ProjectResolver(
      projectRepository: repository,
      now: () => DateTime.utc(2026, 5, 17),
    ),
  );
}

Device _device() {
  return const Device(
    id: 1,
    name: 'SANY 1#',
    brand: 'sany',
    defaultUnitPrice: 100,
    baseMeterHours: 0,
  );
}

Project _project({
  required String id,
  required String contact,
  required String site,
  ProjectStatus status = ProjectStatus.active,
}) {
  return Project(
    id: id,
    contact: contact,
    site: site,
    status: status,
    createdAt: '2026-05-17T00:00:00.000Z',
    updatedAt: '2026-05-17T00:00:00.000Z',
  );
}

class _FakeProjectRepository implements ProjectRepository {
  _FakeProjectRepository(this.projects);

  final List<Project> projects;
  final inserted = <Project>[];
  int findActiveCalls = 0;

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
    findActiveCalls++;
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
