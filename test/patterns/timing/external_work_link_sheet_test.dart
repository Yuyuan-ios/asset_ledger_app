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

  Future<void> pumpUnlinked(
    WidgetTester tester, {
    required List<ExternalWorkLinkCandidate> candidates,
    required void Function(ExternalWorkLinkCandidate) onConfirm,
    VoidCallback? onCancel,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExternalWorkLinkSheet(
            summaryTitle: '余远 · 鲜滩+尚义...',
            summaryDetail: 'Hitachi · 6条记录 · 248.0h',
            candidates: candidates,
            onConfirm: onConfirm,
            onCancel: onCancel ?? () {},
          ),
        ),
      ),
    );
  }

  testWidgets('unlinked sheet shows summary + candidates, no 合并X项目', (
    tester,
  ) async {
    await pumpUnlinked(
      tester,
      candidates: const [
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
      ],
      onConfirm: (_) {},
    );

    expect(find.text('余远 · 鲜滩+尚义...'), findsOneWidget);
    expect(find.text('Hitachi · 6条记录 · 248.0h'), findsOneWidget);
    expect(find.text('李杰 + 鲜滩'), findsOneWidget);
    expect(find.text('刘锐 + 五里山（已结清）'), findsOneWidget);
    expect(find.textContaining('合并'), findsNothing);
  });

  testWidgets('confirm is disabled until a candidate is selected', (
    tester,
  ) async {
    await pumpUnlinked(
      tester,
      candidates: const [
        ExternalWorkLinkCandidate(
          projectId: 'p1',
          title: '李杰 + 鲜滩',
          settled: false,
        ),
      ],
      onConfirm: (_) {},
    );

    AppPrimaryButton confirm() => tester.widget<AppPrimaryButton>(
      find.byKey(const Key('external-work-link-confirm')),
    );
    expect(confirm().onPressed, isNull);

    await tester.tap(find.byKey(const Key('external-work-link-candidate-p1')));
    await tester.pump();
    expect(confirm().onPressed, isNotNull);
  });

  testWidgets('selecting a settled candidate surfaces the boundary hint', (
    tester,
  ) async {
    await pumpUnlinked(
      tester,
      candidates: const [
        ExternalWorkLinkCandidate(
          projectId: 'p2',
          title: '刘锐 + 五里山',
          settled: true,
        ),
      ],
      onConfirm: (_) {},
    );

    expect(find.text(externalWorkLinkSettledHint), findsNothing);
    await tester.tap(find.byKey(const Key('external-work-link-candidate-p2')));
    await tester.pump();
    expect(find.text(externalWorkLinkSettledHint), findsOneWidget);
  });

  testWidgets('confirm fires onConfirm with the selected candidate', (
    tester,
  ) async {
    ExternalWorkLinkCandidate? confirmed;
    await pumpUnlinked(
      tester,
      candidates: const [
        ExternalWorkLinkCandidate(
          projectId: 'p1',
          title: '李杰 + 鲜滩',
          settled: false,
        ),
      ],
      onConfirm: (candidate) => confirmed = candidate,
    );

    await tester.tap(find.byKey(const Key('external-work-link-candidate-p1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('external-work-link-confirm')));
    await tester.pump();

    expect(confirmed?.projectId, 'p1');
  });

  testWidgets('linked sheet shows linked state + unlink, no confirm', (
    tester,
  ) async {
    var unlinkTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExternalWorkLinkSheet(
            summaryTitle: '余远 · 鲜滩',
            summaryDetail: 'Hitachi · 6条记录 · 248.0h',
            candidates: const [],
            linkedProjectTitle: '李杰 + 鲜滩',
            onConfirm: (_) {},
            onCancel: () {},
            onUnlink: () => unlinkTapped = true,
          ),
        ),
      ),
    );

    expect(find.text('已关联：李杰 + 鲜滩'), findsOneWidget);
    expect(find.byKey(const Key('external-work-link-confirm')), findsNothing);

    await tester.tap(find.byKey(const Key('external-work-link-unlink')));
    await tester.pump();
    expect(unlinkTapped, isTrue);
  });
}
