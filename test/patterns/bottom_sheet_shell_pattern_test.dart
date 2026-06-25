import 'package:asset_ledger/components/feedback/app_toast.dart';
import 'package:asset_ledger/patterns/layout/bottom_sheet_shell_pattern.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('showAppBottomSheet hosts toast on the local sheet scaffold', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          key: const ValueKey('root-scaffold'),
          body: Builder(
            builder: (pageContext) {
              return Center(
                child: FilledButton(
                  onPressed: () {
                    showAppBottomSheet<void>(
                      context: pageContext,
                      builder: (sheetContext) {
                        return AppBottomSheetShell(
                          title: '测试弹层',
                          scrollable: false,
                          footerEnabled: false,
                          child: Center(
                            child: FilledButton(
                              onPressed: () {
                                AppToast.show(sheetContext, '弹层提示');
                              },
                              child: const Text('显示提示'),
                            ),
                          ),
                        );
                      },
                    );
                  },
                  child: const Text('打开弹层'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开弹层'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('显示提示'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('弹层提示'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('app-bottom-sheet-feedback-host')),
        matching: find.byType(SnackBar),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('root-scaffold')),
        matching: find.byType(SnackBar),
      ),
      findsNothing,
    );
  });
}
