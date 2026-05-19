import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:asset_ledger/data/models/project_id.dart';
import 'package:asset_ledger/data/repositories/account_project_merge_repository.dart';
import 'package:asset_ledger/data/repositories/project_repository.dart';
import 'package:asset_ledger/data/services/account_project_merge_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  late SqfliteAccountProjectMergeRepository repository;
  late SqfliteProjectRepository projectRepository;
  late AccountProjectMergeService service;

  setUp(() async {
    await AppDatabase.resetForTest();
    AppDatabase.debugInitDbOverride = () {
      return openDatabase(
        inMemoryDatabasePath,
        version: AppDatabase.schemaVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, _) => DbSchema.create(db),
      );
    };
    repository = SqfliteAccountProjectMergeRepository();
    projectRepository = SqfliteProjectRepository();
    service = AccountProjectMergeService(
      repository: repository,
      projectRepository: projectRepository,
      now: () => DateTime.utc(2026, 5, 15, 1, 2, 3),
    );
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  test('creates a group with members and queries active groups', () async {
    final created = await service.createMergeGroup(
      contact: '李杰',
      projectKeys: ['李杰||尚义', '李杰||鲜滩'],
    );

    expect(created.group.id, isNotNull);
    expect(created.group.contact, '李杰');
    expect(created.group.isActive, isTrue);
    expect(created.group.createdAt, '2026-05-15T01:02:03.000Z');
    expect(created.members.map((item) => item.projectKey), [
      '李杰||尚义',
      '李杰||鲜滩',
    ]);
    expect(created.members.map((item) => item.sortOrder), [0, 1]);

    final active = await service.getActiveMergeGroupsWithMembers();
    expect(active, hasLength(1));
    expect(active.single.group.id, created.group.id);
    expect(active.single.members.map((item) => item.site), ['尚义', '鲜滩']);
  });

  test('dissolves a group and hides it from active queries', () async {
    final created = await service.createMergeGroup(
      contact: '李杰',
      projectKeys: ['李杰||尚义', '李杰||鲜滩'],
    );

    await service.dissolveMergeGroup(created.group.id!);

    final active = await service.getActiveMergeGroupsWithMembers();
    expect(active, isEmpty);

    final group = await repository.getGroupById(created.group.id!);
    expect(group, isNotNull);
    expect(group!.isActive, isFalse);
    expect(group.dissolvedAt, '2026-05-15T01:02:03.000Z');

    final members = await repository.listMembersByGroupId(created.group.id!);
    expect(members, hasLength(2));
    expect(members.every((item) => !item.isActive), isTrue);
  });

  test('dissolves active group when member address changes', () async {
    final created = await service.createMergeGroup(
      contact: '李杰',
      projectKeys: ['李杰||尚义', '李杰||鲜滩'],
    );

    final dissolved = await service.dissolveMergeGroupIfProjectKeyChanged(
      oldProjectKey: '李杰||尚义',
      newProjectKey: '李杰||尚义远的家电公司也有很多长您好今天',
    );

    expect(dissolved, isTrue);
    expect(await service.getActiveMergeGroupsWithMembers(), isEmpty);

    final group = await repository.getGroupById(created.group.id!);
    expect(group, isNotNull);
    expect(group!.isActive, isFalse);

    final members = await repository.listMembersByGroupId(created.group.id!);
    expect(members, hasLength(2));
    expect(members.every((item) => !item.isActive), isTrue);
  });

  test('dissolves active group when member contact changes', () async {
    await service.createMergeGroup(
      contact: '李杰',
      projectKeys: ['李杰||尚义', '李杰||鲜滩'],
    );

    final dissolved = await service.dissolveMergeGroupIfProjectKeyChanged(
      oldProjectKey: '李杰||尚义',
      newProjectKey: '张三||尚义',
    );

    expect(dissolved, isTrue);
    expect(await service.getActiveMergeGroupsWithMembers(), isEmpty);
  });

  test(
    'keeps active group when hours date device or note edits keep project key',
    () async {
      final created = await service.createMergeGroup(
        contact: '李杰',
        projectKeys: ['李杰||尚义', '李杰||鲜滩'],
      );

      for (final editedField in ['工时', '日期', '设备', '备注']) {
        final dissolved = await service.dissolveMergeGroupIfProjectKeyChanged(
          oldProjectKey: '李杰||尚义',
          newProjectKey: '李杰||尚义',
        );
        expect(dissolved, isFalse, reason: editedField);
      }

      final active = await service.getActiveMergeGroupsWithMembers();
      expect(active, hasLength(1));
      expect(active.single.group.id, created.group.id);
      expect(active.single.group.isActive, isTrue);
    },
  );

  test(
    'does not dissolve when old project key is not an active member',
    () async {
      final created = await service.createMergeGroup(
        contact: '李杰',
        projectKeys: ['李杰||尚义', '李杰||鲜滩'],
      );

      final dissolved = await service.dissolveMergeGroupIfProjectKeyChanged(
        oldProjectKey: '李杰||高桥',
        newProjectKey: '李杰||高桥新址',
      );

      expect(dissolved, isFalse);

      final active = await service.getActiveMergeGroupsWithMembers();
      expect(active, hasLength(1));
      expect(active.single.group.id, created.group.id);
    },
  );

  test('rejects fewer than two members', () async {
    expect(
      () => service.createMergeGroup(contact: '李杰', projectKeys: ['李杰||尚义']),
      throwsArgumentError,
    );
  });

  test('rejects cross-contact members', () async {
    expect(
      () => service.createMergeGroup(
        contact: '李杰',
        projectKeys: ['李杰||尚义', '王涛||高桥'],
      ),
      throwsArgumentError,
    );
  });

  test('rejects project keys that do not match contact and site', () async {
    expect(
      () => service.createMergeGroup(
        contact: '李杰',
        projectKeys: ['李杰||尚义||多余', '李杰||鲜滩'],
      ),
      throwsArgumentError,
    );
  });

  test('prevents a project from joining two active groups', () async {
    await service.createMergeGroup(
      contact: '李杰',
      projectKeys: ['李杰||尚义', '李杰||鲜滩'],
    );

    expect(
      () => service.createMergeGroup(
        contact: '李杰',
        projectKeys: ['李杰||尚义', '李杰||高桥'],
      ),
      throwsStateError,
    );
  });

  test(
    'allows active projects to merge when project rows are active',
    () async {
      await _insertProject('李杰', '尚义', ProjectStatus.active);
      await _insertProject('李杰', '鲜滩', ProjectStatus.active);

      final created = await service.createMergeGroup(
        contact: '李杰',
        projectIds: [_projectId('李杰', '尚义'), _projectId('李杰', '鲜滩')],
        projectKeys: ['李杰||尚义', '李杰||鲜滩'],
      );

      expect(created.members.map((member) => member.projectId), [
        _projectId('李杰', '尚义'),
        _projectId('李杰', '鲜滩'),
      ]);
    },
  );

  test('rejects merging settled and active projects', () async {
    await _insertProject('李杰', '尚义', ProjectStatus.settled);
    await _insertProject('李杰', '鲜滩', ProjectStatus.active);

    expect(
      () => service.createMergeGroup(
        contact: '李杰',
        projectIds: [_projectId('李杰', '尚义'), _projectId('李杰', '鲜滩')],
        projectKeys: ['李杰||尚义', '李杰||鲜滩'],
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          settledProjectMergeBlockedMessage,
        ),
      ),
    );

    expect(await service.getActiveMergeGroupsWithMembers(), isEmpty);
  });

  test('rejects merging two settled projects', () async {
    await _insertProject('李杰', '尚义', ProjectStatus.settled);
    await _insertProject('李杰', '鲜滩', ProjectStatus.settled);

    expect(
      () => service.createMergeGroup(
        contact: '李杰',
        projectIds: [_projectId('李杰', '尚义'), _projectId('李杰', '鲜滩')],
        projectKeys: ['李杰||尚义', '李杰||鲜滩'],
      ),
      throwsA(isA<StateError>()),
    );

    expect(await service.getActiveMergeGroupsWithMembers(), isEmpty);
  });

  test(
    'rejecting settled projects preserves write-offs statuses timings and payments',
    () async {
      final settledId = _projectId('李杰', '尚义');
      final activeId = _projectId('李杰', '鲜滩');
      await _insertProject('李杰', '尚义', ProjectStatus.settled);
      await _insertProject('李杰', '鲜滩', ProjectStatus.active);
      await _insertWriteOff(settledId);
      await _insertTiming(settledId, contact: '李杰', site: '尚义');
      await _insertPayment(activeId, projectKey: '李杰||鲜滩');

      final beforeProjects = await _tableRows('projects');
      final beforeWriteOffs = await _tableRows('project_write_offs');
      final beforeTimings = await _tableRows('timing_records');
      final beforePayments = await _tableRows('account_payments');

      await expectLater(
        service.createMergeGroup(
          contact: '李杰',
          projectIds: [settledId, activeId],
          projectKeys: ['李杰||尚义', '李杰||鲜滩'],
        ),
        throwsStateError,
      );

      expect(await _tableRows('projects'), beforeProjects);
      expect(await _tableRows('project_write_offs'), beforeWriteOffs);
      expect(await _tableRows('timing_records'), beforeTimings);
      expect(await _tableRows('account_payments'), beforePayments);
    },
  );

  test('allows a dissolved project key to join a new active group', () async {
    final first = await service.createMergeGroup(
      contact: '李杰',
      projectKeys: ['李杰||尚义', '李杰||鲜滩'],
    );

    await service.dissolveMergeGroup(first.group.id!);

    final second = await service.createMergeGroup(
      contact: '李杰',
      projectKeys: ['李杰||尚义', '李杰||高桥'],
    );

    expect(second.group.id, isNot(first.group.id));
    final activeMembers = await repository.listActiveMembersByProjectKeys([
      '李杰||尚义',
    ]);
    expect(activeMembers, hasLength(1));
    expect(activeMembers.single.groupId, second.group.id);
  });
}

String _projectId(String contact, String site) {
  return ProjectId.legacyFromParts(contact: contact, site: site);
}

Future<void> _insertProject(
  String contact,
  String site,
  ProjectStatus status,
) async {
  final timestamp = DateTime.utc(2026, 5, 15).toIso8601String();
  await SqfliteProjectRepository().insert(
    Project(
      id: _projectId(contact, site),
      contact: contact,
      site: site,
      status: status,
      settledAt: status == ProjectStatus.settled ? timestamp : null,
      createdAt: timestamp,
      updatedAt: timestamp,
      legacyProjectKey: '$contact||$site',
    ),
  );
}

Future<void> _insertWriteOff(String projectId) async {
  final db = await AppDatabase.database;
  await db.insert('project_write_offs', {
    'id': 'writeoff-1',
    'project_id': projectId,
    'amount': 120,
    'amount_fen': 12000,
    'reason': 'settlement',
    'note': '结清',
    'write_off_date': '2026-05-15T00:00:00.000Z',
    'created_at': '2026-05-15T00:00:00.000Z',
    'updated_at': '2026-05-15T00:00:00.000Z',
  });
}

Future<void> _insertTiming(
  String projectId, {
  required String contact,
  required String site,
}) async {
  final db = await AppDatabase.database;
  await db.insert('timing_records', {
    'project_id': projectId,
    'device_id': 1,
    'start_date': 20260515,
    'contact': contact,
    'site': site,
    'type': 'hours',
    'start_meter': 0,
    'end_meter': 1,
    'hours': 1,
    'income': 100,
    'exclude_from_fuel_eff': 0,
    'is_breaking': 0,
  });
}

Future<void> _insertPayment(
  String projectId, {
  required String projectKey,
}) async {
  final db = await AppDatabase.database;
  await db.insert('account_payments', {
    'project_id': projectId,
    'project_key': projectKey,
    'ymd': 20260515,
    'amount': 50,
    'amount_fen': 5000,
    'note': '收款',
    'source_type': 'manual',
    'created_at': '2026-05-15T00:00:00.000Z',
  });
}

Future<List<Map<String, Object?>>> _tableRows(String table) async {
  final db = await AppDatabase.database;
  return db.query(table, orderBy: 'rowid ASC');
}
