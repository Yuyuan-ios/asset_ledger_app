import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:asset_ledger/features/account/model/account_view_model.dart';
import 'package:asset_ledger/features/account/view/dialogs/account_payment_editor_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const project = AccountProjectVM(
    projectKey: 'ding+site',
    displayName: '丁队 + 五里山',
    minYmd: 20260301,
    deviceIds: [1],
    hoursByDevice: {1: 51.2},
    rentIncomeTotal: 0,
    minRate: 180,
    isMultiDevice: false,
    isMultiMode: false,
    receivable: 9216,
    received: 1000,
    remaining: 8216,
    ratio: 0.1085,
    payments: [
      AccountPayment(
        id: 1,
        projectKey: 'ding+site',
        ymd: 20260302,
        amount: 1000,
      ),
    ],
  );

  testWidgets('opens the sheet date picker when tapping the payment date', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountPaymentEditorDialog(
            project: project,
            allPayments: project.payments,
            editing: AccountPayment(
              id: 1,
              projectKey: 'ding+site',
              ymd: 20260302,
              amount: 1000,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('2026.03.02'));
    await tester.pumpAndSettle();

    expect(find.text('2026年3月'), findsOneWidget);
  });
}
