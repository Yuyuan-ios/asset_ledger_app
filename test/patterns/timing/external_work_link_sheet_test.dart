import 'package:asset_ledger/components/buttons/app_primary_button.dart';
import 'package:asset_ledger/patterns/timing/external_work_link_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('externalWorkLinkSiteSummary', () {
    test('joins distinct sites with + and truncates with ...', () {
      expect(externalWorkLinkSiteSummary(['鲜滩', '尚义', '五里山']), '鲜滩+尚义...');
    });

    test('single site shows no separator/ellipsis', () {
      expect(externalWorkLinkSiteSummary(['鲜滩']), '鲜滩');
    });

    test('exactly maxShown sites have no ellipsis', () {
      expect(externalWorkLinkSiteSummary(['鲜滩', '尚义']), '鲜滩+尚义');
    });

    test('dedupes and ignores blanks', () {
      expect(externalWorkLinkSiteSummary(['鲜滩', ' 鲜滩 ', '', '  ']), '鲜滩');
    });

    test('empty input yields empty summary', () {
      expect(externalWorkLinkSiteSummary(const []), '');
    });
  });

  const candidates = [
    ExternalWorkLinkCandidate(
      projectId: 'p1',
      title: '李杰 + 鲜滩',
      settled: false,
    ),
    ExternalWorkLinkCandidate(
      projectId: 'p2',
      title: '刘锐 + 五里山',
      settled: true,
    ),
  ];

  const pkgXiantan = ExternalWorkLinkPackage(
    batchId: 'b1',
    optionTitle: '余远 · 鲜滩',
    summaryDetail: 'Hitachi · 5条记录 · 239.0h',
  );
  const pkgWuli = ExternalWorkLinkPackage(
    batchId: 'b2',
    optionTitle: '余远 · 五里山',
    summaryDetail: 'CAT · 3条记录 · 120.0h',
  );

  Future<void> pumpSheet(
    WidgetTester tester, {
    required List<ExternalWorkLinkPackage> packages,
    List<ExternalWorkLinkCandidate> withCandidates = candidates,
    ExternalWorkLinkConfirm? onConfirm,
    ExternalWorkLinkUnlink? onUnlink,
    double? height,
  }) async {
    final sheet = ExternalWorkLinkSheet(
      packages: packages,
      candidates: withCandidates,
      onConfirm: onConfirm ?? (_, _) {},
      onCancel: () {},
      onUnlink: onUnlink,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: height == null
              ? sheet
              : Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(height: height, child: sheet),
                ),
        ),
      ),
    );
  }

  testWidgets('multiple packages show the picker with 来源人 · 地址摘要', (
    tester,
  ) async {
    await pumpSheet(tester, packages: const [pkgXiantan, pkgWuli]);

    expect(find.text('选择外协包'), findsOneWidget);
    expect(find.text('余远 · 鲜滩'), findsOneWidget);
    expect(find.text('余远 · 五里山'), findsOneWidget);
    expect(find.textContaining('合并'), findsNothing);
  });

  testWidgets('switching package syncs the summary detail', (tester) async {
    await pumpSheet(tester, packages: const [pkgXiantan, pkgWuli]);

    // 默认选中第一个包。
    expect(find.text('Hitachi · 5条记录 · 239.0h'), findsOneWidget);
    expect(find.text('CAT · 3条记录 · 120.0h'), findsNothing);

    await tester.tap(find.byKey(const Key('external-work-link-package-b2')));
    await tester.pump();

    expect(find.text('CAT · 3条记录 · 120.0h'), findsOneWidget);
    expect(find.text('Hitachi · 5条记录 · 239.0h'), findsNothing);
  });

  testWidgets('single package is shown + selectable and confirmable', (
    tester,
  ) async {
    ExternalWorkLinkPackage? confirmedPkg;
    ExternalWorkLinkCandidate? confirmedCandidate;
    await pumpSheet(
      tester,
      packages: const [pkgXiantan],
      onConfirm: (pkg, candidate) {
        confirmedPkg = pkg;
        confirmedCandidate = candidate;
      },
    );

    // 单包也显示"选择外协包"，且默认选中、摘要可见。
    expect(find.text('选择外协包'), findsOneWidget);
    expect(find.text('Hitachi · 5条记录 · 239.0h'), findsOneWidget);

    AppPrimaryButton confirm() => tester.widget<AppPrimaryButton>(
      find.byKey(const Key('external-work-link-confirm')),
    );
    expect(confirm().onPressed, isNull);

    await tester.tap(find.byKey(const Key('external-work-link-candidate-p1')));
    await tester.pump();
    expect(confirm().onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('external-work-link-confirm')));
    await tester.pump();
    expect(confirmedPkg?.batchId, 'b1');
    expect(confirmedCandidate?.projectId, 'p1');
  });

  testWidgets('selecting a settled candidate surfaces the boundary hint', (
    tester,
  ) async {
    await pumpSheet(tester, packages: const [pkgXiantan]);

    expect(find.text(externalWorkLinkSettledHint), findsNothing);
    await tester.tap(find.byKey(const Key('external-work-link-candidate-p2')));
    await tester.pump();
    expect(find.text(externalWorkLinkSettledHint), findsOneWidget);
  });

  testWidgets('linked package shows linked state + unlink, no confirm', (
    tester,
  ) async {
    ExternalWorkLinkPackage? unlinked;
    await pumpSheet(
      tester,
      packages: const [
        ExternalWorkLinkPackage(
          batchId: 'b1',
          optionTitle: '余远 · 鲜滩',
          summaryDetail: 'Hitachi · 5条记录 · 239.0h',
          linkedProjectTitle: '李杰 + 鲜滩',
        ),
      ],
      onUnlink: (pkg) => unlinked = pkg,
    );

    expect(find.text('已关联：李杰 + 鲜滩'), findsOneWidget);
    expect(find.byKey(const Key('external-work-link-confirm')), findsNothing);

    await tester.tap(find.byKey(const Key('external-work-link-unlink')));
    await tester.pump();
    expect(unlinked?.batchId, 'b1');
  });

  testWidgets('actions stay fixed while candidates scroll', (tester) async {
    final manyCandidates = List.generate(
      18,
      (index) => ExternalWorkLinkCandidate(
        projectId: 'p${index + 1}',
        title: '项目 ${index + 1}',
        settled: false,
      ),
    );

    await pumpSheet(
      tester,
      packages: const [pkgXiantan],
      withCandidates: manyCandidates,
      height: 360,
    );

    final confirmFinder = find.byKey(const Key('external-work-link-confirm'));
    final confirmTopBefore = tester.getTopLeft(confirmFinder).dy;

    await tester.ensureVisible(
      find.byKey(const Key('external-work-link-candidate-p18')),
    );
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(confirmFinder).dy, confirmTopBefore);
    expect(confirmFinder, findsOneWidget);
  });
}
