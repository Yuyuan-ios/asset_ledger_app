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

    expect(find.text('已收-开支'), findsOneWidget);
    expect(find.text('-¥2000'), findsOneWidget);

    final label = tester.widget<Text>(find.text('已收-开支'));
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

  testWidgets('centers no device data message in device section', (
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
                  totalReceivable: 0,
                  totalReceived: 0,
                  totalRemaining: 0,
                  totalRatio: null,
                  netCashReceived: 0,
                  deviceReceivables: const [],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final emptyMessage = find.text('暂无设备数据');
    final divider = find.byType(Divider);
    final donutLabel = find.text('已收-开支');

    expect(emptyMessage, findsOneWidget);
    expect(
      tester.getCenter(emptyMessage).dy,
      greaterThan(tester.getBottomLeft(divider).dy + 40),
    );
    expect(
      (tester.getCenter(emptyMessage).dy - tester.getCenter(donutLabel).dy)
          .abs(),
      lessThan(24),
    );
  });

  testWidgets('places device legend list near upper third in device section', (
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
                  totalReceived: 0,
                  totalRemaining: 3000,
                  totalRatio: 0,
                  netCashReceived: 0,
                  deviceReceivables: const [
                    AccountDeviceReceivable(
                      deviceId: 1,
                      name: 'HITACHI 1#',
                      amount: 1000,
                    ),
                    AccountDeviceReceivable(
                      deviceId: 2,
                      name: 'SANY 2#',
                      amount: 2000,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final divider = find.byType(Divider);
    final donutLabel = find.text('已收-开支');
    final firstDevice = find.text('HITACHI 1#');
    final lastDevice = find.text('SANY 2#');
    final legendCenterY =
        (tester.getTopLeft(firstDevice).dy +
            tester.getBottomLeft(lastDevice).dy) /
        2;

    expect(firstDevice, findsOneWidget);
    expect(lastDevice, findsOneWidget);
    expect(
      tester.getTopLeft(firstDevice).dy,
      greaterThan(tester.getBottomLeft(divider).dy + 12),
    );
    expect(legendCenterY, lessThan(tester.getCenter(donutLabel).dy - 12));
  });
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
