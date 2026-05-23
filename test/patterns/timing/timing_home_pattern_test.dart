import 'package:asset_ledger/components/layout/pinned_header_delegate.dart';
import 'package:asset_ledger/data/models/external_work_record.dart';
import 'package:asset_ledger/patterns/timing/records_title_pattern.dart';
import 'package:asset_ledger/patterns/timing/timing_home_pattern.dart';
import 'package:asset_ledger/features/timing/state/timing_external_work_store.dart';
import 'package:asset_ledger/tokens/mapper/timing_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'records header shows only the current title at the pinned height',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TimingHomePattern(
            header: const SizedBox(height: 20),
            chart: const SizedBox(height: 80),
            recordsTitle: const RecordsTitle(count: 13),
            recordsSection: TimingRecordsSection.recent,
            onRecordsSectionChanged: (_) {},
            records: const [],
            externalWorkItems: const [],
            deviceById: const {},
            deviceIndexById: const {},
            loading: false,
          ),
        ),
      );

      final header = tester.widget<SliverPersistentHeader>(
        find.byType(SliverPersistentHeader),
      );
      final delegate = header.delegate as PinnedHeaderDelegate;
      expect(
        delegate.minExtent,
        (TimingTokens.recordsTitleFontSize *
                TimingTokens.recordsTitleLineHeight) +
            TimingTokens.homeRecordsTitleTopGap,
      );
      expect(delegate.maxExtent, delegate.minExtent);
      expect(find.text('最近记录(13)'), findsOneWidget);
      expect(find.text('最近记录'), findsNothing);
      expect(find.text('项目外协'), findsNothing);
    },
  );

  testWidgets('swiping records sections syncs the title without a capsule', (
    tester,
  ) async {
    var section = TimingRecordsSection.recent;
    final externalItems = List.generate(3, _externalItem);

    Future<void> pump() async {
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return TimingHomePattern(
                header: const SizedBox(height: 20),
                chart: const SizedBox(height: 80),
                recordsTitle: const RecordsTitle(count: 0),
                recordsSection: section,
                onRecordsSectionChanged: (next) {
                  setState(() => section = next);
                },
                records: const [],
                externalWorkItems: externalItems,
                deviceById: const {},
                deviceIndexById: const {},
                loading: false,
              );
            },
          ),
        ),
      );
      await tester.pump();
    }

    await pump();

    expect(find.text('暂无记录'), findsOneWidget);
    expect(find.text('最近记录(0)'), findsOneWidget);
    expect(find.text('项目外协(3)'), findsNothing);
    expect(find.text('最近记录'), findsNothing);
    expect(find.text('项目外协'), findsNothing);

    await tester.drag(find.byType(TabBarView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(section, TimingRecordsSection.externalWork);
    expect(find.text('项目外协(3)'), findsOneWidget);
    expect(find.text('项目外协(3条)'), findsNothing);
    expect(find.text('最近记录'), findsNothing);
    expect(find.text('项目外协'), findsNothing);
  });
}

TimingExternalWorkRecordItem _externalItem(int index) {
  return TimingExternalWorkRecordItem(
    record: ExternalWorkRecord(
      id: 'r-$index',
      importBatchId: 'b-1',
      sourceShareId: 'share-1',
      sourceRecordUuid: 'src-$index',
      sourceInstallationUuid: 'install-1',
      originFingerprint: 'fp-$index',
      collaboratorName: '李工',
      contactSnapshot: '张三',
      siteSnapshot: '五里山',
      workDate: 20240101 + index,
      hoursMilli: 1000,
      sourceUnitPriceFen: 100,
      localUnitPriceFen: 100,
      amountFen: 100,
      createdAt: '2026-05-23T00:00:00.000Z',
      updatedAt: '2026-05-23T00:00:00.000Z',
    ),
  );
}
