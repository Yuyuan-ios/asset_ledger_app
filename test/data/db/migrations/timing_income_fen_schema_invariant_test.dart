import 'dart:io';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../test_setup.dart';

/// R5.26-B3 → v34，Track A / A4-7：timing_records.income_fen schema 不变式。
///
/// 锁定 fresh schema：income_fen 存在且 **NOT NULL**（v34/migration_034 起由
/// schema 强制）；A4-7 起 income REAL 已删除。unit NOT NULL；quantity_scaled
/// 保持 nullable（rent 行 quantity 合法为 NULL,v33 语义）；不放宽其它字段。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  late Directory tmpDir;
  late String dbPath;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('timing_income_fen_schema_');
    dbPath = p.join(tmpDir.path, 'asset_ledger.db');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test('fresh timing_records schema is income_fen-only', () async {
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onCreate: (db, _) => DbSchema.create(db),
      ),
    );
    try {
      final columns = await _columns(db, 'timing_records');

      // v34：income_fen NOT NULL 由 schema 强制。
      expect(columns.containsKey('income_fen'), isTrue);
      expect(
        _isNullable(columns['income_fen']!),
        isFalse,
        reason: 'v34/migration_034 起 income_fen 为 INTEGER NOT NULL',
      );

      // Track A / A4-7：income REAL 已删除，income_fen 是唯一存储权威。
      expect(columns.containsKey('income'), isFalse);

      // v36：unit 由 schema 强制 NOT NULL（S2 权威收口）；
      // quantity_scaled 保持 nullable（rent 行租期计量语义未定）。
      expect(_isNullable(columns['unit']!), isFalse);
      expect(_isNullable(columns['quantity_scaled']!), isTrue);

      // 不放宽其它字段白名单：核心列仍在。
      for (final expected in const [
        'id',
        'project_id',
        'device_id',
        'start_date',
        'allocation_cutoff_date',
        'display_end_date',
        'contact',
        'site',
        'type',
        'start_meter',
        'end_meter',
        'hours',
        'income_fen',
        'unit',
        'quantity_scaled',
        'exclude_from_fuel_eff',
        'is_breaking',
      ]) {
        expect(
          columns.containsKey(expected),
          isTrue,
          reason: 'timing_records 缺列：$expected',
        );
      }
    } finally {
      await db.close();
    }
  });
}

Future<Map<String, Map<String, Object?>>> _columns(
  DatabaseExecutor db,
  String table,
) async {
  final rows = await db.rawQuery('PRAGMA table_info($table);');
  return {for (final row in rows) row['name'] as String: row};
}

bool _isNullable(Map<String, Object?> columnInfo) {
  return ((columnInfo['notnull'] as int?) ?? 0) == 0;
}
