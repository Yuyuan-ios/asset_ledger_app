import 'package:asset_ledger/data/db/db_migrations.dart';
import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/db/db_schema_compat.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  group('Db migrations', () {
    test(
      'upgrades a v3 database to v13 and creates project identity with safe defaults',
      () async {
        final path = await _testDbPath('v3_to_v9');
        await deleteDatabase(path);

        final legacyDb = await openDatabase(
          path,
          version: 3,
          onCreate: (db, _) async {
            await _createV3Schema(db);
            await _seedV3Data(db);
          },
        );
        await legacyDb.close();

        final db = await _openCurrentDb(path);

        final deviceRow = (await db.query('devices', where: 'id = 1')).single;
        expect(deviceRow['name'], 'Legacy SANY 1#');
        expect(deviceRow.containsKey('default_unit_price'), isFalse);
        expect(deviceRow.containsKey('breaking_unit_price'), isFalse);
        expect(deviceRow['default_unit_price_fen'], 38000);
        expect(deviceRow['breaking_unit_price_fen'], isNull);
        expect(deviceRow['equipment_type'], 'excavator');

        final timingRow = (await db.query(
          'timing_records',
          where: 'id = 1',
        )).single;
        expect(timingRow['contact'], '张三');
        expect(timingRow['project_id'], isA<String>());
        expect((timingRow['project_id'] as String).isNotEmpty, isTrue);
        expect(timingRow['exclude_from_fuel_eff'], 0);
        expect(timingRow['is_breaking'], 0);

        final projects = await db.query('projects');
        expect(projects, hasLength(1));
        expect(projects.single['contact'], '张三');
        expect(projects.single['site'], '一号工地');
        expect(projects.single['status'], 'active');
        expect(projects.single['id'], timingRow['project_id']);
        expect(
          await _projectForeignKeyTables(db),
          containsAll([
            'timing_records',
            'account_payments',
            'project_device_rates',
            'account_project_merge_members',
            'project_write_offs',
          ]),
        );
        expect(await db.rawQuery('PRAGMA foreign_key_check;'), isEmpty);

        expect(await _tableExists(db, 'maintenance_records'), isTrue);
        expect(await _tableExists(db, 'account_payments'), isTrue);
        expect(
          await _columnNames(db, 'account_payments'),
          containsAll([
            'source_type',
            'merge_group_id',
            'merge_batch_id',
            'amount_fen',
            'merge_batch_total_amount_fen',
            'merge_batch_note',
            'created_at',
          ]),
        );
        expect(
          await _columnNames(db, 'account_payments'),
          isNot(contains('amount')),
        );
        expect(
          await _columnNames(db, 'account_payments'),
          isNot(contains('merge_batch_total_amount')),
        );
        expect(await _tableExists(db, 'project_device_rates'), isTrue);
        expect(await _tableExists(db, 'timing_calculation_history'), isTrue);
        expect(await _tableExists(db, 'account_project_merge_groups'), isTrue);
        expect(await _tableExists(db, 'account_project_merge_members'), isTrue);
        expect(await _tableExists(db, 'project_write_offs'), isTrue);
        expect(await _indexExists(db, 'idx_timing_calc_record_id'), isTrue);
        expect(
          await _indexExists(db, 'idx_project_write_offs_project_id'),
          isTrue,
        );
        expect(
          await _indexExists(db, 'idx_project_write_offs_write_off_date'),
          isTrue,
        );
        expect(
          await _indexExists(
            db,
            'idx_account_project_merge_groups_active_contact',
          ),
          isTrue,
        );
        expect(
          await _indexExists(
            db,
            'idx_account_project_merge_members_active_project',
          ),
          isTrue,
        );

        expect(await _primaryKeyColumns(db, 'project_device_rates'), [
          'project_id',
          'device_id',
          'is_breaking',
        ]);

        await db.close();
        await deleteDatabase(path);
      },
    );

    test(
      'upgrades a v7 database by rebuilding project rate primary keys',
      () async {
        final path = await _testDbPath('v7_to_v9');
        await deleteDatabase(path);

        final legacyDb = await openDatabase(
          path,
          version: 7,
          onCreate: (db, _) async {
            await _createV7Schema(db);
            await _seedV7Data(db);
          },
        );
        await legacyDb.close();

        final db = await _openCurrentDb(path);

        final rows = await db.query(
          'project_device_rates',
          orderBy: 'project_key ASC, device_id ASC, is_breaking ASC',
        );
        expect(rows, hasLength(2));
        final rowByKey = {
          for (final row in rows) row['project_key'] as String: row,
        };
        final secondSiteRate = rowByKey['李四||二号工地']!;
        final thirdSiteRate = rowByKey['李四||三号工地']!;
        expect(secondSiteRate['project_id'], isA<String>());
        expect((secondSiteRate['project_id'] as String).isNotEmpty, isTrue);
        expect(secondSiteRate['device_id'], 1);
        expect(secondSiteRate['is_breaking'], 0);
        expect(secondSiteRate.containsKey('rate'), isFalse);
        expect(secondSiteRate['rate_fen'], 51000);
        expect(thirdSiteRate['project_id'], isA<String>());
        expect((thirdSiteRate['project_id'] as String).isNotEmpty, isTrue);
        expect(thirdSiteRate['device_id'], 2);
        expect(thirdSiteRate['is_breaking'], 0);
        expect(thirdSiteRate.containsKey('rate'), isFalse);
        expect(thirdSiteRate['rate_fen'], 61000);
        expect(await _primaryKeyColumns(db, 'project_device_rates'), [
          'project_id',
          'device_id',
          'is_breaking',
        ]);
        expect(await _tableExists(db, 'timing_calculation_history'), isTrue);

        final projects = await db.query('projects');
        expect(projects, hasLength(2));
        expect(projects.map((row) => row['site']).toSet(), {'二号工地', '三号工地'});

        final paymentRow = (await db.query(
          'account_payments',
          where: 'id = ?',
          whereArgs: [1],
        )).single;
        expect(paymentRow['project_id'], secondSiteRate['project_id']);
        expect(paymentRow['source_type'], 'manual');
        expect(paymentRow['merge_group_id'], isNull);
        expect(paymentRow['merge_batch_id'], isNull);
        expect(paymentRow.containsKey('amount'), isFalse);
        expect(paymentRow.containsKey('merge_batch_total_amount'), isFalse);
        expect(paymentRow['amount_fen'], 50000);
        expect(paymentRow['merge_batch_total_amount_fen'], isNull);
        expect(paymentRow['merge_batch_note'], isNull);
        expect(paymentRow['created_at'], isNull);

        await db.close();
        await deleteDatabase(path);
      },
    );

    test('repairs drifted latest-version schemas on open', () async {
      final path = await _testDbPath('compat_fix');
      await deleteDatabase(path);

      final brokenDb = await openDatabase(
        path,
        version: 9,
        onCreate: (db, _) async {
          await _createDriftedV9Schema(db);
          await _seedDriftedV9Data(db);
        },
      );
      await brokenDb.close();

      final db = await _openCurrentDb(path);

      expect(
        await _columnNames(db, 'devices'),
        allOf(
          containsAll(['default_unit_price_fen', 'equipment_type']),
          isNot(contains('default_unit_price')),
          isNot(contains('breaking_unit_price')),
        ),
      );
      expect(await _primaryKeyColumns(db, 'project_device_rates'), [
        'project_id',
        'device_id',
        'is_breaking',
      ]);
      expect(await _tableExists(db, 'timing_calculation_history'), isTrue);
      expect(await _tableExists(db, 'account_project_merge_groups'), isTrue);
      expect(await _tableExists(db, 'account_project_merge_members'), isTrue);
      expect(
        await _columnNames(db, 'account_payments'),
        containsAll([
          'source_type',
          'merge_group_id',
          'merge_batch_id',
          'amount_fen',
          'merge_batch_total_amount_fen',
          'merge_batch_note',
          'created_at',
        ]),
      );
      expect(
        await _columnNames(db, 'account_payments'),
        isNot(contains('amount')),
      );
      expect(
        await _columnNames(db, 'account_payments'),
        isNot(contains('merge_batch_total_amount')),
      );

      final repairedDevice = (await db.query(
        'devices',
        where: 'id = 1',
      )).single;
      expect(repairedDevice['equipment_type'], 'excavator');
      expect(repairedDevice.containsKey('default_unit_price'), isFalse);
      expect(repairedDevice.containsKey('breaking_unit_price'), isFalse);
      expect(repairedDevice['default_unit_price_fen'], 50000);
      expect(repairedDevice['breaking_unit_price_fen'], isNull);

      final repairedRate = (await db.query('project_device_rates')).single;
      final repairedProject = (await db.query('projects')).single;
      expect(repairedRate['project_id'], repairedProject['id']);
      expect(repairedRate['project_key'], '王五||老工地');
      expect(repairedRate['device_id'], 7);
      expect(repairedRate['is_breaking'], 0);
      expect(repairedRate.containsKey('rate'), isFalse);
      expect(repairedRate['rate_fen'], 69900);
      expect(await _primaryKeyColumns(db, 'project_device_rates'), [
        'project_id',
        'device_id',
        'is_breaking',
      ]);
      expect(await db.rawQuery('PRAGMA foreign_key_check;'), isEmpty);

      await db.close();
      await deleteDatabase(path);
    });

    test(
      'project_id foreign keys reject orphan timing rows and restrict delete',
      () async {
        final path = await _testDbPath('project_fk');
        await deleteDatabase(path);

        final db = await _openCurrentDb(path);
        final project = Project(
          id: 'project:fk',
          contact: '甲方',
          site: '一号工地',
          createdAt: '2026-05-17T00:00:00.000Z',
          updatedAt: '2026-05-17T00:00:00.000Z',
        );
        await db.insert('projects', project.toMap());

        await expectLater(
          db.insert('timing_records', {
            'project_id': 'project:missing',
            'device_id': 1,
            'start_date': 20260517,
            'contact': '甲方',
            'site': '一号工地',
            'type': 'hours',
            'start_meter': 0.0,
            'end_meter': 1.0,
            'hours': 1.0,
            'income_fen': 38000,
            'unit': 'HOUR',
            'exclude_from_fuel_eff': 0,
            'is_breaking': 0,
          }),
          throwsA(isA<DatabaseException>()),
        );

        await db.insert('timing_records', {
          'project_id': project.id,
          'device_id': 1,
          'start_date': 20260517,
          'contact': '甲方',
          'site': '一号工地',
          'type': 'hours',
          'start_meter': 0.0,
          'end_meter': 1.0,
          'hours': 1.0,
          'income_fen': 38000,
          'unit': 'HOUR',
          'exclude_from_fuel_eff': 0,
          'is_breaking': 0,
        });

        await expectLater(
          db.delete('projects', where: 'id = ?', whereArgs: [project.id]),
          throwsA(isA<DatabaseException>()),
        );
        expect(await db.rawQuery('PRAGMA foreign_key_check;'), isEmpty);

        await db.close();
        await deleteDatabase(path);
      },
    );

    test('account_payments project_id foreign key rejects orphans and '
        'restricts delete', () async {
      final path = await _testDbPath('account_payments_fk');
      await deleteDatabase(path);

      final db = await _openCurrentDb(path);
      final project = Project(
        id: 'project:fk',
        contact: '甲方',
        site: '一号工地',
        createdAt: '2026-05-17T00:00:00.000Z',
        updatedAt: '2026-05-17T00:00:00.000Z',
      );
      await db.insert('projects', project.toMap());

      await expectLater(
        db.insert('account_payments', {
          'project_id': 'project:missing',
          'project_key': '甲方||一号工地',
          'ymd': 20260517,
          'amount_fen': 10000,
        }),
        throwsA(isA<DatabaseException>()),
      );

      await db.insert('account_payments', {
        'project_id': project.id,
        'project_key': '甲方||一号工地',
        'ymd': 20260517,
        'amount_fen': 10000,
      });

      await expectLater(
        db.delete('projects', where: 'id = ?', whereArgs: [project.id]),
        throwsA(isA<DatabaseException>()),
      );
      expect(await db.rawQuery('PRAGMA foreign_key_check;'), isEmpty);

      await db.close();
      await deleteDatabase(path);
    });

    test('project_device_rates project_id foreign key rejects orphans and '
        'restricts delete', () async {
      final path = await _testDbPath('project_device_rates_fk');
      await deleteDatabase(path);

      final db = await _openCurrentDb(path);
      final project = Project(
        id: 'project:fk',
        contact: '甲方',
        site: '一号工地',
        createdAt: '2026-05-17T00:00:00.000Z',
        updatedAt: '2026-05-17T00:00:00.000Z',
      );
      await db.insert('projects', project.toMap());

      await expectLater(
        db.insert('project_device_rates', {
          'project_id': 'project:missing',
          'project_key': '甲方||一号工地',
          'device_id': 1,
          'is_breaking': 0,
          'rate_fen': 38000,
        }),
        throwsA(isA<DatabaseException>()),
      );

      await db.insert('project_device_rates', {
        'project_id': project.id,
        'project_key': '甲方||一号工地',
        'device_id': 1,
        'is_breaking': 0,
        'rate_fen': 38000,
      });

      await expectLater(
        db.delete('projects', where: 'id = ?', whereArgs: [project.id]),
        throwsA(isA<DatabaseException>()),
      );
      expect(await db.rawQuery('PRAGMA foreign_key_check;'), isEmpty);

      await db.close();
      await deleteDatabase(path);
    });

    test('account_project_merge_members project_id foreign key rejects '
        'orphans and restricts delete', () async {
      final path = await _testDbPath('merge_members_fk');
      await deleteDatabase(path);

      final db = await _openCurrentDb(path);
      final project = Project(
        id: 'project:fk',
        contact: '甲方',
        site: '一号工地',
        createdAt: '2026-05-17T00:00:00.000Z',
        updatedAt: '2026-05-17T00:00:00.000Z',
      );
      await db.insert('projects', project.toMap());
      final groupId = await db.insert('account_project_merge_groups', {
        'contact': '甲方',
        'created_at': '2026-05-17T00:00:00.000Z',
      });

      await expectLater(
        db.insert('account_project_merge_members', {
          'group_id': groupId,
          'project_id': 'project:missing',
          'project_key': '甲方||一号工地',
          'contact': '甲方',
          'site': '一号工地',
          'created_at': '2026-05-17T00:00:00.000Z',
        }),
        throwsA(isA<DatabaseException>()),
      );

      await db.insert('account_project_merge_members', {
        'group_id': groupId,
        'project_id': project.id,
        'project_key': '甲方||一号工地',
        'contact': '甲方',
        'site': '一号工地',
        'created_at': '2026-05-17T00:00:00.000Z',
      });

      await expectLater(
        db.delete('projects', where: 'id = ?', whereArgs: [project.id]),
        throwsA(isA<DatabaseException>()),
      );
      expect(await db.rawQuery('PRAGMA foreign_key_check;'), isEmpty);

      await db.close();
      await deleteDatabase(path);
    });

    test('upgrades v14 databases with external work import tables', () async {
      final path = await _testDbPath('v14_to_v15_external_work');
      await deleteDatabase(path);

      final legacyDb = await openDatabase(
        path,
        version: 14,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, _) async {
          await DbSchema.create(db);
          await db.execute('DROP TABLE external_work_records;');
          await db.execute('DROP TABLE external_import_batches;');
        },
      );
      await legacyDb.close();

      final db = await _openCurrentDb(path);

      expect(await _tableExists(db, 'external_import_batches'), isTrue);
      expect(await _tableExists(db, 'external_work_records'), isTrue);
      expect(
        await _columnNames(db, 'external_work_records'),
        containsAll([
          'hours_milli',
          'source_unit_price_fen',
          'local_unit_price_fen',
          'amount_fen',
          'project_received_fen',
          'linked_project_id',
        ]),
      );

      final fks = await db.rawQuery(
        'PRAGMA foreign_key_list(external_work_records);',
      );
      expect(
        fks,
        contains(
          predicate<Map<String, Object?>>((row) {
            return row['table'] == 'projects' &&
                row['from'] == 'linked_project_id' &&
                row['on_delete'] == 'RESTRICT';
          }),
        ),
      );
      expect(await db.rawQuery('PRAGMA foreign_key_check;'), isEmpty);

      await db.close();
      await deleteDatabase(path);
    });

    test('new v16 databases include project write-off schema', () async {
      final path = await _testDbPath('v16_project_write_off_on_create');
      await deleteDatabase(path);

      final db = await _openCurrentDb(path);

      expect(await _tableExists(db, 'project_write_offs'), isTrue);
      expect(
        await _columnNames(db, 'project_write_offs'),
        containsAll([
          'id',
          'project_id',
          'amount_fen',
          'reason',
          'note',
          'write_off_date',
          'created_at',
          'updated_at',
        ]),
      );
      expect(
        await _indexExists(db, 'idx_project_write_offs_project_id'),
        isTrue,
      );
      expect(
        await _indexExists(db, 'idx_project_write_offs_write_off_date'),
        isTrue,
      );

      await db.close();
      await deleteDatabase(path);
    });

    test('upgrades v15 databases with project write-off table', () async {
      final path = await _testDbPath('v15_to_v16_project_write_offs');
      await deleteDatabase(path);

      final legacyDb = await openDatabase(
        path,
        version: 15,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, _) async {
          await DbSchema.create(db);
          await db.execute(
            'DROP INDEX IF EXISTS idx_project_write_offs_project_id;',
          );
          await db.execute(
            'DROP INDEX IF EXISTS idx_project_write_offs_write_off_date;',
          );
          await db.execute('DROP TABLE IF EXISTS project_write_offs;');
        },
      );
      await legacyDb.close();

      final db = await _openCurrentDb(path);

      expect(await _tableExists(db, 'project_write_offs'), isTrue);
      expect(
        await _indexExists(db, 'idx_project_write_offs_project_id'),
        isTrue,
      );
      expect(
        await _indexExists(db, 'idx_project_write_offs_write_off_date'),
        isTrue,
      );

      await db.close();
      await deleteDatabase(path);
    });

    test(
      'upgrades v17 databases by backfilling first money fen fields',
      () async {
        final path = await _testDbPath('v17_to_v18_money_fen');
        await deleteDatabase(path);

        final legacyDb = await openDatabase(
          path,
          version: 17,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
          onCreate: (db, _) async {
            await DbSchema.create(db);
            await _recreateMoneyTablesWithoutFen(db);
            await db.insert(
              'projects',
              const Project(
                id: 'project:money',
                contact: '甲方',
                site: '金额工地',
                createdAt: '2026-05-18T00:00:00.000Z',
                updatedAt: '2026-05-18T00:00:00.000Z',
              ).toMap(),
            );
            await db.insert('account_payments', {
              'id': 1,
              'project_id': 'project:money',
              'project_key': '甲方||金额工地',
              'ymd': 20260518,
              'amount': 123.45,
              'source_type': 'merge_allocation',
              'merge_batch_id': 'batch-money',
              'merge_batch_total_amount': 5000.01,
            });
            await db.insert('project_write_offs', {
              'id': 'write-off-money',
              'project_id': 'project:money',
              'amount': 6.78,
              'reason': 'rounding',
              'write_off_date': '2026-05-18',
              'created_at': '2026-05-18T00:00:00.000Z',
              'updated_at': '2026-05-18T00:00:00.000Z',
            });
          },
        );
        await legacyDb.close();

        final db = await _openCurrentDb(path);

        expect(
          await _columnNames(db, 'account_payments'),
          contains('amount_fen'),
        );
        expect(
          await _columnNames(db, 'account_payments'),
          contains('merge_batch_total_amount_fen'),
        );
        expect(
          await _columnNames(db, 'account_payments'),
          isNot(contains('amount')),
        );
        expect(
          await _columnNames(db, 'account_payments'),
          isNot(contains('merge_batch_total_amount')),
        );
        expect(
          await _columnNames(db, 'project_write_offs'),
          contains('amount_fen'),
        );
        expect(
          await _columnNames(db, 'project_write_offs'),
          isNot(contains('amount')),
        );

        final payment = (await db.query('account_payments')).single;
        expect(payment['amount_fen'], 12345);
        expect(payment['merge_batch_total_amount_fen'], 500001);
        final writeOff = (await db.query('project_write_offs')).single;
        expect(writeOff['amount_fen'], 678);

        await db.close();
        await deleteDatabase(path);
      },
    );
  });
}

Future<Database> _openCurrentDb(String path) {
  return openDatabase(
    path,
    version: AppDatabase.schemaVersion,
    onConfigure: (db) async {
      await db.execute('PRAGMA foreign_keys = ON');
    },
    onCreate: (db, _) async {
      await DbSchema.create(db);
    },
    onUpgrade: DbMigrations.apply,
    onOpen: (db) async {
      await DbSchemaCompat.ensure(db);
    },
  );
}

Future<bool> _indexExists(Database db, String index) async {
  final rows = await db.query(
    'sqlite_master',
    columns: ['name'],
    where: 'type = ? AND name = ?',
    whereArgs: ['index', index],
    limit: 1,
  );
  return rows.isNotEmpty;
}

Future<String> _testDbPath(String name) async {
  final dbPath = await getDatabasesPath();
  final suffix = DateTime.now().microsecondsSinceEpoch;
  return p.join(dbPath, 'db_migrations_${name}_$suffix.db');
}

Future<List<String>> _columnNames(Database db, String table) async {
  final rows = await db.rawQuery('PRAGMA table_info($table);');
  return rows.map((row) => row['name'] as String).toList();
}

Future<List<String>> _primaryKeyColumns(Database db, String table) async {
  final rows = List<Map<String, Object?>>.from(
    await db.rawQuery('PRAGMA table_info($table);'),
  );
  rows.sort((a, b) {
    final left = (a['pk'] as int?) ?? 0;
    final right = (b['pk'] as int?) ?? 0;
    return left.compareTo(right);
  });
  return rows
      .where((row) => ((row['pk'] as int?) ?? 0) > 0)
      .map((row) => row['name'] as String)
      .toList();
}

Future<Set<String>> _projectForeignKeyTables(Database db) async {
  final tables = <String>{
    'timing_records',
    'account_payments',
    'project_device_rates',
    'account_project_merge_members',
    'project_write_offs',
  };
  final out = <String>{};
  for (final table in tables) {
    final rows = await db.rawQuery('PRAGMA foreign_key_list($table);');
    if (rows.any((row) {
      return row['table'] == 'projects' && row['from'] == 'project_id';
    })) {
      out.add(table);
    }
  }
  return out;
}

Future<bool> _tableExists(Database db, String table) async {
  final rows = await db.query(
    'sqlite_master',
    columns: ['name'],
    where: 'type = ? AND name = ?',
    whereArgs: ['table', table],
    limit: 1,
  );
  return rows.isNotEmpty;
}

Future<void> _recreateMoneyTablesWithoutFen(Database db) async {
  await db.execute('DROP INDEX IF EXISTS idx_account_payments_project_ymd;');
  await db.execute('DROP INDEX IF EXISTS idx_project_write_offs_project_id;');
  await db.execute(
    'DROP INDEX IF EXISTS idx_project_write_offs_write_off_date;',
  );
  await db.execute('DROP TABLE IF EXISTS account_payments;');
  await db.execute('DROP TABLE IF EXISTS project_write_offs;');

  await db.execute('''
    CREATE TABLE account_payments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      project_id TEXT NOT NULL,
      project_key TEXT NOT NULL,
      ymd INTEGER NOT NULL,
      amount REAL NOT NULL,
      note TEXT,
      source_type TEXT NOT NULL DEFAULT 'manual',
      merge_group_id INTEGER,
      merge_batch_id TEXT,
      merge_batch_total_amount REAL,
      merge_batch_note TEXT,
      created_at TEXT,
      FOREIGN KEY (project_id)
        REFERENCES projects(id) ON DELETE RESTRICT
    );
  ''');
  await db.execute('''
    CREATE INDEX idx_account_payments_project_ymd
    ON account_payments(project_id, ymd);
  ''');

  await db.execute('''
    CREATE TABLE project_write_offs (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      amount REAL NOT NULL CHECK (amount > 0),
      reason TEXT NOT NULL,
      note TEXT,
      write_off_date TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (project_id)
        REFERENCES projects(id) ON DELETE RESTRICT
    );
  ''');
  await db.execute('''
    CREATE INDEX idx_project_write_offs_project_id
    ON project_write_offs(project_id);
  ''');
  await db.execute('''
    CREATE INDEX idx_project_write_offs_write_off_date
    ON project_write_offs(write_off_date);
  ''');
}

Future<void> _createV3Schema(Database db) async {
  await db.execute('''
    CREATE TABLE devices (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      brand TEXT NOT NULL,
      model TEXT,
      default_unit_price REAL NOT NULL,
      base_meter_hours REAL NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 1,
      custom_avatar_path TEXT
    );
  ''');

  await db.execute('''
    CREATE TABLE timing_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      device_id INTEGER NOT NULL,
      start_date INTEGER NOT NULL,
      contact TEXT NOT NULL,
      site TEXT NOT NULL,
      type TEXT NOT NULL,
      start_meter REAL NOT NULL,
      end_meter REAL NOT NULL,
      hours REAL NOT NULL,
      income REAL NOT NULL
    );
  ''');

  await db.execute('''
    CREATE TABLE fuel_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      device_id INTEGER NOT NULL,
      date INTEGER NOT NULL,
      supplier TEXT NOT NULL,
      liters REAL NOT NULL,
      cost REAL NOT NULL
    );
  ''');
}

Future<void> _seedV3Data(Database db) async {
  await db.insert('devices', {
    'id': 1,
    'name': 'Legacy SANY 1#',
    'brand': 'SANY',
    'model': 'SY75',
    'default_unit_price': 380.0,
    'base_meter_hours': 88.5,
    'is_active': 1,
    'custom_avatar_path': '/legacy/avatar.png',
  });

  await db.insert('timing_records', {
    'id': 1,
    'device_id': 1,
    'start_date': 20250301,
    'contact': '张三',
    'site': '一号工地',
    'type': 'work',
    'start_meter': 100.0,
    'end_meter': 108.0,
    'hours': 8.0,
    'income': 3040.0,
  });
}

Future<void> _createV7Schema(Database db) async {
  await db.execute('''
    CREATE TABLE devices (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      brand TEXT NOT NULL,
      model TEXT,
      default_unit_price REAL NOT NULL,
      base_meter_hours REAL NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 1,
      custom_avatar_path TEXT
    );
  ''');

  await db.execute('''
    CREATE TABLE timing_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      device_id INTEGER NOT NULL,
      start_date INTEGER NOT NULL,
      contact TEXT NOT NULL,
      site TEXT NOT NULL,
      type TEXT NOT NULL,
      start_meter REAL NOT NULL,
      end_meter REAL NOT NULL,
      hours REAL NOT NULL,
      income REAL NOT NULL,
      exclude_from_fuel_eff INTEGER NOT NULL DEFAULT 0,
      is_breaking INTEGER NOT NULL DEFAULT 0
    );
  ''');

  await db.execute('''
    CREATE TABLE fuel_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      device_id INTEGER NOT NULL,
      date INTEGER NOT NULL,
      supplier TEXT NOT NULL,
      liters REAL NOT NULL,
      cost REAL NOT NULL
    );
  ''');

  await db.execute('''
    CREATE TABLE maintenance_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      device_id INTEGER,
      ymd INTEGER NOT NULL,
      item TEXT NOT NULL,
      amount REAL NOT NULL,
      note TEXT
    );
  ''');

  await db.execute('''
    CREATE TABLE account_payments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      project_key TEXT NOT NULL,
      ymd INTEGER NOT NULL,
      amount REAL NOT NULL,
      note TEXT
    );
  ''');

  await db.execute('''
    CREATE INDEX idx_account_payments_project_ymd
    ON account_payments(project_key, ymd);
  ''');

  await db.execute('''
    CREATE TABLE project_device_rates (
      project_key TEXT NOT NULL,
      device_id INTEGER NOT NULL,
      rate REAL NOT NULL,
      PRIMARY KEY (project_key, device_id)
    );
  ''');

  await db.execute('''
    CREATE INDEX idx_project_device_rates_project
    ON project_device_rates(project_key);
  ''');
}

Future<void> _seedV7Data(Database db) async {
  await db.insert('account_payments', {
    'id': 1,
    'project_key': '李四||二号工地',
    'ymd': 20260515,
    'amount': 500.0,
    'note': '旧库收款',
  });
  await db.insert('project_device_rates', {
    'project_key': '李四||二号工地',
    'device_id': 1,
    'rate': 510.0,
  });
  await db.insert('project_device_rates', {
    'project_key': '李四||三号工地',
    'device_id': 2,
    'rate': 610.0,
  });
}

Future<void> _createDriftedV9Schema(Database db) async {
  await db.execute('''
    CREATE TABLE devices (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      brand TEXT NOT NULL,
      model TEXT,
      default_unit_price REAL NOT NULL,
      base_meter_hours REAL NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 1,
      custom_avatar_path TEXT
    );
  ''');

  await db.execute('''
    CREATE TABLE timing_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      device_id INTEGER NOT NULL,
      start_date INTEGER NOT NULL,
      contact TEXT NOT NULL,
      site TEXT NOT NULL,
      type TEXT NOT NULL,
      start_meter REAL NOT NULL,
      end_meter REAL NOT NULL,
      hours REAL NOT NULL,
      income REAL NOT NULL,
      exclude_from_fuel_eff INTEGER NOT NULL DEFAULT 0,
      is_breaking INTEGER NOT NULL DEFAULT 0
    );
  ''');

  await db.execute('''
    CREATE TABLE fuel_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      device_id INTEGER NOT NULL,
      date INTEGER NOT NULL,
      supplier TEXT NOT NULL,
      liters REAL NOT NULL,
      cost REAL NOT NULL
    );
  ''');

  await db.execute('''
    CREATE TABLE maintenance_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      device_id INTEGER,
      ymd INTEGER NOT NULL,
      item TEXT NOT NULL,
      amount REAL NOT NULL,
      note TEXT
    );
  ''');

  await db.execute('''
    CREATE TABLE account_payments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      project_key TEXT NOT NULL,
      ymd INTEGER NOT NULL,
      amount REAL NOT NULL,
      note TEXT
    );
  ''');

  await db.execute('''
    CREATE INDEX idx_account_payments_project_ymd
    ON account_payments(project_key, ymd);
  ''');

  await db.execute('''
    CREATE TABLE project_device_rates (
      project_key TEXT NOT NULL,
      device_id INTEGER NOT NULL,
      rate REAL NOT NULL,
      PRIMARY KEY (project_key, device_id)
    );
  ''');

  await db.execute('''
    CREATE INDEX idx_project_device_rates_project
    ON project_device_rates(project_key);
  ''');
}

Future<void> _seedDriftedV9Data(Database db) async {
  await db.insert('devices', {
    'id': 1,
    'name': 'Broken Loader',
    'brand': 'XCMG',
    'model': null,
    'default_unit_price': 500.0,
    'base_meter_hours': 12.0,
    'is_active': 1,
    'custom_avatar_path': null,
  });

  await db.insert('project_device_rates', {
    'project_key': '王五||老工地',
    'device_id': 7,
    'rate': 699.0,
  });
}
