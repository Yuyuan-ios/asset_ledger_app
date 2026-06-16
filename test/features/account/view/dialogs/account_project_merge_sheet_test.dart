import 'package:asset_ledger/features/account/view/dialogs/account_project_merge_sheet.dart';
import 'package:asset_ledger/features/account/view/dialogs/account_project_merge_sheet_data.dart';
import 'package:asset_ledger/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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

      expect(_softHeaderDivider(), findsOneWidget);

      await tester.tap(find.text('李杰 · 新村'));
      await tester.tap(find.text('李杰 · 高桥'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      expect(submitted?.contact, '李杰');
      expect(submitted?.projectIds, [
        'project:lijie-xincun',
        'project:lijie-gaoqiao',
      ]);
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
      await tester.tap(find.text('李杰 · 新村'));
      await tester.tap(find.text('李杰 · 高桥'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确定'));
      await tester.pump();

      expect(find.text('合并项目'), findsOneWidget);
      expect(errors.single, contains('项目已属于其他合并组'));
    });
  });
}

Finder _softHeaderDivider() {
  return find.byWidgetPredicate((widget) {
    final decoration = widget is Container ? widget.decoration : null;
    if (decoration is! BoxDecoration) return false;
    final gradient = decoration.gradient;
    if (gradient is! LinearGradient) return false;
    return gradient.colors.length == 4 &&
        gradient.colors.first == const Color(0x00D8CEC4) &&
        gradient.colors[1] == const Color(0x78D8CEC4) &&
        gradient.colors[2] == const Color(0x78D8CEC4) &&
        gradient.colors.last == const Color(0x00D8CEC4) &&
        gradient.stops.toString() == const [0.0, 0.06, 0.94, 1.0].toString();
  });
}

class _SheetHarness extends StatelessWidget {
  const _SheetHarness({required this.onConfirmMerge, this.onError});

  final ConfirmMergeProjects onConfirmMerge;
  final ValueChanged<String>? onError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
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
        projectId: 'project:lijie-xincun',
        projectKey: '李杰||新村',
        displayName: '李杰 + 新村',
        isMerged: false,
      ),
      MergeProjectSheetItem(
        projectId: 'project:lijie-gaoqiao',
        projectKey: '李杰||高桥',
        displayName: '李杰 + 高桥',
        isMerged: false,
      ),
    ],
    mergedItems: [
      MergeProjectSheetItem(
        projectId: 'project:lijie-shangyi',
        projectKey: '李杰||尚义',
        displayName: '李杰 + 尚义',
        isMerged: true,
      ),
    ],
  ),
];
