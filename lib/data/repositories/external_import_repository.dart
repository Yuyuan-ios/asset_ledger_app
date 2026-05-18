import 'package:sqflite/sqflite.dart';

import '../db/database.dart';
import '../models/external_import_batch.dart';

abstract class ExternalImportRepository {
  Future<void> insertBatch(ExternalImportBatch batch);

  Future<ExternalImportBatch?> findBatchById(String id);

  Future<List<ExternalImportBatch>> listBatches();
}

class SqfliteExternalImportRepository implements ExternalImportRepository {
  static const String table = 'external_import_batches';

  @override
  Future<void> insertBatch(ExternalImportBatch batch) async {
    final db = await AppDatabase.database;
    await insertBatchWithExecutor(db, batch);
  }

  @override
  Future<ExternalImportBatch?> findBatchById(String id) async {
    final normalized = id.trim();
    if (normalized.isEmpty) return null;
    final db = await AppDatabase.database;
    final rows = await db.query(
      table,
      where: 'id = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ExternalImportBatch.fromMap(rows.single);
  }

  @override
  Future<List<ExternalImportBatch>> listBatches() async {
    final db = await AppDatabase.database;
    final rows = await db.query(table, orderBy: 'imported_at DESC, id ASC');
    return rows.map(ExternalImportBatch.fromMap).toList();
  }

  static Future<void> insertBatchWithExecutor(
    DatabaseExecutor executor,
    ExternalImportBatch batch,
  ) async {
    await executor.insert(table, batch.toMap());
  }
}
