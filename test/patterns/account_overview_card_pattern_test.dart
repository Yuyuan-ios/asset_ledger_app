import 'package:asset_ledger/features/account/model/account_view_model.dart';
import 'package:asset_ledger/patterns/account/account_overview_card_pattern.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows compact net received label with unhighlighted amount', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
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
}
