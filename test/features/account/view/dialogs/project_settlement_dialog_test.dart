import 'package:asset_ledger/features/account/model/account_view_model.dart';
import 'package:asset_ledger/features/account/view/dialogs/project_settlement_dialog.dart';
import 'package:asset_ledger/features/account/use_cases/project_settlement_use_case.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'updates write-off amount from payment amount and requires reason',
    (tester) async {
      var saveCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProjectSettlementDialog(
              project: _project(),
              onSave: (_) async {
                saveCalls++;
                return const ProjectSettlementResult(
                  projectId: 'project:1',
                  receivable: 1260,
                  receivedBefore: 1200,
                  writeOffBefore: 0,
                  remainingBefore: 60,
                  paymentAmount: 0,
                  writeOffAmount: 60,
                  receivedAfter: 1200,
                  writeOffAfter: 60,
                  remainingAfter: 0,
                  settled: true,
                  writeOffId: 'write-off-1',
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('¥60'), findsWidgets);
      expect(find.text('¥0'), findsWidgets);

      await tester.enterText(find.byType(TextField).first, '0');
      await tester.pump();

      expect(find.text('¥60'), findsWidgets);

      await tester.tap(find.text('保存结清'));
      await tester.pump();

      expect(find.text('请选择核销原因'), findsOneWidget);
      expect(saveCalls, 0);
    },
  );
}

AccountProjectVM _project() {
  return const AccountProjectVM(
    projectId: 'project:1',
    projectKey: '甲方||一号工地',
    displayName: '甲方 + 一号工地',
    minYmd: 20260501,
    deviceIds: [1],
    hoursByDevice: {1: 12.6},
    rentIncomeTotal: 0,
    minRate: 100,
    isMultiDevice: false,
    isMultiMode: false,
    receivable: 1260,
    received: 1200,
    remaining: 60,
    ratio: 1200 / 1260,
    payments: [],
  );
}
