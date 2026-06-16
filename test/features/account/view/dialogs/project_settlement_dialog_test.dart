import 'package:asset_ledger/data/models/project_write_off.dart';
import 'package:asset_ledger/features/account/model/account_view_model.dart';
import 'package:asset_ledger/features/account/use_cases/project_settlement_use_case.dart';
import 'package:asset_ledger/features/account/view/dialogs/project_settlement_dialog.dart';
import 'package:asset_ledger/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows only fixed write-off amount and optional reason input', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(
        home: Scaffold(
          body: ProjectSettlementDialog(
            project: _project(),
            onSave: (_) async => _settledResult(),
          ),
        ),
      ),
    );

    expect(find.text('结清项目'), findsOneWidget);
    expect(find.text('核销金额'), findsOneWidget);
    expect(find.text('¥60'), findsOneWidget);
    expect(find.text('核销/减免原因（可填）'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('确认后，这笔待收将作为核销处理，不再计入待收，也不会算作实收。'), findsOneWidget);
    expect(find.text('确认结清'), findsOneWidget);

    expect(find.text('本次实收金额'), findsNothing);
    expect(find.text('备注（可填）'), findsNothing);
    expect(find.text('核销原因'), findsNothing);
    expect(find.text('甲方 + 一号工地'), findsNothing);
    expect(find.text('项目总额'), findsNothing);
    expect(find.text('已收金额'), findsNothing);
    expect(find.text('当前待收'), findsNothing);
  });

  testWidgets('saves empty reason as settlement write-off without payment', (
    tester,
  ) async {
    ProjectSettlementDialogInput? savedInput;

    await tester.pumpWidget(
      _localizedApp(
        home: Scaffold(
          body: ProjectSettlementDialog(
            project: _project(),
            onSave: (input) async {
              savedInput = input;
              return _settledResult();
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('确认结清'));
    await tester.pump();

    expect(savedInput?.paymentAmount, 0);
    expect(savedInput?.writeOffAmount, 60);
    expect(savedInput?.writeOffReason, ProjectWriteOffReason.settlement);
    expect(savedInput?.note, isNull);
  });

  testWidgets('saves optional reason text as write-off note', (tester) async {
    ProjectSettlementDialogInput? savedInput;

    await tester.pumpWidget(
      _localizedApp(
        home: Scaffold(
          body: ProjectSettlementDialog(
            project: _project(),
            onSave: (input) async {
              savedInput = input;
              return _settledResult();
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '协商减免尾款');
    await tester.tap(find.text('确认结清'));
    await tester.pump();

    expect(savedInput?.paymentAmount, 0);
    expect(savedInput?.writeOffAmount, 60);
    expect(savedInput?.writeOffReason, ProjectWriteOffReason.settlement);
    expect(savedInput?.note, '协商减免尾款');
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

ProjectSettlementResult _settledResult() {
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
}
