part of '../db_migrations.dart';

Future<bool> _tableExists(Database db, String table) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?;",
    [table],
  );
  return rows.isNotEmpty;
}

Future<void> _addColumnIfMissing(
  Database db,
  String table,
  String column,
  String definition,
) async {
  final columns = await db.rawQuery('PRAGMA table_info($table);');
  final exists = columns.any((row) => row['name'] == column);
  if (exists) return;
  await db.execute('ALTER TABLE $table ADD COLUMN $column $definition;');
}

Future<bool> _columnExists(Database db, String table, String column) async {
  final columns = await db.rawQuery('PRAGMA table_info($table);');
  return columns.any((row) => row['name'] == column);
}

/// 列存在且声明为 NOT NULL（PRAGMA table_info.notnull == 1）。列缺失返回 false。
Future<bool> _columnIsNotNull(Database db, String table, String column) async {
  final columns = await db.rawQuery('PRAGMA table_info($table);');
  for (final row in columns) {
    if (row['name'] == column) return ((row['notnull'] as int?) ?? 0) == 1;
  }
  return false;
}
