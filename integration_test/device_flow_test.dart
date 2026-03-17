import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'support/asset_ledger_robot.dart';
import 'support/patrol_app_harness.dart';

void main() {
  patrolTest(
    'adds a device and shows it in device management',
    ($) async {
      await PatrolAppHarness.pumpFreshApp($);
      final robot = AssetLedgerRobot($);

      await robot.addDevice();
      expect(find.text('已新增设备'), findsOneWidget);
      expect(find.text('1#挖掘机'), findsOneWidget);
    },
    config: PatrolAppHarness.config,
  );

  patrolTest(
    'adds a rent timing record and shows it in the timing list',
    ($) async {
      await PatrolAppHarness.pumpFreshApp($);
      final robot = AssetLedgerRobot($);
      await robot.addDefaultDevice();

      const contact = 'Beta计时联系人';
      const site = 'Beta测试工地';

      await robot.addRentTimingRecord(
        contact: contact,
        site: site,
        amount: '980',
      );
      expect(find.text('已保存'), findsOneWidget);
      expect(find.text('$contact·$site'), findsOneWidget);
      expect(find.text('¥980'), findsOneWidget);
    },
    config: PatrolAppHarness.config,
  );

  patrolTest(
    'adds a fuel record and shows it in the recent records list',
    ($) async {
      await PatrolAppHarness.pumpFreshApp($);
      final robot = AssetLedgerRobot($);
      await robot.addDefaultDevice();

      const supplier = 'BetaFuel供应商';

      await robot.addFuelRecord(
        supplier: supplier,
        liters: '120',
        amount: '980',
      );
      expect(find.text('已保存'), findsOneWidget);
      expect(find.textContaining(supplier), findsOneWidget);
      expect(find.text('120.0 L'), findsOneWidget);
      expect(find.text('¥980'), findsOneWidget);
    },
    config: PatrolAppHarness.config,
  );
}
