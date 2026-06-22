import 'package:asset_ledger/features/device/domain/services/lifecycle_payback_calculator.dart';
import 'package:asset_ledger/features/device/view/lifecycle_amount_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('showLifecycleAmountSheet', () {
    testWidgets('returns the entered amounts when saved', (tester) async {
      LifecyclePaybackAmounts? saved;
      var popped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  saved = await showLifecycleAmountSheet(
                    context: context,
                    deviceName: 'SANY 1#',
                    netReceivedFen: 234724,
                    initialCostFen: null,
                    estimatedResidualFen: null,
                  );
                  popped = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('设置设备生命周期金额'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('更新'), findsOneWidget);
      expect(find.text('保存并更新卡片'), findsNothing);

      // First field is initial cost, second is estimated residual.
      await tester.enterText(find.byType(TextField).at(0), '5000');
      await tester.enterText(find.byType(TextField).at(1), '1200');
      await tester.pump();

      await tester.tap(find.text('更新'));
      await tester.pumpAndSettle();

      expect(popped, isTrue);
      expect(saved, isNotNull);
      expect(saved!.initialCostFen, 500000);
      expect(saved!.estimatedResidualFen, 120000);
    });

    testWidgets('returns null when dismissed without saving', (tester) async {
      LifecyclePaybackAmounts? saved = const LifecyclePaybackAmounts(
        initialCostFen: 1,
      );
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  saved = await showLifecycleAmountSheet(
                    context: context,
                    deviceName: 'SANY 1#',
                    netReceivedFen: 234724,
                    initialCostFen: 250000,
                    estimatedResidualFen: 100000,
                  );
                  completed = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('设置设备生命周期金额'), findsOneWidget);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(saved, isNull);
    });
  });
}
