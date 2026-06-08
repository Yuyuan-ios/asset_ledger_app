import 'package:asset_ledger/features/timing/model/timing_chart_data.dart';
import 'package:asset_ledger/patterns/timing/card_main_chart_pattern.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'keeps chart legend labels while showing net income value as net intake',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CardMainChart(
              data: TimingChartData(
                year: 2026,
                targetMonth: 12,
                monthLabels: const [
                  '1月',
                  '2月',
                  '3月',
                  '4月',
                  '5月',
                  '6月',
                  '7月',
                  '8月',
                  '9月',
                  '10月',
                  '11月',
                  '12月',
                ],
                incomeBars: List<double>.filled(12, 10),
                expenseBars: List<double>.filled(12, 5),
                totalIncomeText: '¥42294',
                netIncomeText: '¥37218',
                totalExpenseText: '¥5076',
              ),
            ),
          ),
        ),
      );

      expect(find.text('收入'), findsOneWidget);
      expect(find.text('支出'), findsOneWidget);
      expect(find.text('净入¥37218'), findsOneWidget);
      expect(find.text('支出¥5076'), findsOneWidget);
      expect(find.text('收入¥37218'), findsNothing);
      expect(find.text('净收入¥37218'), findsNothing);
      expect(find.text('¥42294'), findsNothing);
    },
  );
}
