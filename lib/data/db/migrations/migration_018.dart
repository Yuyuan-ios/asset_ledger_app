part of '../db_migrations.dart';

class Migration018 {
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 18) {
      await ensureMoneyFenSchema(db);
    }
  }

  static Future<void> ensureMoneyFenSchema(Database db) async {
    if (await _tableExists(db, 'account_payments')) {
      await _addColumnIfMissing(
        db,
        'account_payments',
        'amount_fen',
        'INTEGER',
      );
      await _addColumnIfMissing(
        db,
        'account_payments',
        'merge_batch_total_amount_fen',
        'INTEGER',
      );
      await db.execute('''
        UPDATE account_payments
        SET amount_fen = CAST(ROUND(COALESCE(amount, 0) * 100.0) AS INTEGER)
        WHERE amount_fen IS NULL;
      ''');
      await db.execute('''
        UPDATE account_payments
        SET merge_batch_total_amount_fen =
          CAST(ROUND(merge_batch_total_amount * 100.0) AS INTEGER)
        WHERE merge_batch_total_amount_fen IS NULL
          AND merge_batch_total_amount IS NOT NULL;
      ''');
    }

    if (await _tableExists(db, 'project_write_offs')) {
      await _addColumnIfMissing(
        db,
        'project_write_offs',
        'amount_fen',
        'INTEGER',
      );
      if (await _columnExists(db, 'project_write_offs', 'amount')) {
        await db.execute('''
          UPDATE project_write_offs
          SET amount_fen = CAST(ROUND(COALESCE(amount, 0) * 100.0) AS INTEGER)
          WHERE amount_fen IS NULL;
        ''');
      }
    }
  }
}
