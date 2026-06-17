import 'package:asset_ledger/features/account/model/account_view_model.dart';
import 'package:asset_ledger/l10n/gen/app_localizations.dart';
import 'package:asset_ledger/patterns/account/external_work_detail_sheet_pattern.dart';
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

    // 应收单价（客户侧）显示真实值。
    final rate = tester.widget<Text>(
      find.byKey(const Key('external-detail-customer-rate')),
    );
    expect(rate.data, '¥250');
    // 应收项目款、毛利、应付总额、已付、待付均显真实值。
    expect(find.text('¥2500'), findsOneWidget); // 应收项目款
    expect(find.text('¥700'), findsOneWidget); // 毛利
    expect(find.text('应付总额 ¥1800'), findsOneWidget);
    expect(find.text('¥0'), findsOneWidget); // 已付占位
    expect(find.text('待付 ¥1800'), findsOneWidget);
    // 支付记录占位。
    expect(find.text('支付记录'), findsOneWidget);
    expect(find.text('支付记录即将上线'), findsOneWidget);
    expect(find.text('+ 新增应付'), findsOneWidget);
  });

  testWidgets('shows pending placeholders when customer rate is unset', (
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

    final rate = tester.widget<Text>(
      find.byKey(const Key('external-detail-customer-rate')),
    );
    expect(rate.data, '待设置');
    expect(find.text('待计算'), findsOneWidget); // 毛利待计算
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

    expect(find.text('Receivable rate'), findsOneWidget);
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
  return AccountExternalWorkProjectVM(
    importBatchId: 'b1',
    displayName: '余远 · 五里山',
    sourceDisplayName: '余远',
    siteSummary: '五里山',
    minYmd: 20260617,
    payableFen: 180000,
    receivableFen: 250000,
    remainingFen: 250000,
    profitFen: 70000,
    recordCount: 1,
    totalHoursMilli: 10000,
    customerUnitPriceFen: customerUnitPriceFen,
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
