import 'dart:io';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../test_setup.dart';

/// R5.26-B3：timing_records.income_fen schema readiness 不变式。
///
/// 锁定 fresh schema：income_fen 存在且 nullable；income REAL 仍 NOT NULL。
/// 本轮 income_fen 维持 nullable —— income (REAL) 仍是业务主口径，income_fen 仅作
/// 存储/同步镜像，读路径切换留待 B4；不放宽其它 timing_records 字段。
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

  test('fresh timing_records schema has income_fen and keeps income REAL', () async {
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onCreate: (db, _) => DbSchema.create(db),
      ),
    );
    try {
      final columns = await _columns(db, 'timing_records');

      // income_fen 存在且 nullable（本轮不改 NOT NULL）。
      expect(columns.containsKey('income_fen'), isTrue);
      expect(
        _isNullable(columns['income_fen']!),
        isTrue,
        reason: 'B3 维持 income_fen nullable；income REAL 仍是业务主口径',
      );

      // income REAL 兼容列仍存在且仍 NOT NULL（本轮不动 REAL income）。
      expect(columns.containsKey('income'), isTrue);
      expect(_isNullable(columns['income']!), isFalse);

      // 不放宽其它字段白名单：核心列仍在。
      for (final expected in const [
        'id',
        'project_id',
        'device_id',
        'start_date',
        'allocation_cutoff_date',
        'contact',
        'site',
        'type',
        'start_meter',
        'end_meter',
        'hours',
        'income',
        'income_fen',
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
