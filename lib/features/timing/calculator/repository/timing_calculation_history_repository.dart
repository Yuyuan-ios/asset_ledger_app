import 'package:sqflite/sqflite.dart';

import '../../../../data/db/database.dart';
import '../model/timing_calculation_history.dart';

abstract class TimingCalculationHistoryRepository {
  Future<List<TimingCalculationHistory>> findByTimingRecordId(
    int timingRecordId,
  );

  Future<void> insertMany(
    int timingRecordId,
    List<TimingCalculationHistory> histories,
  );

  Future<void> deleteByTimingRecordId(int timingRecordId);
}

class SqfliteTimingCalculationHistoryRepository
    implements TimingCalculationHistoryRepository {
  static const String table = 'timing_calculation_history';

  @override
  Future<List<TimingCalculationHistory>> findByTimingRecordId(
    int timingRecordId,
  ) async {
    final db = await AppDatabase.database;
    final rows = await db.query(
      table,
      where: 'timing_record_id = ?',
      whereArgs: [timingRecordId],
      orderBy: 'created_at DESC',
    );
    return rows.map(TimingCalculationHistory.fromMap).toList();
  }

  @override
  Future<void> insertMany(
    int timingRecordId,
    List<TimingCalculationHistory> histories,
  ) async {
    if (histories.isEmpty) return;
    final db = await AppDatabase.database;
    await insertManyWithExecutor(db, timingRecordId, histories);
  }

  Future<void> insertManyWithExecutor(
    DatabaseExecutor executor,
    int timingRecordId,
    List<TimingCalculationHistory> histories,
  ) async {
    if (histories.isEmpty) return;

    final batch = executor.batch();
    for (final history in histories) {
      batch.insert(
        table,
        history.copyWith(timingRecordId: timingRecordId).toMap(),
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> deleteByTimingRecordId(int timingRecordId) async {
    final db = await AppDatabase.database;
    await deleteByTimingRecordIdWithExecutor(db, timingRecordId);
  }

  Future<void> deleteByTimingRecordIdWithExecutor(
    DatabaseExecutor executor,
    int timingRecordId,
  ) async {
    await executor.delete(
      table,
      where: 'timing_record_id = ?',
      whereArgs: [timingRecordId],
    );
  }
}
