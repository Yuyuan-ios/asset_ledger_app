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

  testWidgets('new payment returns the stable project id', (
    WidgetTester tester,
  ) async {
    const stableProject = AccountProjectVM(
      projectId: 'project:stable',
      projectKey: '丁队||五里山',
      displayName: '丁队 + 五里山',
      minYmd: 20260301,
      deviceIds: [1],
      hoursByDevice: {1: 51.2},
      rentIncomeTotal: 0,
      minRate: 180,
      isMultiDevice: false,
      isMultiMode: false,
      receivable: 9216,
      received: 0,
      remaining: 9216,
      ratio: 0,
      payments: [],
    );

    AccountPayment? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                result = await showDialog<AccountPayment>(
                  context: context,
                  builder: (_) => const AccountPaymentEditorDialog(
                    project: stableProject,
                    allPayments: [],
                  ),
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '金额（整数）'), '100');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.projectId, 'project:stable');
    expect(result!.projectKey, '丁队||五里山');
    expect(result!.effectiveProjectId, 'project:stable');
  });

  testWidgets('editing payment preserves its project id', (
    WidgetTester tester,
  ) async {
    const stableProject = AccountProjectVM(
      projectId: 'project:stable',
      projectKey: '丁队||五里山',
      displayName: '丁队 + 五里山',
      minYmd: 20260301,
      deviceIds: [1],
      hoursByDevice: {1: 51.2},
      rentIncomeTotal: 0,
      minRate: 180,
      isMultiDevice: false,
      isMultiMode: false,
      receivable: 9216,
      received: 100,
      remaining: 9116,
      ratio: 100 / 9216,
      payments: [
        AccountPayment(
          id: 1,
          projectId: 'project:stable',
          projectKey: '丁队||五里山',
          ymd: 20260302,
          amount: 100,
        ),
      ],
    );

    AccountPayment? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                result = await showDialog<AccountPayment>(
                  context: context,
                  builder: (_) => AccountPaymentEditorDialog(
                    project: stableProject,
                    allPayments: stableProject.payments,
                    editing: stableProject.payments.single,
                  ),
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.projectId, 'project:stable');
    expect(result!.id, 1);
  });
}
