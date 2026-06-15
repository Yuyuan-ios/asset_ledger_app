import 'package:sqflite/sqflite.dart';

/// devices / fuel_logs / maintenance_records（无外键的设备车队相关表）。
class FleetSchema {
  static Future<void> create(Database db) async {
    await db.execute('''
      CREATE TABLE devices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        brand TEXT NOT NULL,
        model TEXT,
        default_unit_price REAL NOT NULL,
        breaking_unit_price REAL,
        default_unit_price_fen INTEGER NOT NULL,
        breaking_unit_price_fen INTEGER,
        base_meter_hours REAL NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        custom_avatar_path TEXT,
        equipment_type TEXT NOT NULL DEFAULT 'excavator'
      );
    ''');

    await db.execute('''
      CREATE TABLE fuel_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id INTEGER NOT NULL,
        date INTEGER NOT NULL,
        supplier TEXT NOT NULL,
        liters REAL NOT NULL,
        cost REAL NOT NULL,
        cost_fen INTEGER NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE maintenance_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id INTEGER,
        ymd INTEGER NOT NULL,
        item TEXT NOT NULL,
        amount REAL NOT NULL,
        amount_fen INTEGER NOT NULL,
        note TEXT
      );
    ''');
  }
}
