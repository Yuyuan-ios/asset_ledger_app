import 'package:asset_ledger/app/app.dart';
import 'package:asset_ledger/app/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';

void main() {
  patrolTest(
    'opens device page and device editor',
    ($) async {
      final bundle = AppProviders.build();

      await $.pumpWidget(
        MultiProvider(
          providers: bundle.providers,
          child: const AssetLedgerApp(),
        ),
      );
      await $.pumpAndSettle();

      await $.tester.tap(find.bySemanticsLabel('设备'));
      await $.pumpAndSettle();

      expect(find.textContaining('设备（'), findsOneWidget);
      expect(find.text('暂无设备，点右下角 + 新增'), findsOneWidget);

      await $.tester.tap(find.byIcon(Icons.add));
      await $.pumpAndSettle();

      expect(find.text('新增设备'), findsOneWidget);
      expect(find.text('未选择品牌（头像）'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
    },
    config: const PatrolTesterConfig(
      visibleTimeout: Duration(seconds: 10),
    ),
  );
}
