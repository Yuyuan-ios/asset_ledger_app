import 'dart:io';

import 'package:asset_ledger/data/db/db_migrations.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../test_setup.dart';

/// 真实 sqflite onUpgrade / onOpen 链路测试：从 v20 + 子表 FK 数据升级到 v21
/// 不能因为 onUpgrade 事务里 DROP projects 而触发
/// FOREIGN KEY constraint failed。
///
/// Migration021.apply 必须是 onUpgrade 事务内安全的 no-op；真正的列级 UNIQUE
/// 移除 + partial unique index 建立由 DbSchemaCompat.ensure（onOpen）执行——
/// 那里没有 sqflite 事务，PRAGMA foreign_keys = OFF 才会生效。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  late Directory tmpDir;
  late String dbPath;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp(
      'asset_ledger_migration_021_',
    );
    dbPath = p.join(tmpDir.path, 'asset_ledger.db');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test(
    'v20 + 真实子表 FK 数据 → v21 完整 onUpgrade/onOpen 链路：'
    '不抛 FOREIGN KEY constraint failed，数据保留，UNIQUE 拆除，partial unique 就位',
    () async {
      // ---- 1) 模拟旧 v20 库：projects 带列级 UNIQUE，并写入子表 FK 数据 ----
      final v20 = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
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
            // 让 projects 真的被子表 FK 引用（验证 onUpgrade 事务内不能 DROP）。
            await db.execute('''
              CREATE TABLE timing_records (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                project_id TEXT NOT NULL,
                FOREIGN KEY (project_id)
                  REFERENCES projects(id) ON DELETE RESTRICT
              );
            ''');
            await db.execute('''
              CREATE TABLE external_import_batches (
                id TEXT PRIMARY KEY,
                source_share_id TEXT NOT NULL DEFAULT '',
                source_display_name TEXT NOT NULL DEFAULT '',
                record_count INTEGER NOT NULL DEFAULT 0,
                total_hours_milli INTEGER NOT NULL DEFAULT 0,
                total_amount_fen INTEGER NOT NULL DEFAULT 0,
                site_summary TEXT NOT NULL DEFAULT '',
                imported_at TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'active',
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
              );
            ''');
            await db.execute('''
              CREATE TABLE external_work_records (
                id TEXT PRIMARY KEY,
                import_batch_id TEXT NOT NULL,
                source_share_id TEXT NOT NULL DEFAULT '',
                source_record_uuid TEXT NOT NULL DEFAULT '',
                source_installation_uuid TEXT NOT NULL DEFAULT '',
                origin_fingerprint TEXT NOT NULL DEFAULT '',
                collaborator_name TEXT NOT NULL DEFAULT '',
                contact_snapshot TEXT NOT NULL DEFAULT '',
                site_snapshot TEXT NOT NULL DEFAULT '',
                work_date INTEGER NOT NULL DEFAULT 0,
                hours_milli INTEGER NOT NULL DEFAULT 0,
                amount_fen INTEGER NOT NULL DEFAULT 0,
                linked_project_id TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY (linked_project_id)
                  REFERENCES projects(id) ON DELETE RESTRICT,
                FOREIGN KEY (import_batch_id)
                  REFERENCES external_import_batches(id) ON DELETE RESTRICT
              );
            ''');
          },
        ),
      );
      try {
        // 旧数据：一个 active 项目，子表两条 FK 数据。
        await v20.insert('projects', {
          'id': 'project:p1',
          'contact': '甲方',
          'site': '一号工地',
          'status': ProjectStatus.active.name,
          'created_at': '2026-04-01T00:00:00.000Z',
          'updated_at': '2026-04-01T00:00:00.000Z',
          'legacy_project_key': '甲方||一号工地',
        });
        // 另一个 settled 项目（不同 key）用于验证升级后行存活。
        await v20.insert('projects', {
          'id': 'project:p2',
          'contact': '乙方',
          'site': '二号工地',
          'status': ProjectStatus.settled.name,
          'settled_at': '2026-03-01T00:00:00.000Z',
          'created_at': '2026-02-01T00:00:00.000Z',
          'updated_at': '2026-03-01T00:00:00.000Z',
          'legacy_project_key': '乙方||二号工地',
        });
        await v20.insert('timing_records', {'project_id': 'project:p1'});
        await v20.insert('timing_records', {'project_id': 'project:p2'});
        await v20.insert('external_import_batches', {
          'id': 'batch-1',
          'imported_at': '2026-04-02T00:00:00.000Z',
          'created_at': '2026-04-02T00:00:00.000Z',
          'updated_at': '2026-04-02T00:00:00.000Z',
        });
        await v20.insert('external_work_records', {
          'id': 'rec-1',
          'import_batch_id': 'batch-1',
          'linked_project_id': 'project:p1',
          'created_at': '2026-04-02T00:00:00.000Z',
          'updated_at': '2026-04-02T00:00:00.000Z',
        });
      } finally {
        await v20.close();
      }

      // ---- 2) 真实 v20 → v21 升级链路：onConfigure → onUpgrade → onOpen ----
      // 这里复用项目自己的 MigrationRunner / DbSchemaCompat，不要走 AppDatabase
      // 单例（测试要直接控制 file path / version）。
      late final Database v21;
      try {
        v21 = await databaseFactoryFfi.openDatabase(
          dbPath,
          options: OpenDatabaseOptions(
            version: 21,
            onConfigure: (db) async {
              await db.execute('PRAGMA foreign_keys = ON');
            },
            onUpgrade: (db, oldV, newV) async {
              // 这里就是真实生产路径会进入的事务区间。
              await DbMigrations.apply(db, oldV, newV);
            },
            onOpen: (db) async {
              // 这里只调用本次修复所关心的 v21 兜底；DbSchemaCompat.ensure 在生产里
              // 会顺次跑完所有 v* ensure，但其他 ensure 需要的旧表（account_payments
              // 等）超出本测试的最小 v20 fixture 范围。
              // 关键不变量：本 ensure 在 onOpen 路径执行，即 sqflite 事务之外，
              // 因此 PRAGMA foreign_keys = OFF 可以生效；这正是修复点。
              await DbMigrations
                  .ensureActiveScopedLegacyProjectKeyUniqueness(db);
            },
          ),
        );
      } catch (e, st) {
        fail('v20 → v21 升级不应抛出 FK 错误: $e\n$st');
      }

      try {
        // ---- 3) 业务数据保留 ----
        final projectRows = await v21.query(
          'projects',
          orderBy: 'id ASC',
        );
        expect(projectRows.map((r) => r['id']).toList(), [
          'project:p1',
          'project:p2',
        ]);

        // 子表 FK 行也保留。
        final timingRows = await v21.query(
          'timing_records',
          orderBy: 'id ASC',
        );
        expect(timingRows, hasLength(2));

        final extBatches = await v21.query('external_import_batches');
        expect(extBatches, hasLength(1));

        final extRecords = await v21.query('external_work_records');
        expect(extRecords, hasLength(1));
        expect(extRecords.single['linked_project_id'], 'project:p1');

        // ---- 4) projects 表已无列级 UNIQUE ----
        final tableSqlRow = await v21.rawQuery(
          "SELECT sql FROM sqlite_master WHERE type='table' AND name='projects';",
        );
        final tableSql = (tableSqlRow.single['sql'] as String).toUpperCase();
        final legacyKeyClause = RegExp(r'LEGACY_PROJECT_KEY[^,)\n]*')
            .firstMatch(tableSql)!
            .group(0)!;
        expect(legacyKeyClause.contains('UNIQUE'), isFalse,
            reason:
                '升级后 legacy_project_key 列不应再有 UNIQUE: $legacyKeyClause');

        // ---- 5) partial unique index 建立 ----
        final idxInfo = await v21.rawQuery(
          "SELECT name, sql FROM sqlite_master WHERE type='index' "
          "AND tbl_name='projects' AND name='idx_projects_active_legacy_key';",
        );
        expect(idxInfo, hasLength(1));
        final idxSql = (idxInfo.single['sql'] as String).toUpperCase();
        expect(idxSql, contains('UNIQUE'));
        expect(idxSql, contains("STATUS = 'ACTIVE'"));

        // ---- 6) FK 校验通过 ----
        final fkIssues = await v21.rawQuery('PRAGMA foreign_key_check;');
        expect(fkIssues, isEmpty);
      } finally {
        await v21.close();
      }
    },
  );

  test(
    '升级后再次打开数据库：ensureActiveScopedLegacyProjectKeyUniqueness 幂等，不抛错',
    () async {
      // 制造一个 v20 + UNIQUE + 子表 FK 的库，升级一次再打开第二次。
      final v20 = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
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
            await db.execute('''
              CREATE TABLE timing_records (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                project_id TEXT NOT NULL,
                FOREIGN KEY (project_id)
                  REFERENCES projects(id) ON DELETE RESTRICT
              );
            ''');
          },
        ),
      );
      await v20.insert('projects', {
        'id': 'project:p1',
        'contact': '甲方',
        'site': '一号工地',
        'status': ProjectStatus.active.name,
        'created_at': '2026-04-01T00:00:00.000Z',
        'updated_at': '2026-04-01T00:00:00.000Z',
        'legacy_project_key': '甲方||一号工地',
      });
      await v20.insert('timing_records', {'project_id': 'project:p1'});
      await v20.close();

      // 第一次升级。
      final firstOpen = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 21,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
          onUpgrade: (db, oldV, newV) async {
            await DbMigrations.apply(db, oldV, newV);
          },
          onOpen: (db) async {
            await DbMigrations.ensureActiveScopedLegacyProjectKeyUniqueness(db);
          },
        ),
      );
      await firstOpen.close();

      // 第二次打开：只走 onOpen，不会走 onUpgrade（version 已经是 21）。
      // ensureActiveScopedLegacyProjectKeyUniqueness 应该幂等：什么都不应失败。
      final secondOpen = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 21,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
          onUpgrade: (db, oldV, newV) async {
            await DbMigrations.apply(db, oldV, newV);
          },
          onOpen: (db) async {
            await DbMigrations.ensureActiveScopedLegacyProjectKeyUniqueness(db);
          },
        ),
      );
      try {
        // 仍然可读、数据保留、FK 健康。
        final rows = await secondOpen.query('projects');
        expect(rows.map((r) => r['id']).toList(), ['project:p1']);
        final fkIssues = await secondOpen.rawQuery('PRAGMA foreign_key_check;');
        expect(fkIssues, isEmpty);

        // 直接再次手动调用 ensure 也不抛错（幂等）。
        await DbMigrations.ensureActiveScopedLegacyProjectKeyUniqueness(
          secondOpen,
        );
        await DbMigrations.ensureActiveScopedLegacyProjectKeyUniqueness(
          secondOpen,
        );
      } finally {
        await secondOpen.close();
      }
    },
  );

  test(
    '升级后业务规则：两 settled 同 key OK / settled+active 同 key OK / 两 active 同 key 阻断',
    () async {
      // 准备一个 v20 库（带 UNIQUE，仅一行）然后升级。
      final v20 = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
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
            await db.execute('''
              CREATE TABLE timing_records (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                project_id TEXT NOT NULL,
                FOREIGN KEY (project_id)
                  REFERENCES projects(id) ON DELETE RESTRICT
              );
            ''');
          },
        ),
      );
      await v20.insert('projects', {
        'id': 'project:settled-1',
        'contact': '甲方',
        'site': '一号工地',
        'status': ProjectStatus.settled.name,
        'settled_at': '2026-03-01T00:00:00.000Z',
        'created_at': '2026-02-01T00:00:00.000Z',
        'updated_at': '2026-03-01T00:00:00.000Z',
        'legacy_project_key': '甲方||一号工地',
      });
      await v20.insert('timing_records', {'project_id': 'project:settled-1'});
      await v20.close();

      final v21 = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 21,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
          onUpgrade: (db, oldV, newV) async {
            await DbMigrations.apply(db, oldV, newV);
          },
          onOpen: (db) async {
            await DbMigrations.ensureActiveScopedLegacyProjectKeyUniqueness(db);
          },
        ),
      );
      try {
        // 两个 settled 共享同一 legacy_project_key —— OK。
        await v21.insert('projects', {
          'id': 'project:settled-2',
          'contact': '甲方',
          'site': '一号工地',
          'status': ProjectStatus.settled.name,
          'settled_at': '2026-04-01T00:00:00.000Z',
          'created_at': '2026-03-15T00:00:00.000Z',
          'updated_at': '2026-04-01T00:00:00.000Z',
          'legacy_project_key': '甲方||一号工地',
        });

        // settled + active 共享同一 legacy_project_key —— OK。
        await v21.insert('projects', {
          'id': 'project:active-1',
          'contact': '甲方',
          'site': '一号工地',
          'status': ProjectStatus.active.name,
          'created_at': '2026-05-01T00:00:00.000Z',
          'updated_at': '2026-05-01T00:00:00.000Z',
          'legacy_project_key': '甲方||一号工地',
        });

        // 再插一个 active 同 key —— 被 partial unique index 阻断。
        await expectLater(
          v21.insert('projects', {
            'id': 'project:active-dup',
            'contact': '甲方',
            'site': '一号工地',
            'status': ProjectStatus.active.name,
            'created_at': '2026-05-02T00:00:00.000Z',
            'updated_at': '2026-05-02T00:00:00.000Z',
            'legacy_project_key': '甲方||一号工地',
          }),
          throwsA(isA<DatabaseException>()),
        );
      } finally {
        await v21.close();
      }
    },
  );
}
