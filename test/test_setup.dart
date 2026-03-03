import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void configureTestDatabase() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}
