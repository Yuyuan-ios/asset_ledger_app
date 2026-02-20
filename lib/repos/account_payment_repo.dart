import '../db/db.dart';
import '../models/account_payment.dart';

// =====================================================================
// ============================== AccountPaymentRepo ==============================
// =====================================================================
//
// 纯 CRUD：不写业务口径
// =====================================================================

class AccountPaymentRepo {
  const AccountPaymentRepo._();

  static const String table = 'account_payments';

  static Future<List<AccountPayment>> listAll() async {
    final db = await AppDatabase.database;
    final rows = await db.query(table, orderBy: 'ymd DESC, id DESC');
    return rows.map((e) => AccountPayment.fromMap(e)).toList();
  }

  static Future<int> insert(AccountPayment p) async {
    final db = await AppDatabase.database;
    return db.insert(table, p.toMap());
  }

  static Future<int> update(AccountPayment p) async {
    final db = await AppDatabase.database;
    return db.update(table, p.toMap(), where: 'id = ?', whereArgs: [p.id]);
  }

  static Future<int> deleteById(int id) async {
    final db = await AppDatabase.database;
    return db.delete(table, where: 'id = ?', whereArgs: [id]);
  }
}
