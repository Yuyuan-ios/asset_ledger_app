import 'package:asset_ledger/patterns/device/upgrade_plan_card_pattern.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders annual plan without overflow on narrow widths', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: UpgradePlanCard(
                title: '12元 / 年',
                subtitle1: '请开发者喝两瓶红牛',
                subtitle2: '附带 7天免费试用',
                badge: '省50%',
                emphasized: true,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('省50%'), findsOneWidget);
  });
}
