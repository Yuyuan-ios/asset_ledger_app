import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:asset_ledger/features/account/model/account_view_model.dart';
import 'package:asset_ledger/features/account/view/dialogs/account_payment_editor_dialog.dart';
import 'package:asset_ledger/l10n/gen/app_localizations.dart';
import 'package:asset_ledger/patterns/account/account_overview_card_pattern.dart';
import 'package:asset_ledger/patterns/account/account_project_list_pattern.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders account overview and empty list strings in Chinese', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(
        locale: const Locale('zh'),
        child: Column(
          children: [
            SizedBox(width: 390, child: AccountOverviewCard(vm: _overviewVm())),
            AccountProjectList(projects: const [], onTap: (_) {}),
          ],
        ),
      ),
    );

    final uiCopy = _collectUiCopy(tester);
    expect(uiCopy, contains('总    览'));
    expect(uiCopy, contains('总应收'));
    expect(uiCopy, contains('已收(净)'));
    expect(uiCopy, contains('暂无项目（计时页有记录后将自动出现）'));
  });

  testWidgets(
    'renders account overview and payment editor strings in English',
    (tester) async {
      await tester.pumpWidget(
        _localizedApp(
          locale: const Locale('en'),
          child: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(
                  width: 390,
                  child: AccountOverviewCard(vm: _overviewVm()),
                ),
                AccountPaymentEditorDialog(
                  project: _projectVm(),
                  allPayments: _projectVm().payments,
                ),
              ],
            ),
          ),
        ),
      );

      final uiCopy = _collectUiCopy(tester);
      expect(uiCopy, contains('Overview'));
      expect(uiCopy, contains('Receivable'));
      expect(uiCopy, contains('Net received'));
      expect(uiCopy, contains('Add payment'));
      expect(uiCopy, contains('Project: Ding · Wulishan'));
      expect(uiCopy, contains('Amount (integer)'));
      expect(uiCopy, contains('Notes (optional)'));
      expect(uiCopy, contains('Receivable: ¥9216, received: ¥1000'));
      expect(uiCopy, isNot(contains('新增收款')));
    },
  );
}

Widget _localizedApp({required Locale locale, required Widget child}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

AccountOverviewVm _overviewVm() {
  return const AccountOverviewVm(
    totalReceivable: 9216,
    totalReceived: 1000,
    totalRemaining: 8216,
    totalRatio: 0.1085,
    netCashReceived: 1000,
    deviceReceivables: [
      AccountDeviceReceivable(deviceId: 1, name: 'SANY 1#', amount: 9216),
    ],
  );
}

AccountProjectVM _projectVm() {
  return AccountProjectVM(
    projectKey: 'ding+site',
    displayName: 'Ding + Wulishan',
    minYmd: 20260301,
    deviceIds: const [1],
    hoursByDevice: const {1: 51.2},
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
}

String _collectUiCopy(WidgetTester tester) {
  final parts = <String>[];
  for (final widget in tester.allWidgets) {
    if (widget is Text) {
      parts.add(widget.data ?? widget.textSpan?.toPlainText() ?? '');
    } else if (widget is TextField) {
      final decoration = widget.decoration;
      if (decoration == null) continue;
      parts
        ..add(decoration.labelText ?? '')
        ..add(decoration.hintText ?? '')
        ..add(decoration.helperText ?? '');
    }
  }
  return parts.where((part) => part.isNotEmpty).join('\n');
}
