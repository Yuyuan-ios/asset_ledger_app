import 'package:asset_ledger/features/timing/model/timing_chart_data.dart';
import 'package:asset_ledger/l10n/gen/app_localizations.dart';
import 'package:asset_ledger/patterns/timing/card_main_chart_pattern.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'keeps chart legend labels while showing net income value as net intake',
    (tester) async {
      await tester.pumpWidget(
        _localizedChartHost(
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
      );

      expect(find.text('2026年'), findsOneWidget);
      expect(find.text('收入'), findsOneWidget);
      expect(find.text('支出'), findsOneWidget);
      expect(find.text('净入¥37218'), findsOneWidget);
      expect(find.text('支出¥5076'), findsOneWidget);
      expect(find.text('收入¥37218'), findsNothing);
      expect(find.text('净收入¥37218'), findsNothing);
      expect(find.text('¥42294'), findsNothing);
    },
  );

  testWidgets('localizes chart labels in English', (tester) async {
    await tester.pumpWidget(
      _localizedChartHost(
        locale: const Locale('en'),
        data: TimingChartData(
          year: 2026,
          targetMonth: 12,
          monthLabels: const [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec',
          ],
          incomeBars: List<double>.filled(12, 10),
          expenseBars: List<double>.filled(12, 5),
          totalIncomeText: r'$42,294',
          netIncomeText: r'$37,218',
          totalExpenseText: r'$5,076',
        ),
      ),
    );

    expect(find.text('2026'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text(r'Net$37,218'), findsOneWidget);
    expect(find.text(r'Expense$5,076'), findsOneWidget);
    expect(find.text('收入'), findsNothing);
    expect(find.text('净入'), findsNothing);
    expect(find.text('2026年'), findsNothing);
  });
}

Widget _localizedChartHost({
  required TimingChartData data,
  Locale locale = const Locale('zh'),
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: CardMainChart(data: data)),
  );
}
