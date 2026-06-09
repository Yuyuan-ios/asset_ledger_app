import 'dart:io';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_migrations.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/db/db_schema_compat.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../test_setup.dart';

/// R5.26-B1：account_payments.amount_fen 提升为 INTEGER NOT NULL（重建表）。
///
/// 覆盖（全程 sqflite_common_ffi，onCreate / onUpgrade / onOpen）：
/// - A fresh schema：amount_fen NOT NULL；merge_batch_total_amount_fen nullable；
///   amount REAL NOT NULL；id AUTOINCREMENT；idx 与 FK RESTRICT 在 DDL；manual 收款
///   不提供 merge_batch_total_amount_fen 仍可插入。
/// - B 多版本升级（缺列 / nullable+残留 NULL / v30 漂移）→ v31：NOT NULL、无 NULL、
///   行数无丢失、COALESCE 兜底、其余列原值保留、manual 行 merge fen 仍 NULL、
///   merge 行 merge fen 被回填、FK RESTRICT 与 idx 仍在。
/// - C 坑A：AUTOINCREMENT 历史高水位不倒退（old_seq > MAX(id) 时仍保留）、无
///   account_payments_v31 残留序列行、新 id > old_seq 且不冲突、seq >= 新 id。
/// - D 坑C：重建后 merge_batch_total_amount_fen 仍 nullable 且 NULL 行保留。
/// - E 当前版本漂移经 ensure 自愈为 NOT NULL（onOpen 口径）。
/// - F 幂等：先真重建、再 no-op；数据 / AUTOINCREMENT 高水位不被破坏。
/// - G FK RESTRICT：重建后孤儿插入失败、删除被引用 project 失败。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  late Directory tmpDir;
  late String dbPath;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('account_payment_fen_notnull_');
    dbPath = p.join(tmpDir.path, 'asset_ledger.db');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  // ---------------------------------------------------------------------------
  // A：fresh schema 结构正确。
  // ---------------------------------------------------------------------------
  test('fresh schema: amount_fen NOT NULL, merge fen nullable, AUTOINCREMENT + '
      'FK + index present', () async {
    final db = await _openFreshDb(dbPath);
    try {
      expect(await _isNotNull(db, 'account_payments', 'amount_fen'), isTrue);
      // merge_batch_total_amount_fen 仍 nullable（坑C）。
      expect(
        await _isNotNull(db, 'account_payments', 'merge_batch_total_amount_fen'),
        isFalse,
      );
      // amount REAL 兼容列仍 NOT NULL。
      expect(await _isNotNull(db, 'account_payments', 'amount'), isTrue);

      final ddl = await _ddl(db, 'account_payments');
      expect(ddl.contains('AUTOINCREMENT'), isTrue);
      expect(ddl.contains('ON DELETE RESTRICT'), isTrue);
      expect(await _indexExists(db, 'idx_account_payments_project_ymd'), isTrue);

      // manual 收款不提供 merge_batch_total_amount_fen 应成功（坑C）。
      await _insertProject(db, id: 'project:a');
      await db.insert('account_payments', {
        'project_id': 'project:a',
        'project_key': '甲方||一号工地',
        'ymd': 20260601,
        'amount': 50.0,
        'amount_fen': 5000,
        'source_type': 'manual',
      });
      expect(
        (await db.query('account_payments')).single['merge_batch_total_amount_fen'],
        isNull,
      );
    } finally {
      await db.close();
    }
  });

  // ---------------------------------------------------------------------------
  // B1：legacy「缺 amount_fen 列」→ v31（数据 / 约束 / 索引保留）。
  // ---------------------------------------------------------------------------
  test('legacy (no amount_fen column) -> v31: NOT NULL, COALESCE backfilled, '
      'data + constraints + index preserved', () async {
    final legacy = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 17,
        onConfigure: _enableForeignKeys,
        onCreate: (db, _) async {
          await DbSchema.create(db);
          await _recreateAccountPaymentsLegacy(db, withAmountFenColumn: false);
          await _insertProject(db, id: 'project:a');
          // 缺列：均不写 amount_fen / merge_batch_total_amount_fen。
          await _insertPaymentRaw(db, id: 1, amount: 123.45, note: '收款一');
          await _insertPaymentRaw(db, id: 2, amount: 0.1);
          await _insertPaymentRaw(
            db,
            id: 3,
            amount: 200.0,
            sourceType: 'merge_allocation',
            mergeGroupId: 7,
            mergeBatchId: 'batch-x',
            mergeBatchTotalAmount: 600.0,
            mergeBatchNote: '微信',
          );
        },
      ),
    );
    expect(await _columnExists(legacy, 'account_payments', 'amount_fen'), isFalse);
    await legacy.close();

    final db = await _openCurrentDb(dbPath);
    try {
      expect(await _isNotNull(db, 'account_payments', 'amount_fen'), isTrue);
      expect(await _nullFenCount(db), 0);
      expect(await _rowCount(db, 'account_payments'), 3);

      final rows = await db.query('account_payments', orderBy: 'id ASC');
      // 逐行 amount_fen == round(amount*100)（COALESCE 兜底）。
      for (final row in rows) {
        final amount = (row['amount'] as num).toDouble();
        expect((row['amount_fen'] as num?)?.toInt(), (amount * 100).round());
      }
      // 其余列原值保留。
      final r1 = rows[0];
      expect(r1['note'], '收款一');
      expect(r1['source_type'], 'manual');
      // manual 行 merge_batch_total_amount_fen 仍 NULL。
      expect(r1['merge_batch_total_amount_fen'], isNull);
      expect(rows[1]['merge_batch_total_amount_fen'], isNull);

      final r3 = rows[2];
      expect(r3['source_type'], 'merge_allocation');
      expect(r3['merge_group_id'], 7);
      expect(r3['merge_batch_id'], 'batch-x');
      expect((r3['merge_batch_total_amount'] as num).toDouble(), 600.0);
      expect(r3['merge_batch_note'], '微信');
      // merge 行 merge_batch_total_amount_fen 被 migration_018 回填。
      expect((r3['merge_batch_total_amount_fen'] as num?)?.toInt(), 60000);

      expect(await _indexExists(db, 'idx_account_payments_project_ymd'), isTrue);

      // FK RESTRICT 仍生效（带合法 amount_fen，确保唯一违例是 FK）。
      await expectLater(
        db.insert('account_payments', {
          'project_id': 'no-such',
          'project_key': '甲方||一号工地',
          'ymd': 20260601,
          'amount': 5.0,
          'amount_fen': 500,
          'source_type': 'manual',
        }),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        db.delete('projects', where: 'id = ?', whereArgs: ['project:a']),
        throwsA(isA<DatabaseException>()),
      );
    } finally {
      await db.close();
    }
  });

  // ---------------------------------------------------------------------------
  // B2：legacy「nullable amount_fen + 残留 NULL」（v18）→ v31。
  // ---------------------------------------------------------------------------
  test('legacy v18 (nullable amount_fen with residual NULL) -> v31: COALESCE '
      'backfills NULL, keeps existing fen', () async {
    final legacy = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 18,
        onConfigure: _enableForeignKeys,
        onCreate: (db, _) async {
          await DbSchema.create(db);
          await _recreateAccountPaymentsLegacy(db, withAmountFenColumn: true);
          await _insertProject(db, id: 'project:a');
          // 一行带一致 fen，一行 fen=NULL（残留漂移）。
          await _insertPaymentRaw(db, id: 1, amount: 60.0, amountFen: 6000);
          await _insertPaymentRaw(db, id: 2, amount: 12.34, amountFen: null);
        },
      ),
    );
    await legacy.close();

    final db = await _openCurrentDb(dbPath);
    try {
      expect(await _isNotNull(db, 'account_payments', 'amount_fen'), isTrue);
      expect(await _nullFenCount(db), 0);
      expect(
        (await db.query('account_payments', where: 'id = ?', whereArgs: [1]))
            .single['amount_fen'],
        6000,
      );
      // NULL 行被兜底为 round(12.34*100)=1234。
      expect(
        (await db.query('account_payments', where: 'id = ?', whereArgs: [2]))
            .single['amount_fen'],
        1234,
      );
    } finally {
      await db.close();
    }
  });

  // ---------------------------------------------------------------------------
  // B3：当前前一版本 v30 漂移库（nullable + NULL）→ v31。
  //     30->31 升级链不再触发 migration_018，证明 migration_031 的 COALESCE 是
  //     最后兜底。
  // ---------------------------------------------------------------------------
  test('v30 drift db (nullable amount_fen + NULL) -> v31 via migration_031 '
      'COALESCE', () async {
    final legacy = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 30,
        onConfigure: _enableForeignKeys,
        onCreate: (db, _) async {
          await DbSchema.create(db);
          await _recreateAccountPaymentsLegacy(db, withAmountFenColumn: true);
          await _insertProject(db, id: 'project:a');
          await _insertPaymentRaw(db, id: 1, amount: 88.80, amountFen: null);
        },
      ),
    );
    await legacy.close();

    final db = await _openCurrentDb(dbPath);
    try {
      expect(await _isNotNull(db, 'account_payments', 'amount_fen'), isTrue);
      expect(await _nullFenCount(db), 0);
      expect((await db.query('account_payments')).single['amount_fen'], 8880);
    } finally {
      await db.close();
    }
  });

  // ---------------------------------------------------------------------------
  // C：坑A —— AUTOINCREMENT 历史高水位不倒退 + 连续性。
  // ---------------------------------------------------------------------------
  test('坑A: AUTOINCREMENT high-water mark survives rebuild (old_seq > MAX(id))',
      () async {
    final db = await _openLegacyNullableAtCurrentVersion(dbPath);
    try {
      await _insertProject(db, id: 'project:a');
      // 低 id。
      await _insertPaymentRaw(db, id: 1, amount: 10.0, amountFen: 1000);
      await _insertPaymentRaw(db, id: 2, amount: 20.0, amountFen: 2000);
      // 显式高 id 后删除，制造 old_seq > MAX(id)。
      await _insertPaymentRaw(db, id: 1000, amount: 30.0, amountFen: 3000);
      await db.delete('account_payments', where: 'id = ?', whereArgs: [1000]);

      final oldSeq = await _seq(db, 'account_payments');
      final maxIdBefore = await _maxId(db, 'account_payments');
      expect(oldSeq, greaterThan(maxIdBefore),
          reason: 'old_seq 应高于当前 MAX(id)（已删除高 id）');

      await DbMigrations.ensureAccountPaymentAmountFenNotNull(db);

      // 列已 NOT NULL。
      expect(await _isNotNull(db, 'account_payments', 'amount_fen'), isTrue);
      // 1) 高水位未倒退。
      expect(await _seq(db, 'account_payments'), greaterThanOrEqualTo(oldSeq));
      // 2) 无 account_payments_v31 残留序列行。
      expect(await _seqRowCount(db, 'account_payments_v31'), 0);
      // sqlite_sequence 中 account_payments 恰一行（无重复）。
      expect(await _seqRowCount(db, 'account_payments'), 1);

      // 3) 再 raw insert（不指定 id）一条新收款（带 amount_fen）。
      final newId = await db.insert('account_payments', {
        'project_id': 'project:a',
        'project_key': '甲方||一号工地',
        'ymd': 20260601,
        'amount': 5.0,
        'amount_fen': 500,
        'source_type': 'manual',
      });
      // 新 id > 重建前高水位（不复用已删除的 1000 之下区间）。
      expect(newId, greaterThan(oldSeq));
      // 4) 新 id 不与任何现有 id 冲突。
      final ids = (await db.query('account_payments', columns: ['id']))
          .map((row) => (row['id'] as num).toInt())
          .toList();
      expect(ids.where((id) => id == newId).length, 1);
      // 5) seq >= 新 id。
      expect(await _seq(db, 'account_payments'), greaterThanOrEqualTo(newId));
    } finally {
      await db.close();
    }
  });

  // ---------------------------------------------------------------------------
  // D：坑C —— 重建后 merge_batch_total_amount_fen 仍 nullable 且 NULL 行保留。
  // ---------------------------------------------------------------------------
  test('坑C: rebuild keeps merge_batch_total_amount_fen nullable and NULL '
      'preserved', () async {
    final db = await _openLegacyNullableAtCurrentVersion(dbPath);
    try {
      await _insertProject(db, id: 'project:a');
      // manual 行：amount_fen 有值，merge fen 缺省 NULL。
      await _insertPaymentRaw(db, id: 1, amount: 50.0, amountFen: 5000);

      // 重建前两列均 nullable。
      expect(await _isNotNull(db, 'account_payments', 'amount_fen'), isFalse);
      expect(
        await _isNotNull(db, 'account_payments', 'merge_batch_total_amount_fen'),
        isFalse,
      );

      await DbMigrations.ensureAccountPaymentAmountFenNotNull(db);

      // 重建后 amount_fen NOT NULL，但 merge fen 仍 nullable（绝不翻 NOT NULL）。
      expect(await _isNotNull(db, 'account_payments', 'amount_fen'), isTrue);
      expect(
        await _isNotNull(db, 'account_payments', 'merge_batch_total_amount_fen'),
        isFalse,
      );
      expect(
        (await db.query('account_payments')).single['merge_batch_total_amount_fen'],
        isNull,
      );
      // 重建后仍可插入不带 merge fen 的 manual 收款。
      await db.insert('account_payments', {
        'project_id': 'project:a',
        'project_key': '甲方||一号工地',
        'ymd': 20260602,
        'amount': 9.0,
        'amount_fen': 900,
        'source_type': 'manual',
      });
      final rows = await db.query('account_payments', orderBy: 'id ASC');
      expect(rows.last['merge_batch_total_amount_fen'], isNull);
    } finally {
      await db.close();
    }
  });

  // ---------------------------------------------------------------------------
  // E：当前版本漂移（nullable amount_fen + NULL 行）经 ensure 自愈（onOpen 口径）。
  // ---------------------------------------------------------------------------
  test('current-version drift (nullable amount_fen + NULL row) healed by ensure',
      () async {
    final db = await _openLegacyNullableAtCurrentVersion(dbPath);
    try {
      await _insertProject(db, id: 'project:a');
      await _insertPaymentRaw(db, id: 1, amount: 88.80, amountFen: null);

      expect(await _isNotNull(db, 'account_payments', 'amount_fen'), isFalse);
      expect(await _nullFenCount(db), 1);

      await DbMigrations.ensureAccountPaymentAmountFenNotNull(db);

      expect(await _isNotNull(db, 'account_payments', 'amount_fen'), isTrue);
      expect(await _nullFenCount(db), 0);
      expect((await db.query('account_payments')).single['amount_fen'], 8880);
    } finally {
      await db.close();
    }
  });

  // ---------------------------------------------------------------------------
  // F：幂等 —— 先真重建、再 no-op；数据 / AUTOINCREMENT 高水位不被破坏。
  // ---------------------------------------------------------------------------
  test('ensure idempotent: first rebuild then no-op, data + AUTOINCREMENT intact',
      () async {
    final db = await _openLegacyNullableAtCurrentVersion(dbPath);
    try {
      await _insertProject(db, id: 'project:a');
      await _insertPaymentRaw(db, id: 1, amount: 50.0, amountFen: 5000);
      await _insertPaymentRaw(db, id: 7, amount: 70.0, amountFen: 7000);

      // 第一次：真正重建。
      await DbMigrations.ensureAccountPaymentAmountFenNotNull(db);
      expect(await _isNotNull(db, 'account_payments', 'amount_fen'), isTrue);
      final seqAfterFirst = await _seq(db, 'account_payments');
      expect(seqAfterFirst, greaterThanOrEqualTo(7));

      // 第二次：已 NOT NULL → no-op。
      await DbMigrations.ensureAccountPaymentAmountFenNotNull(db);
      expect(await _isNotNull(db, 'account_payments', 'amount_fen'), isTrue);
      expect(await _rowCount(db, 'account_payments'), 2);
      expect(
        (await db.query('account_payments', where: 'id = ?', whereArgs: [1]))
            .single['amount_fen'],
        5000,
      );
      expect(
        (await db.query('account_payments', where: 'id = ?', whereArgs: [7]))
            .single['amount_fen'],
        7000,
      );
      // no-op 不倒退、不破坏 AUTOINCREMENT。
      expect(await _seq(db, 'account_payments'), seqAfterFirst);
      expect(await _seqRowCount(db, 'account_payments_v31'), 0);
      final newId = await db.insert('account_payments', {
        'project_id': 'project:a',
        'project_key': '甲方||一号工地',
        'ymd': 20260603,
        'amount': 6.0,
        'amount_fen': 600,
        'source_type': 'manual',
      });
      expect(newId, greaterThan(7));
    } finally {
      await db.close();
    }
  });

  // ---------------------------------------------------------------------------
  // G：FK RESTRICT —— 重建后孤儿插入失败、删除被引用 project 失败。
  // ---------------------------------------------------------------------------
  test('坑G: rebuilt table keeps FK RESTRICT (orphan insert + delete referenced '
      'project both fail)', () async {
    final db = await _openLegacyNullableAtCurrentVersion(dbPath);
    try {
      await _insertProject(db, id: 'project:a');
      await _insertPaymentRaw(db, id: 1, amount: 50.0, amountFen: 5000);

      // 经 ensure 重建为 NOT NULL 的表上验证 FK。
      await DbMigrations.ensureAccountPaymentAmountFenNotNull(db);
      expect(await _isNotNull(db, 'account_payments', 'amount_fen'), isTrue);

      // 孤儿 project_id 插入失败（带合法 amount_fen，确保违例来自 FK）。
      await expectLater(
        db.insert('account_payments', {
          'project_id': 'no-such',
          'project_key': '甲方||一号工地',
          'ymd': 20260601,
          'amount': 5.0,
          'amount_fen': 500,
          'source_type': 'manual',
        }),
        throwsA(isA<DatabaseException>()),
      );
      // 删除被 account_payments 引用的 project 失败。
      await expectLater(
        db.delete('projects', where: 'id = ?', whereArgs: ['project:a']),
        throwsA(isA<DatabaseException>()),
      );
    } finally {
      await db.close();
    }
  });
}

// ===========================================================================
// Helpers
// ===========================================================================

const Object _absent = Object();

Future<void> _enableForeignKeys(Database db) async {
  await db.execute('PRAGMA foreign_keys = ON');
}

Future<Database> _openFreshDb(String path) {
  return databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: AppDatabase.schemaVersion,
      onConfigure: _enableForeignKeys,
      onCreate: (db, _) => DbSchema.create(db),
    ),
  );
}

Future<Database> _openCurrentDb(String path) {
  return databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: AppDatabase.schemaVersion,
      onConfigure: _enableForeignKeys,
      onCreate: (db, _) => DbSchema.create(db),
      onUpgrade: DbMigrations.apply,
      onOpen: (db) => DbSchemaCompat.ensure(db),
    ),
  );
}

/// 在当前版本库上把 account_payments 退回 nullable amount_fen 形态（可自由插任意
/// id / NULL，便于构造高水位与漂移桩）。不挂 onOpen ensure，避免开库即自愈。
Future<Database> _openLegacyNullableAtCurrentVersion(String path) {
  return databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: AppDatabase.schemaVersion,
      onConfigure: _enableForeignKeys,
      onCreate: (db, _) async {
        await DbSchema.create(db);
        await _recreateAccountPaymentsLegacy(db, withAmountFenColumn: true);
      },
    ),
  );
}

Future<void> _insertProject(DatabaseExecutor db, {required String id}) async {
  await db.insert(
    'projects',
    Project(
      id: id,
      contact: '甲方',
      site: '一号工地',
      createdAt: '2026-05-18T00:00:00.000Z',
      updatedAt: '2026-05-18T00:00:00.000Z',
    ).toMap(),
  );
}

/// 把 account_payments 退回旧形态。
/// - withAmountFenColumn=false：完全缺 amount_fen / merge_batch_total_amount_fen
///   两个 fen 列（真 pre-v18）。
/// - withAmountFenColumn=true：含两个 fen 列且 amount_fen nullable（当前漂移形态）。
Future<void> _recreateAccountPaymentsLegacy(
  DatabaseExecutor db, {
  required bool withAmountFenColumn,
}) async {
  await db.execute('DROP INDEX IF EXISTS idx_account_payments_project_ymd;');
  await db.execute('DROP TABLE IF EXISTS account_payments;');
  final fenColumns = withAmountFenColumn
      ? 'amount_fen INTEGER,\n      merge_batch_total_amount_fen INTEGER,'
      : '';
  await db.execute('''
    CREATE TABLE account_payments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      project_id TEXT NOT NULL,
      project_key TEXT NOT NULL,
      ymd INTEGER NOT NULL,
      amount REAL NOT NULL,
      $fenColumns
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
}

/// 直接按当前 legacy 列集插入；amountFen 为 [_absent] 时不写该键（缺列形态）、
/// 为 null 时写 NULL（漂移形态）、为数值时写值。
Future<void> _insertPaymentRaw(
  DatabaseExecutor db, {
  required int id,
  required double amount,
  Object? amountFen = _absent,
  String sourceType = 'manual',
  String projectId = 'project:a',
  String projectKey = '甲方||一号工地',
  String? note,
  int? mergeGroupId,
  String? mergeBatchId,
  double? mergeBatchTotalAmount,
  String? mergeBatchNote,
}) async {
  final row = <String, Object?>{
    'id': id,
    'project_id': projectId,
    'project_key': projectKey,
    'ymd': 20260518,
    'amount': amount,
    'source_type': sourceType,
    'created_at': '2026-05-18T00:00:00.000Z',
  };
  if (!identical(amountFen, _absent)) row['amount_fen'] = amountFen;
  if (note != null) row['note'] = note;
  if (mergeGroupId != null) row['merge_group_id'] = mergeGroupId;
  if (mergeBatchId != null) row['merge_batch_id'] = mergeBatchId;
  if (mergeBatchTotalAmount != null) {
    row['merge_batch_total_amount'] = mergeBatchTotalAmount;
  }
  if (mergeBatchNote != null) row['merge_batch_note'] = mergeBatchNote;
  await db.insert('account_payments', row);
}

Future<bool> _columnExists(
  DatabaseExecutor db,
  String table,
  String column,
) async {
  final rows = await db.rawQuery('PRAGMA table_info($table);');
  return rows.any((row) => row['name'] == column);
}

Future<bool> _isNotNull(
  DatabaseExecutor db,
  String table,
  String column,
) async {
  final rows = await db.rawQuery('PRAGMA table_info($table);');
  for (final row in rows) {
    if (row['name'] == column) return ((row['notnull'] as int?) ?? 0) == 1;
  }
  return false;
}

Future<int> _nullFenCount(DatabaseExecutor db) async {
  final rows = await db.rawQuery(
    'SELECT COUNT(*) AS c FROM account_payments WHERE amount_fen IS NULL',
  );
  return (rows.single['c'] as num?)?.toInt() ?? 0;
}

Future<int> _rowCount(DatabaseExecutor db, String table) async {
  final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
  return (rows.single['c'] as num?)?.toInt() ?? 0;
}

Future<bool> _indexExists(DatabaseExecutor db, String index) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'index' AND name = ?;",
    [index],
  );
  return rows.isNotEmpty;
}

Future<String> _ddl(DatabaseExecutor db, String table) async {
  final rows = await db.rawQuery(
    "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?;",
    [table],
  );
  return (rows.first['sql'] as String?) ?? '';
}

Future<int> _seq(DatabaseExecutor db, String name) async {
  final rows = await db.rawQuery(
    'SELECT seq FROM sqlite_sequence WHERE name = ?;',
    [name],
  );
  if (rows.isEmpty) return 0;
  return (rows.first['seq'] as num?)?.toInt() ?? 0;
}

Future<int> _seqRowCount(DatabaseExecutor db, String name) async {
  final rows = await db.rawQuery(
    'SELECT COUNT(*) AS c FROM sqlite_sequence WHERE name = ?;',
    [name],
  );
  return (rows.single['c'] as num?)?.toInt() ?? 0;
}

Future<int> _maxId(DatabaseExecutor db, String table) async {
  final rows = await db.rawQuery('SELECT COALESCE(MAX(id), 0) AS m FROM $table');
  return (rows.single['m'] as num?)?.toInt() ?? 0;
}
