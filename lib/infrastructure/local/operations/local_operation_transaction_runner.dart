import '../../../core/operations/operation_transaction_runner.dart';
import '../../../data/db/database.dart';

class LocalOperationTransactionRunner implements OperationTransactionRunner {
  const LocalOperationTransactionRunner();

  @override
  Future<T> run<T>(
    Future<T> Function(OperationDatabaseExecutor executor) action,
  ) {
    return AppDatabase.inTransaction(action);
  }
}
