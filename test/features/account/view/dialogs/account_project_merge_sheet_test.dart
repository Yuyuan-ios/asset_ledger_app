import 'package:asset_ledger/features/account/view/dialogs/account_project_merge_sheet.dart';
import 'package:asset_ledger/features/account/view/dialogs/account_project_merge_sheet_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccountProjectMergeSheet', () {
    testWidgets('confirms selected projects and closes after success', (
      tester,
    ) async {
      MergeProjectSheetResult? submitted;
      var refreshed = false;

      await tester.pumpWidget(
        _SheetHarness(
          onConfirmMerge: (result) async {
            submitted = result;
            refreshed = true;
          },
        ),
      );

      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('李杰 + 新村'));
      await tester.tap(find.text('李杰 + 高桥'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();

      expect(submitted?.contact, '李杰');
      expect(submitted?.projectKeys, ['李杰||新村', '李杰||高桥']);
      expect(refreshed, isTrue);
      expect(find.text('合并项目'), findsNothing);
    });

    testWidgets('keeps the sheet open and reports error after failure', (
      tester,
    ) async {
      final errors = <String>[];

      await tester.pumpWidget(
        _SheetHarness(
          onConfirmMerge: (_) async {
            throw StateError('项目已属于其他合并组');
          },
          onError: errors.add,
        ),
      );

      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('李杰 + 新村'));
      await tester.tap(find.text('李杰 + 高桥'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认'));
      await tester.pump();

      expect(find.text('合并项目'), findsOneWidget);
      expect(errors.single, contains('项目已属于其他合并组'));
    });
  });
}

class _SheetHarness extends StatelessWidget {
  const _SheetHarness({required this.onConfirmMerge, this.onError});

  final ConfirmMergeProjects onConfirmMerge;
  final ValueChanged<String>? onError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                showAccountProjectMergeSheet(
                  context,
                  groups: _groups,
                  onConfirmMerge: onConfirmMerge,
                  onError: onError ?? (_) {},
                );
              },
              child: const Text('打开'),
            );
          },
        ),
      ),
    );
  }
}

const _groups = [
  MergeProjectSheetContactGroup(
    contact: '李杰',
    unmergedItems: [
      MergeProjectSheetItem(
        projectKey: '李杰||新村',
        displayName: '李杰 + 新村',
        isMerged: false,
      ),
      MergeProjectSheetItem(
        projectKey: '李杰||高桥',
        displayName: '李杰 + 高桥',
        isMerged: false,
      ),
    ],
    mergedItems: [
      MergeProjectSheetItem(
        projectKey: '李杰||尚义',
        displayName: '李杰 + 尚义',
        isMerged: true,
      ),
    ],
  ),
];
