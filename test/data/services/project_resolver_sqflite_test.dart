import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/db/db_migrations.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:asset_ledger/data/repositories/project_repository.dart';
import 'package:asset_ledger/data/services/project_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  setUp(() async {
    await AppDatabase.resetForTest();
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  group('ProjectResolver (sqflite) - legacy_project_key 唯一性规则', () {
    test('未结清同联系人同工地：resolveOrCreate 返回同一 active project_id', () async {
      final db = await _openCurrentInMemoryDb();
      final resolver = _resolver();

      final first = await resolver.resolveOrCreate(
        contact: '甲方',
        site: '一号工地',
      );
      final second = await resolver.resolveOrCreate(
        contact: '甲方',
        site: '一号工地',
      );

      expect(first.created, isTrue);
      expect(second.created, isFalse);
      expect(second.projectId, first.projectId);

      final rows = await db.query('projects');
      expect(rows, hasLength(1));
      expect(rows.single['status'], ProjectStatus.active.name);
    });

    test('已结清同联系人同工地：resolveOrCreate 创建新的 project_id', () async {
      final db = await _openCurrentInMemoryDb();
      final resolver = _resolver();

      final first = await resolver.resolveOrCreate(
        contact: '甲方',
        site: '同一工地',
      );
      // 结清旧项目。
      await db.update(
        'projects',
        {
          'status': ProjectStatus.settled.name,
          'settled_at': '2026-05-01T00:00:00.000Z',
        },
        where: 'id = ?',
        whereArgs: [first.projectId],
      );

      final second = await resolver.resolveOrCreate(
        contact: '甲方',
        site: '同一工地',
      );

      expect(second.created, isTrue);
      expect(second.projectId, isNot(first.projectId));

      final rows = await db.query(
        'projects',
        orderBy: 'created_at ASC, id ASC',
      );
      expect(rows, hasLength(2));
      // 两条项目共享同一 legacy_project_key，一条 settled、一条 active。
      final keys = rows.map((r) => r['legacy_project_key']).toSet();
      expect(keys, hasLength(1));
      final statuses = rows.map((r) => r['status']).toList();
      expect(statuses, containsAll([
        ProjectStatus.settled.name,
        ProjectStatus.active.name,
      ]));
    });

    test('两个 settled 项目允许拥有相同 legacy_project_key', () async {
      final db = await _openCurrentInMemoryDb();
      const legacyKey = '甲方||一号工地';

      // 直接插入两个 settled 项目，共享同一 legacy_project_key。
      await db.insert('projects', {
        'id': 'project:settled-1',
        'contact': '甲方',
        'site': '一号工地',
        'status': ProjectStatus.settled.name,
        'settled_at': '2026-04-01T00:00:00.000Z',
        'created_at': '2026-03-01T00:00:00.000Z',
        'updated_at': '2026-04-01T00:00:00.000Z',
        'legacy_project_key': legacyKey,
      });
      await db.insert('projects', {
        'id': 'project:settled-2',
        'contact': '甲方',
        'site': '一号工地',
        'status': ProjectStatus.settled.name,
        'settled_at': '2026-05-01T00:00:00.000Z',
        'created_at': '2026-04-15T00:00:00.000Z',
        'updated_at': '2026-05-01T00:00:00.000Z',
        'legacy_project_key': legacyKey,
      });

      final rows = await db.query('projects');
      expect(rows, hasLength(2));
    });

    test('不允许两个 active 项目拥有相同 legacy_project_key', () async {
      final db = await _openCurrentInMemoryDb();
      const legacyKey = '甲方||一号工地';

      await db.insert('projects', {
        'id': 'project:active-1',
        'contact': '甲方',
        'site': '一号工地',
        'status': ProjectStatus.active.name,
        'created_at': '2026-05-01T00:00:00.000Z',
        'updated_at': '2026-05-01T00:00:00.000Z',
        'legacy_project_key': legacyKey,
      });

      // 直接插入第二个 active（同 key）应失败，partial unique index 阻止。
      await expectLater(
        db.insert('projects', {
          'id': 'project:active-2',
          'contact': '甲方',
          'site': '一号工地',
          'status': ProjectStatus.active.name,
          'created_at': '2026-05-02T00:00:00.000Z',
          'updated_at': '2026-05-02T00:00:00.000Z',
          'legacy_project_key': legacyKey,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('settled 与 active 可共存于同一 legacy_project_key', () async {
      final db = await _openCurrentInMemoryDb();
      const legacyKey = '甲方||一号工地';

      await db.insert('projects', {
        'id': 'project:settled',
        'contact': '甲方',
        'site': '一号工地',
        'status': ProjectStatus.settled.name,
        'settled_at': '2026-04-01T00:00:00.000Z',
        'created_at': '2026-03-01T00:00:00.000Z',
        'updated_at': '2026-04-01T00:00:00.000Z',
        'legacy_project_key': legacyKey,
      });
      await db.insert('projects', {
        'id': 'project:active',
        'contact': '甲方',
        'site': '一号工地',
        'status': ProjectStatus.active.name,
        'created_at': '2026-05-01T00:00:00.000Z',
        'updated_at': '2026-05-01T00:00:00.000Z',
        'legacy_project_key': legacyKey,
      });
      final rows = await db.query('projects');
      expect(rows, hasLength(2));
    });

    test('结清后再次开工，真实 sqflite repository 完整流程贯通', () async {
      final db = await _openCurrentInMemoryDb();
      final resolver = _resolver();

      // 1) 第一次开工：创建 active 项目。
      final first = await resolver.resolveOrCreate(
        contact: '甲方',
        site: '工地 A',
      );
      expect(first.created, isTrue);

      // 2) 老板结清该项目。
      await db.update(
        'projects',
        {
          'status': ProjectStatus.settled.name,
          'settled_at': '2026-05-15T00:00:00.000Z',
        },
        where: 'id = ?',
        whereArgs: [first.projectId],
      );

      // 3) 同联系人同工地再次开工：必须创建新的 project_id。
      final second = await resolver.resolveOrCreate(
        contact: '甲方',
        site: '工地 A',
      );
      expect(second.created, isTrue);
      expect(second.projectId, isNot(first.projectId));

      // 4) 第三次开工应复用第二个 active 项目。
      final third = await resolver.resolveOrCreate(
        contact: '甲方',
        site: '工地 A',
      );
      expect(third.created, isFalse);
      expect(third.projectId, second.projectId);

      final activeRows = await db.query(
        'projects',
        where: 'status = ?',
        whereArgs: [ProjectStatus.active.name],
      );
      expect(activeRows, hasLength(1));
      expect(activeRows.single['id'], second.projectId);
    });
  });

  group('legacy_project_key partial unique index 迁移路径', () {
    test('新库建表：projects 没有全局 UNIQUE 列约束，仅有 active partial unique index',
        () async {
      final db = await _openCurrentInMemoryDb();

      final tableInfo = await db.rawQuery(
        "SELECT sql FROM sqlite_master WHERE type='table' AND name='projects';",
      );
      final tableSql = (tableInfo.single['sql'] as String).toUpperCase();
      // legacy_project_key 列定义部分必须不含 UNIQUE。
      final legacyKeyLine = RegExp(r'LEGACY_PROJECT_KEY[^,)\n]*')
          .firstMatch(tableSql)!
          .group(0)!;
      expect(legacyKeyLine.contains('UNIQUE'), isFalse,
          reason: 'legacy_project_key 列不应再有 UNIQUE 约束: $legacyKeyLine');

      // 必须存在 partial unique index。
      final indexInfo = await db.rawQuery(
        "SELECT name, sql FROM sqlite_master WHERE type='index' "
        "AND tbl_name='projects' AND name='idx_projects_active_legacy_key';",
      );
      expect(indexInfo, hasLength(1));
      final indexSql = (indexInfo.single['sql'] as String).toUpperCase();
      expect(indexSql, contains('UNIQUE'));
      expect(indexSql, contains("STATUS = 'ACTIVE'"));
    });

    test('旧库升级：v20 schema（带 legacy_project_key UNIQUE）升级后应失去 UNIQUE 并具备 partial unique',
        () async {
      // 模拟旧 DB：legacy_project_key TEXT UNIQUE。
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: 20,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE projects (
              id TEXT PRIMARY KEY,
              contact TEXT NOT NULL,
              site TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'active',
              settled_at TEXT,
              settled_snapshot TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              legacy_project_key TEXT UNIQUE
            );
          ''');
        },
      );

      // 写入一条 settled 数据 —— 升级后该数据应继续存在。
      await db.insert('projects', {
        'id': 'project:legacy-settled',
        'contact': '甲方',
        'site': '一号工地',
        'status': ProjectStatus.settled.name,
        'settled_at': '2026-04-01T00:00:00.000Z',
        'created_at': '2026-03-01T00:00:00.000Z',
        'updated_at': '2026-04-01T00:00:00.000Z',
        'legacy_project_key': '甲方||一号工地',
      });

      // 应用 v21 迁移。
      await DbMigrations.ensureActiveScopedLegacyProjectKeyUniqueness(db);

      // UNIQUE 已被移除。
      final tableInfo = await db.rawQuery(
        "SELECT sql FROM sqlite_master WHERE type='table' AND name='projects';",
      );
      final tableSql = (tableInfo.single['sql'] as String).toUpperCase();
      final legacyKeyLine = RegExp(r'LEGACY_PROJECT_KEY[^,)\n]*')
          .firstMatch(tableSql)!
          .group(0)!;
      expect(legacyKeyLine.contains('UNIQUE'), isFalse);

      // partial unique index 已建立。
      final indexInfo = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' "
        "AND tbl_name='projects' AND name='idx_projects_active_legacy_key';",
      );
      expect(indexInfo, hasLength(1));

      // 旧数据保留。
      final rows = await db.query('projects');
      expect(rows, hasLength(1));
      expect(rows.single['id'], 'project:legacy-settled');

      // 升级后允许：在已有 settled 的相同 key 下新增一个 active。
      await db.insert('projects', {
        'id': 'project:new-active',
        'contact': '甲方',
        'site': '一号工地',
        'status': ProjectStatus.active.name,
        'created_at': '2026-05-15T00:00:00.000Z',
        'updated_at': '2026-05-15T00:00:00.000Z',
        'legacy_project_key': '甲方||一号工地',
      });

      // 但第二个 active 仍被 partial unique 阻止。
      await expectLater(
        db.insert('projects', {
          'id': 'project:duplicate-active',
          'contact': '甲方',
          'site': '一号工地',
          'status': ProjectStatus.active.name,
          'created_at': '2026-05-16T00:00:00.000Z',
          'updated_at': '2026-05-16T00:00:00.000Z',
          'legacy_project_key': '甲方||一号工地',
        }),
        throwsA(isA<DatabaseException>()),
      );

      await db.close();
    });
  });
}

Future<Database> _openCurrentInMemoryDb() {
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
  return AppDatabase.database;
}

ProjectResolver _resolver() {
  return ProjectResolver(
    projectRepository: SqfliteProjectRepository(),
    now: () => DateTime.utc(2026, 5, 26),
  );
}
