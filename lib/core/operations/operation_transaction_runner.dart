import 'package:sqflite/sqflite.dart';

typedef OperationDatabaseExecutor = DatabaseExecutor;

abstract class OperationTransactionRunner {
  Future<T> run<T>(
    Future<T> Function(OperationDatabaseExecutor executor) action,
  );
}
