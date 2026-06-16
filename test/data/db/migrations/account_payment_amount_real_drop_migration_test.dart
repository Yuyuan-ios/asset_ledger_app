import 'dart:io';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_migrations.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../test_setup.dart';

/// Track A / A4-6：account_payments.amount / merge_batch_total_amount REAL
/// 删除，fen 列成为唯一存储权威。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  late Directory tmpDir;
  late String dbPath;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp(
      'account_payment_real_drop_',
    );
    dbPath = p.join(tmpDir.path, 'asset_ledger.db');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test(
    'fresh schema has no amount REAL columns and keeps FK/indexes',
    () async {
      final db = await _openFreshDb(dbPath);
      try {
        final columns = await _columnNames(db, 'account_payments');
        expect(columns, isNot(contains('amount')));
        expect(columns, isNot(contains('merge_batch_total_amount')));
        expect(columns, contains('amount_fen'));
        expect(columns, contains('merge_batch_total_amount_fen'));
        expect(await _isNotNull(db, 'account_payments', 'amount_fen'), isTrue);
        expect(
          await _isNotNull(
            db,
            'account_payments',
            'merge_batch_total_amount_fen',
          ),
          isFalse,
        );

        final ddl = await _ddl(db, 'account_payments');
        expect(ddl.contains('AUTOINCREMENT'), isTrue);
        expect(ddl.contains('ON DELETE RESTRICT'), isTrue);
        expect(
          await _indexExists(db, 'idx_account_payments_project_ymd'),
          isTrue,
        );

        await _insertProject(db, id: 'project:a');
        await db.insert('account_payments', {
          'project_id': 'project:a',
          'project_key': '甲方||一号工地',
          'ymd': 20260601,
          'amount_fen': 5000,
          'source_type': 'manual',
        });
        final row = (await db.query('account_payments')).single;
        expect(row['amount_fen'], 5000);
        expect(row['merge_batch_total_amount_fen'], isNull);

        await expectLater(
          db.insert('account_payments', {
            'project_id': 'missing',
            'project_key': '甲方||一号工地',
            'ymd': 20260601,
            'amount_fen': 500,
            'source_type': 'manual',
          }),
          throwsA(isA<DatabaseException>()),
        );
      } finally {
        await db.close();
      }
    },
  );

  test(
    'legacy v46 -> v47 drops REAL columns, backfills fen, keeps sequence',
    () async {
      final legacy = await _openLegacyV46(dbPath);
      try {
        await _insertProject(legacy, id: 'project:a');
        await _insertLegacyPayment(
          legacy,
          id: 1,
          amount: 123.45,
          amountFen: null,
        );
        await _insertLegacyPayment(
          legacy,
          id: 2,
          amount: 10.0,
          amountFen: 1001,
        );
        await _insertLegacyPayment(
          legacy,
          id: 1000,
          amount: 5.0,
          amountFen: 500,
        );
        await legacy.delete(
          'account_payments',
          where: 'id = ?',
          whereArgs: [1000],
        );
        await _insertLegacyPayment(
          legacy,
          id: 3,
          amount: 200.0,
          amountFen: null,
          sourceType: 'merge_allocation',
          mergeBatchId: 'batch-a',
          mergeBatchTotalAmount: 600.0,
          mergeBatchTotalAmountFen: null,
        );
        expect(await _seq(legacy, 'account_payments'), 1000);
      } finally {
        await legacy.close();
      }

      final db = await _openCurrentDb(dbPath);
      try {
        final columns = await _columnNames(db, 'account_payments');
        expect(columns, isNot(contains('amount')));
        expect(columns, isNot(contains('merge_batch_total_amount')));
        expect(await _rowCount(db, 'account_payments'), 3);

        final rows = await db.query('account_payments', orderBy: 'id ASC');
        expect(
          rows.map((row) => (row['amount_fen'] as num?)?.toInt()).toList(),
          [12345, 1001, 20000],
        );
        expect(rows[2]['merge_batch_total_amount_fen'], 60000);
        expect(rows[2]['merge_batch_id'], 'batch-a');
        expect(
          await _indexExists(db, 'idx_account_payments_project_ymd'),
          isTrue,
        );
        expect(await db.rawQuery('PRAGMA foreign_key_check;'), isEmpty);
        expect(await _seqRowCount(db, 'account_payments_v47'), 0);
        expect(await _seqRowCount(db, 'account_payments'), 1);
        expect(await _seq(db, 'account_payments'), 1000);

        final newId = await db.insert('account_payments', {
          'project_id': 'project:a',
          'project_key': '甲方||一号工地',
          'ymd': 20260602,
          'amount_fen': 700,
          'source_type': 'manual',
        });
        expect(newId, greaterThan(1000));
      } finally {
        await db.close();
      }
    },
  );

  test('ensure is idempotent after first rebuild', () async {
    final db = await _openLegacyV46(dbPath);
    try {
      await _insertProject(db, id: 'project:a');
      await _insertLegacyPayment(db, id: 1, amount: 50.0, amountFen: null);

      await DbMigrations.ensureAccountPaymentAmountRealsDropped(db);
      final columnsAfterFirst = await _columnNames(db, 'account_payments');
      final seqAfterFirst = await _seq(db, 'account_payments');

      await DbMigrations.ensureAccountPaymentAmountRealsDropped(db);
      expect(await _columnNames(db, 'account_payments'), columnsAfterFirst);
      expect(await _seq(db, 'account_payments'), seqAfterFirst);
      expect((await db.query('account_payments')).single['amount_fen'], 5000);
    } finally {
      await db.close();
    }
  });
}

Future<Database> _openFreshDb(String path) {
  return databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: AppDatabase.schemaVersion,
      onConfigure: _enableForeignKeys,
      onCreate: (db, _) => DbSchema.create(db),
      onOpen: (db) async {
        await DbMigrations.ensureAccountPaymentAmountRealsDropped(db);
      },
    ),
  );
}

Future<Database> _openCurrentDb(String path) {
  return databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: AppDatabase.schemaVersion,
      onConfigure: _enableForeignKeys,
      onUpgrade: DbMigrations.apply,
      onOpen: (db) async {
        await DbMigrations.ensureAccountPaymentAmountRealsDropped(db);
      },
    ),
  );
}

Future<Database> _openLegacyV46(String path) async {
  final db = await databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 46,
      onConfigure: _enableForeignKeys,
      onCreate: (db, _) async {
        await DbSchema.create(db);
        await _recreateAccountPaymentsLegacy(db);
      },
    ),
  );
  return db;
}

Future<void> _enableForeignKeys(Database db) async {
  await db.execute('PRAGMA foreign_keys = ON;');
}

Future<void> _recreateAccountPaymentsLegacy(DatabaseExecutor db) async {
  await db.execute('DROP INDEX IF EXISTS idx_account_payments_project_ymd;');
  await db.execute('DROP TABLE IF EXISTS account_payments;');
  await db.execute('''
    CREATE TABLE account_payments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      project_id TEXT NOT NULL,
      project_key TEXT NOT NULL,
      ymd INTEGER NOT NULL,
      amount REAL NOT NULL,
      amount_fen INTEGER,
      note TEXT,
      source_type TEXT NOT NULL DEFAULT 'manual',
      merge_group_id INTEGER,
      merge_batch_id TEXT,
      merge_batch_total_amount REAL,
      merge_batch_total_amount_fen INTEGER,
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
}

Future<void> _insertProject(DatabaseExecutor db, {required String id}) async {
  await db.insert(
    'projects',
    Project(
      id: id,
      contact: '甲方',
      site: '一号工地',
      createdAt: '2026-06-01T00:00:00.000Z',
      updatedAt: '2026-06-01T00:00:00.000Z',
    ).toMap(),
  );
}

Future<void> _insertLegacyPayment(
  DatabaseExecutor db, {
  required int id,
  required double amount,
  required int? amountFen,
  String sourceType = 'manual',
  String? mergeBatchId,
  double? mergeBatchTotalAmount,
  int? mergeBatchTotalAmountFen,
}) async {
  await db.insert('account_payments', {
    'id': id,
    'project_id': 'project:a',
    'project_key': '甲方||一号工地',
    'ymd': 20260601,
    'amount': amount,
    'amount_fen': amountFen,
    'source_type': sourceType,
    'merge_batch_id': mergeBatchId,
    'merge_batch_total_amount': mergeBatchTotalAmount,
    'merge_batch_total_amount_fen': mergeBatchTotalAmountFen,
    'created_at': '2026-06-01T00:00:00.000Z',
  });
}

Future<List<String>> _columnNames(DatabaseExecutor db, String table) async {
  final rows = await db.rawQuery('PRAGMA table_info($table);');
  return rows.map((row) => row['name'] as String).toList();
}

Future<bool> _isNotNull(
  DatabaseExecutor db,
  String table,
  String column,
) async {
  final rows = await db.rawQuery('PRAGMA table_info($table);');
  final row = rows.singleWhere((item) => item['name'] == column);
  return row['notnull'] == 1;
}

Future<String> _ddl(DatabaseExecutor db, String table) async {
  final rows = await db.rawQuery(
    "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?;",
    [table],
  );
  return rows.single['sql'] as String;
}

Future<bool> _indexExists(DatabaseExecutor db, String name) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'index' AND name = ?;",
    [name],
  );
  return rows.isNotEmpty;
}

Future<int> _rowCount(DatabaseExecutor db, String table) async {
  final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM $table;');
  return (rows.single['c'] as num).toInt();
}

Future<int> _seq(DatabaseExecutor db, String table) async {
  final rows = await db.rawQuery(
    'SELECT seq FROM sqlite_sequence WHERE name = ?;',
    [table],
  );
  if (rows.isEmpty) return 0;
  return (rows.single['seq'] as num).toInt();
}

Future<int> _seqRowCount(DatabaseExecutor db, String table) async {
  final rows = await db.rawQuery(
    'SELECT COUNT(*) AS c FROM sqlite_sequence WHERE name = ?;',
    [table],
  );
  return (rows.single['c'] as num?)?.toInt() ?? 0;
}
