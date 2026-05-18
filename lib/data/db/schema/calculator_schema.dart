import 'package:sqflite/sqflite.dart';

/// timing_calculation_history（外键级联指向 timing_records）。
class CalculatorSchema {
  static Future<void> create(Database db) async {
    await db.execute('''
      CREATE TABLE timing_calculation_history (
        id TEXT PRIMARY KEY,
        timing_record_id INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        expression TEXT NOT NULL,
        result REAL NOT NULL,
        ticket_count INTEGER NOT NULL,
        FOREIGN KEY (timing_record_id)
          REFERENCES timing_records(id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE INDEX idx_timing_calc_record_id
      ON timing_calculation_history(timing_record_id);
    ''');
  }
}
