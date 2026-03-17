import 'package:asset_ledger/app/app.dart';
import 'package:asset_ledger/app/app_bootstrap.dart';
import 'package:asset_ledger/app/app_providers.dart';
import 'package:asset_ledger/data/db/database.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';

class PatrolAppHarness {
  static const config = PatrolTesterConfig(
    visibleTimeout: Duration(seconds: 10),
  );

  static Future<void> pumpFreshApp(PatrolIntegrationTester $) async {
    await _resetDatabase();

    final bundle = AppProviders.build();
    await AppBootstrap.preload(
      deviceStore: bundle.deviceStore,
      timingStore: bundle.timingStore,
      fuelStore: bundle.fuelStore,
      projectRateStore: bundle.projectRateStore,
    );

    await $.pumpWidget(
      MultiProvider(
        providers: bundle.providers,
        child: const AssetLedgerApp(),
      ),
    );
    await $.pumpAndSettle();
  }

  static Future<void> _resetDatabase() async {
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
    });
  }
}
