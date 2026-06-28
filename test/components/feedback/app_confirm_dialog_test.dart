import 'package:asset_ledger/components/feedback/app_confirm_dialog.dart';
import 'package:asset_ledger/core/theme/app_theme.dart';
import 'package:asset_ledger/tokens/mapper/core_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dialogs reuse the shared sheet shell background', (
    WidgetTester tester,
  ) async {
    final theme = AppTheme.light();
    expect(theme.dialogTheme.backgroundColor, SheetColors.shellBackground);

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () {
                  showAppConfirmDialog(
                    context: context,
                    title: '删除记录',
                    content: '确定删除？',
                  );
                },
                child: const Text('打开'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(dialog.backgroundColor, SheetColors.shellBackground);
  });
}
