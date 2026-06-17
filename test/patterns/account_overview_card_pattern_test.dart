import 'package:asset_ledger/features/account/model/account_view_model.dart';
import 'package:asset_ledger/l10n/gen/app_localizations.dart';
import 'package:asset_ledger/patterns/account/account_overview_card_pattern.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows compact net received label with unhighlighted amount', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 390,
              child: AccountOverviewCard(
                vm: AccountOverviewVm(
                  totalReceivable: 1000,
                  totalReceived: 100,
                  totalRemaining: 900,
                  totalRatio: 0.1,
                  netCashReceived: -2000,
                  deviceReceivables: const [
                    AccountDeviceReceivable(
                      deviceId: 1,
                      name: 'HITACHI 1#',
                      amount: 1000,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('已收(净)'), findsOneWidget);
    expect(find.text('-¥2000'), findsOneWidget);

    final label = tester.widget<Text>(find.text('已收(净)'));
    final amount = tester.widget<Text>(find.text('-¥2000'));
    expect(amount.style?.color, label.style?.color);
    expect(amount.style?.fontSize, label.style?.fontSize);
    expect(amount.style?.fontWeight, label.style?.fontWeight);
  });

  testWidgets('shows external receivable hint below total receivable', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 390,
              child: AccountOverviewCard(
                vm: AccountOverviewVm(
                  totalReceivable: 3000,
                  totalReceived: 700,
                  totalRemaining: 2300,
                  totalRatio: 700 / 3000,
                  netCashReceived: 700,
                  externalCustomerReceivableFen: 200000,
                  deviceReceivables: const [
                    AccountDeviceReceivable(
                      deviceId: 1,
                      name: 'HITACHI 1#',
                      amount: 1000,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('其中:外协应收 ¥2000'), findsOneWidget);
    expect(find.textContaining('其中：'), findsNothing);
    expect(find.textContaining('其中: 外协应收'), findsNothing);

    final totalValueRight = tester.getTopRight(find.text('¥3000')).dx;
    final externalHintRight = tester.getTopRight(find.text('其中:外协应收 ¥2000')).dx;
    expect((externalHintRight - totalValueRight).abs(), lessThan(1));
  });

  testWidgets(
    'hides external receivable hint when external receivable is zero',
    (tester) async {
      await tester.pumpWidget(
        _localizedApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 390,
                child: AccountOverviewCard(
                  vm: AccountOverviewVm(
                    totalReceivable: 1000,
                    totalReceived: 100,
                    totalRemaining: 900,
                    totalRatio: 0.1,
                    netCashReceived: 100,
                    externalCustomerReceivableFen: 0,
                    deviceReceivables: const [],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('其中:'), findsNothing);
      expect(find.textContaining('外协应收'), findsNothing);
    },
  );
}

Widget _localizedApp({required Widget home}) {
  return MaterialApp(
    locale: const Locale('zh'),
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
