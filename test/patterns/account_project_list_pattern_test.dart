import 'package:asset_ledger/features/account/model/account_view_model.dart';
import 'package:asset_ledger/patterns/account/account_project_list_pattern.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders total hours in bold on account project cards', (
    tester,
  ) async {
    const project = AccountProjectVM(
      projectKey: 'zhao-shangyi',
      displayName: '赵六 + 尚义',
      minYmd: 20260317,
      deviceIds: [1],
      hoursByDevice: {1: 9},
      rentIncomeTotal: 0,
      minRate: 120,
      isMultiDevice: false,
      isMultiMode: false,
      receivable: 1080,
      received: 1000,
      remaining: 80,
      ratio: 0.926,
      payments: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountProjectList(
            projects: const [project],
            onTap: (_) {},
          ),
        ),
      ),
    );

    final totalHoursText = tester.widget<Text>(find.text('总共:  9 h'));

    expect(totalHoursText.style?.fontWeight, FontWeight.w700);
  });
}
