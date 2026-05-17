import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/repositories/account_project_merge_repository.dart';
import 'package:asset_ledger/data/services/account_project_merge_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  late SqfliteAccountProjectMergeRepository repository;
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
    service = AccountProjectMergeService(
      repository: repository,
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
