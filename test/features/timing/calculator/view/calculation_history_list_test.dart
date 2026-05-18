import 'package:asset_ledger/features/timing/calculator/model/staged_timing_calculation_history.dart';
import 'package:asset_ledger/features/timing/calculator/model/timing_calculation_history.dart';
import 'package:asset_ledger/features/timing/calculator/view/calculation_history_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows existing and staged histories newest first', (
    WidgetTester tester,
  ) async {
    final stagedHistory = StagedTimingCalculationHistory(
      createdAt: DateTime.utc(2026, 5, 14, 15, 32),
      expression: '8+8.2+8.3+8.1',
      result: 32.6,
      ticketCount: 4,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 320,
            child: CalculationHistoryList(
              existingHistories: [
                TimingCalculationHistory(
                  id: 'saved',
                  timingRecordId: 7,
                  createdAt: DateTime.utc(2026, 5, 13, 18, 20),
                  expression: '8+8.2+7.8',
                  result: 24.0,
                  ticketCount: 3,
                ),
              ],
              stagedHistories: [stagedHistory],
              latestAppliedHistory: stagedHistory,
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('[本次]'), findsNothing);
    expect(find.textContaining('[已保存]'), findsNothing);
    expect(find.text('2026.05.14 15:32 | 票据 4 张'), findsOneWidget);
    expect(find.text('2026.05.13 18:20 | 票据 3 张'), findsOneWidget);
    expect(
      find.textContaining('8 + 8.2 + 8.3 + 8.1 = 32.6 h', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('8 + 8.2 + 7.8 = 24.0 h', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('已填入工时'), findsOneWidget);

    final stagedTop = tester
        .getTopLeft(find.text('2026.05.14 15:32 | 票据 4 张'))
        .dy;
    final existingTop = tester
        .getTopLeft(find.text('2026.05.13 18:20 | 票据 3 张'))
        .dy;
    expect(stagedTop, lessThan(existingTop));
  });
}
