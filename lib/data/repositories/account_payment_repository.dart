import '../db/database.dart';
import '../models/account_payment.dart';

abstract class AccountPaymentRepository {
  Future<List<AccountPayment>> listAll();

  Future<int> insert(AccountPayment payment);

  Future<int> update(AccountPayment payment);

  Future<int> deleteById(int id);
}

// =====================================================================
// ============================== AccountPaymentRepo ==============================
// =====================================================================
//
// 纯 CRUD：不写业务口径
// =====================================================================

class SqfliteAccountPaymentRepository implements AccountPaymentRepository {

  static const String table = 'account_payments';

  @override
  Future<List<AccountPayment>> listAll() async {
    final db = await AppDatabase.database;
    final rows = await db.query(table, orderBy: 'ymd DESC, id DESC');
    return rows.map((e) => AccountPayment.fromMap(e)).toList();
  }

  @override
  Future<int> insert(AccountPayment p) async {
    final db = await AppDatabase.database;
    return db.insert(table, p.toMap());
  }

  @override
  Future<int> update(AccountPayment p) async {
    final db = await AppDatabase.database;
    return db.update(table, p.toMap(), where: 'id = ?', whereArgs: [p.id]);
  }

  @override
  Future<int> deleteById(int id) async {
    final db = await AppDatabase.database;
    return db.delete(table, where: 'id = ?', whereArgs: [id]);
  }
}
