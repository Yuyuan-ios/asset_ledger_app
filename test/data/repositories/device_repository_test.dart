import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/repositories/device_repository.dart';
import 'package:asset_ledger/features/device/state/device_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  setUp(() async {
    await AppDatabase.resetForTest();
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  test(
    'DeviceStore lifecycle payback update persists through sqflite',
    () async {
      await _openCurrentInMemoryDb();
      final repository = SqfliteDeviceRepository();
      final deviceId = await repository.insert(
        Device(
          name: 'SANY 1#',
          brand: 'SANY',
          model: 'SY75',
          defaultUnitPrice: 380,
          baseMeterHours: 12.5,
          customAvatarPath: '/tmp/avatar.png',
          equipmentType: EquipmentType.loader,
        ),
      );
      final store = DeviceStore(repository);
      await store.loadAll();

      await store.updateLifecyclePaybackAmounts(
        deviceId: deviceId,
        lifecycleInitialCostFen: 1500000,
        lifecycleEstimatedResidualFen: 230000,
      );

      final reread = (await repository.getByIdOrNull(deviceId))!;
      expect(reread.lifecycleInitialCostFen, 1500000);
      expect(reread.lifecycleEstimatedResidualFen, 230000);
      expect(reread.name, 'SANY 1#');
      expect(reread.brand, 'SANY');
      expect(reread.model, 'SY75');
      expect(reread.defaultUnitPriceFen, 38000);
      expect(reread.baseMeterHours, 12.5);
      expect(reread.customAvatarPath, '/tmp/avatar.png');
      expect(reread.equipmentType, EquipmentType.loader);

      await store.updateLifecyclePaybackAmounts(
        deviceId: deviceId,
        lifecycleInitialCostFen: null,
        lifecycleEstimatedResidualFen: 0,
      );

      final cleared = (await repository.getByIdOrNull(deviceId))!;
      expect(cleared.lifecycleInitialCostFen, isNull);
      expect(cleared.lifecycleEstimatedResidualFen, 0);
      expect(cleared.defaultUnitPriceFen, 38000);
    },
  );
}

Future<Database> _openCurrentInMemoryDb() {
  AppDatabase.debugInitDbOverride = () {
    return openDatabase(
      inMemoryDatabasePath,
      version: AppDatabase.schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, _) => DbSchema.create(db),
    );
  };
  return AppDatabase.database;
}
