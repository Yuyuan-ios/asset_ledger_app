import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/main.dart' as app;

void main() {
  final binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized()
          as IntegrationTestWidgetsFlutterBinding;

  Future<void> seedLiveData() async {
    await AppDatabase.resetForTest();
    final db = await AppDatabase.database;

    await db.transaction((txn) async {
      for (final table in [
        'account_payments',
        'project_device_rates',
        'fuel_logs',
        'timing_records',
        'maintenance_records',
        'devices',
      ]) {
        await txn.delete(table);
      }
      await txn.delete('sqlite_sequence');

      Future<void> insertAll(String table, List<Map<String, Object?>> rows) async {
        for (final row in rows) {
          await txn.insert(
            table,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      await insertAll('devices', [
        {
          'id': 1,
          'name': 'SANY 1#',
          'brand': 'SANY',
          'model': null,
          'default_unit_price': 120.0,
          'breaking_unit_price': 200.0,
          'base_meter_hours': 0.0,
          'is_active': 1,
          'custom_avatar_path': null,
          'equipment_type': 'excavator',
        },
        {
          'id': 2,
          'name': 'SANY 2#',
          'brand': 'SANY',
          'model': null,
          'default_unit_price': 180.0,
          'breaking_unit_price': null,
          'base_meter_hours': 0.0,
          'is_active': 1,
          'custom_avatar_path': null,
          'equipment_type': 'excavator',
        },
        {
          'id': 3,
          'name': 'HITACHI 1#',
          'brand': 'Hitachi',
          'model': null,
          'default_unit_price': 180.0,
          'breaking_unit_price': null,
          'base_meter_hours': 0.0,
          'is_active': 1,
          'custom_avatar_path': null,
          'equipment_type': 'excavator',
        },
      ]);

      await insertAll('timing_records', [
        {
          'id': 1,
          'device_id': 1,
          'start_date': 20260301,
          'contact': '陈七',
          'site': '修文水厂',
          'type': 'hours',
          'start_meter': 2000.0,
          'end_meter': 2004.0,
          'hours': 4.0,
          'income': 480.0,
          'exclude_from_fuel_eff': 0,
          'is_breaking': 0,
        },
        {
          'id': 2,
          'device_id': 1,
          'start_date': 20260308,
          'contact': '李四',
          'site': '万华',
          'type': 'hours',
          'start_meter': 2004.0,
          'end_meter': 2096.0,
          'hours': 92.0,
          'income': 11040.0,
          'exclude_from_fuel_eff': 0,
          'is_breaking': 0,
        },
        {
          'id': 3,
          'device_id': 2,
          'start_date': 20260308,
          'contact': '李四',
          'site': '万华',
          'type': 'hours',
          'start_meter': 3000.0,
          'end_meter': 3045.0,
          'hours': 45.0,
          'income': 8100.0,
          'exclude_from_fuel_eff': 0,
          'is_breaking': 0,
        },
        {
          'id': 4,
          'device_id': 3,
          'start_date': 20260302,
          'contact': '王五',
          'site': '通威',
          'type': 'hours',
          'start_meter': 4000.0,
          'end_meter': 4070.0,
          'hours': 70.0,
          'income': 12600.0,
          'exclude_from_fuel_eff': 0,
          'is_breaking': 0,
        },
        {
          'id': 5,
          'device_id': 1,
          'start_date': 20260317,
          'contact': '赵六',
          'site': '尚义',
          'type': 'hours',
          'start_meter': 2096.0,
          'end_meter': 2102.0,
          'hours': 6.0,
          'income': 1200.0,
          'exclude_from_fuel_eff': 0,
          'is_breaking': 1,
        },
        {
          'id': 6,
          'device_id': 1,
          'start_date': 20260317,
          'contact': '赵六',
          'site': '尚义',
          'type': 'hours',
          'start_meter': 2102.0,
          'end_meter': 2105.0,
          'hours': 3.0,
          'income': 360.0,
          'exclude_from_fuel_eff': 0,
          'is_breaking': 0,
        },
      ]);

      await insertAll('fuel_logs', [
        {
          'id': 1,
          'device_id': 1,
          'date': 20260301,
          'supplier': '中石油',
          'liters': 139.0,
          'cost': 829.83,
        },
        {
          'id': 2,
          'device_id': 1,
          'date': 20260303,
          'supplier': '中石油',
          'liters': 110.0,
          'cost': 774.0,
        },
        {
          'id': 3,
          'device_id': 1,
          'date': 20260305,
          'supplier': '中石油',
          'liters': 126.0,
          'cost': 882.0,
        },
        {
          'id': 4,
          'device_id': 2,
          'date': 20260308,
          'supplier': '中石油',
          'liters': 241.0,
          'cost': 1662.8,
        },
        {
          'id': 5,
          'device_id': 3,
          'date': 20260308,
          'supplier': '中石油',
          'liters': 231.0,
          'cost': 1570.0,
        },
        {
          'id': 6,
          'device_id': 3,
          'date': 20260313,
          'supplier': '中石油',
          'liters': 245.0,
          'cost': 1641.0,
        },
      ]);

      await insertAll('project_device_rates', [
        {
          'project_key': '赵六||尚义',
          'device_id': 1,
          'is_breaking': 0,
          'rate': 120.0,
        },
        {
          'project_key': '赵六||尚义',
          'device_id': 1,
          'is_breaking': 1,
          'rate': 200.0,
        },
        {
          'project_key': '李四||万华',
          'device_id': 1,
          'is_breaking': 0,
          'rate': 120.0,
        },
        {
          'project_key': '李四||万华',
          'device_id': 2,
          'is_breaking': 0,
          'rate': 180.0,
        },
        {
          'project_key': '王五||通威',
          'device_id': 3,
          'is_breaking': 0,
          'rate': 180.0,
        },
        {
          'project_key': '陈七||修文水厂',
          'device_id': 1,
          'is_breaking': 0,
          'rate': 120.0,
        },
      ]);

      await insertAll('account_payments', [
        {
          'id': 1,
          'project_key': '赵六||尚义',
          'ymd': 20260317,
          'amount': 1000.0,
          'note': null,
        },
        {
          'id': 2,
          'project_key': '李四||万华',
          'ymd': 20260310,
          'amount': 2000.0,
          'note': null,
        },
        {
          'id': 3,
          'project_key': '王五||通威',
          'ymd': 20260309,
          'amount': 5000.0,
          'note': null,
        },
      ]);
    });
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.bySemanticsLabel(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('captures app store source screenshots from live data', (
    WidgetTester tester,
  ) async {
    await seedLiveData();
    app.main();
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();

    await openTab(tester, '计时');
    await binding.takeScreenshot('timing-live');

    await openTab(tester, '燃油');
    await binding.takeScreenshot('fuel-live');

    await openTab(tester, '账户');
    await binding.takeScreenshot('account-live');
  });
}
