import 'package:asset_ledger/features/timing/calculator/model/staged_timing_calculation_history.dart';
import 'package:asset_ledger/data/models/timing_calculation_history.dart';
import 'package:asset_ledger/features/timing/calculator/view/work_hour_calculator_sheet.dart';
import 'package:asset_ledger/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpSheet(
    WidgetTester tester, {
    Locale locale = const Locale('zh'),
    List<TimingCalculationHistory> existingHistories = const [],
    ValueChanged<List<StagedTimingCalculationHistory>>? onHistoriesChanged,
  }) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh'), Locale('en')],
        home: Scaffold(
          body: WorkHourCalculatorSheet(
            initialHours: null,
            existingHistories: existingHistories,
            initialStagedHistories: const [],
            onResultApplied: (_) {},
            onHistoriesChanged: (histories) {
              onHistoriesChanged?.call(histories);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapTextKey(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(OutlinedButton, label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('shows existing histories and appends staged histories after =', (
    WidgetTester tester,
  ) async {
    List<StagedTimingCalculationHistory>? latestStagedHistories;
    await pumpSheet(
      tester,
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
      onHistoriesChanged: (histories) {
        latestStagedHistories = histories;
      },
    );

    expect(find.textContaining('[已保存]'), findsNothing);
    expect(find.text('未计算'), findsOneWidget);
    expect(find.text('工时计算式'), findsOneWidget);
    expect(find.text('填入'), findsOneWidget);
    expect(find.text('2026.05.13 18:20 | 票据 3 张'), findsOneWidget);
    expect(
      find.textContaining('8 + 8.2 + 7.8 = 24.0 h', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('计算依据'), findsNothing);
    expect(find.text('工时计算依据'), findsNothing);
    expect(find.byTooltip('关闭'), findsNothing);
    expect(find.widgetWithText(TextButton, '关闭'), findsNothing);
    expect(find.widgetWithText(FilledButton, '完成'), findsNothing);

    final equalLeft = tester
        .getTopLeft(find.widgetWithText(FilledButton, '='))
        .dx;
    final zeroLeft = tester
        .getTopLeft(find.widgetWithText(OutlinedButton, '0'))
        .dx;
    final decimalLeft = tester
        .getTopLeft(find.widgetWithText(OutlinedButton, '.'))
        .dx;
    expect(equalLeft, lessThan(zeroLeft));
    expect(zeroLeft, lessThan(decimalLeft));

    await tapTextKey(tester, '8');
    await tapTextKey(tester, '+');
    await tapTextKey(tester, '8');
    await tester.tap(find.widgetWithText(FilledButton, '=').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('[本次]'), findsNothing);
    expect(find.text('结果 16.0 h'), findsOneWidget);
    expect(find.text('已填入工时'), findsOneWidget);
    expect(
      find.textContaining('8 + 8 = 16.0 h', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('8 + 8.2 + 7.8 = 24.0 h', findRichText: true),
      findsOneWidget,
    );

    await tapTextKey(tester, '+');
    await tapTextKey(tester, '4');
    await tester.tap(find.widgetWithText(FilledButton, '=').last);
    await tester.pumpAndSettle();

    expect(find.text('已填入工时'), findsOneWidget);
    expect(
      find.textContaining('16.0 + 4 = 20.0 h', findRichText: true),
      findsOneWidget,
    );
    expect(latestStagedHistories, hasLength(2));
  });

  testWidgets('renders localized en calculator labels', (
    WidgetTester tester,
  ) async {
    await pumpSheet(tester, locale: const Locale('en'));

    expect(find.text('Not calculated'), findsOneWidget);
    expect(find.text('Work hour expression'), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);

    await tapTextKey(tester, '8');
    await tapTextKey(tester, '+');
    await tapTextKey(tester, '8');
    await tester.tap(find.widgetWithText(FilledButton, '=').last);
    await tester.pumpAndSettle();

    expect(find.text('Result 16.0 h'), findsOneWidget);
    expect(find.text('Applied to hours'), findsOneWidget);
  });
}
