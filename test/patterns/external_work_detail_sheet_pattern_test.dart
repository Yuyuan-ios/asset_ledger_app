import 'package:asset_ledger/features/account/model/account_view_model.dart';
import 'package:asset_ledger/l10n/gen/app_localizations.dart';
import 'package:asset_ledger/patterns/account/external_work_detail_sheet_pattern.dart';
import 'package:asset_ledger/tokens/mapper/color_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows customer rate, receivable, profit and payable totals', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(
        home: _sheetHost(
          ExternalWorkDetailSheet(
            project: _vm(customerUnitPriceFen: 25000),
            onEditCustomerRate: () {},
          ),
        ),
      ),
    );

    // 应收项目款、应付项目款、毛利、应付总额、已付、待付均显真实值。
    expect(find.text('应收项目款'), findsOneWidget);
    expect(find.text('单价¥250'), findsOneWidget);
    expect(find.text('应付项目款(应付单价¥180/h)'), findsOneWidget);
    expect(find.text('¥2500'), findsOneWidget); // 应收项目款
    expect(find.text('¥1800'), findsOneWidget); // 应付项目款
    expect(find.text('¥700'), findsOneWidget); // 毛利
    final receivableText = tester.widget<Text>(find.text('应收项目款'));
    final receivableRateText = tester.widget<Text>(find.text('单价¥250'));
    expect(receivableText.style?.color, SheetColors.textPrimary);
    expect(receivableRateText.style?.color, SheetColors.textPrimary);
    expect(find.text('应付总额 ¥1800'), findsOneWidget);
    expect(find.text('¥0'), findsOneWidget); // 已付占位
    expect(find.text('待付 ¥1800'), findsOneWidget);
    // 支付记录占位。
    expect(find.text('支付记录'), findsOneWidget);
    expect(find.text('支付记录即将上线'), findsOneWidget);
    expect(find.text('+ 新增应付'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '+ 新增应付'), findsNothing);
    expect(find.widgetWithText(InkWell, '+ 新增应付'), findsOneWidget);
  });

  testWidgets('falls back to payable rate when customer rate is unset', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(
        home: _sheetHost(
          ExternalWorkDetailSheet(
            project: _vm(customerUnitPriceFen: null),
            onEditCustomerRate: () {},
          ),
        ),
      ),
    );

    expect(find.text('应收项目款'), findsOneWidget);
    expect(find.text('单价¥180'), findsOneWidget);
    expect(find.text('应付项目款(应付单价¥180/h)'), findsOneWidget);
    expect(find.text('¥1800'), findsWidgets);
    expect(find.text('¥0'), findsNWidgets(2)); // 毛利默认应收 - 应付，已付占位
    expect(find.text('待设置'), findsNothing);
    expect(find.text('待计算'), findsNothing);
  });

  testWidgets('edit button fires onEditCustomerRate', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      _localizedApp(
        home: _sheetHost(
          ExternalWorkDetailSheet(
            project: _vm(customerUnitPriceFen: 25000),
            onEditCustomerRate: () => tapped++,
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const Key('external-detail-edit-customer-rate')),
    );
    expect(tapped, 1);
  });

  testWidgets('renders English labels under en locale', (tester) async {
    await tester.pumpWidget(
      _localizedApp(
        locale: const Locale('en'),
        home: _sheetHost(
          ExternalWorkDetailSheet(
            project: _vm(customerUnitPriceFen: 25000),
            onEditCustomerRate: () {},
          ),
        ),
      ),
    );

    expect(find.text('Project receivable'), findsOneWidget);
    expect(find.text('Rate ¥250'), findsOneWidget);
    expect(find.text('Project payable (payable rate ¥180/h)'), findsOneWidget);
    expect(find.text('Payment records'), findsOneWidget);
    expect(find.text('Payment records coming soon'), findsOneWidget);
  });

  testWidgets('rate dialog returns fen on confirm and clear on empty', (
    tester,
  ) async {
    ExternalCustomerRateResult? result;
    await tester.pumpWidget(
      _localizedApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showDialog<ExternalCustomerRateResult>(
                    context: context,
                    builder: (_) => const ExternalCustomerRateDialog(),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    // 输入 250 → 25000 分。
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('external-customer-rate-input')),
      '250',
    );
    await tester.tap(find.byKey(const Key('external-customer-rate-confirm')));
    await tester.pumpAndSettle();
    expect(result?.fen, 25000);

    // 空输入 → 清除（结果非 null，fen 为 null）。
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('external-customer-rate-input')),
      '',
    );
    await tester.tap(find.byKey(const Key('external-customer-rate-confirm')));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.fen, isNull);
  });
}

AccountExternalWorkProjectVM _vm({required int? customerUnitPriceFen}) {
  final receivableFen = customerUnitPriceFen == null ? 180000 : 250000;
  final profitFen = receivableFen - 180000;
  return AccountExternalWorkProjectVM(
    importBatchId: 'b1',
    displayName: '余远 · 五里山',
    sourceDisplayName: '余远',
    siteSummary: '五里山',
    minYmd: 20260617,
    payableFen: 180000,
    receivableFen: receivableFen,
    remainingFen: receivableFen,
    profitFen: profitFen,
    recordCount: 1,
    totalHoursMilli: 10000,
    customerUnitPriceFen: customerUnitPriceFen,
    sourceUnitPriceText: '¥180/h',
  );
}

Widget _sheetHost(Widget child) {
  return Scaffold(
    body: SingleChildScrollView(
      child: Center(child: SizedBox(width: 390, child: child)),
    ),
  );
}

Widget _localizedApp({
  required Widget home,
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
    home: home,
  );
}
