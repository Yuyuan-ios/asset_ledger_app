import 'package:asset_ledger/components/layout/pinned_header_delegate.dart';
import 'package:asset_ledger/patterns/timing/records_title_pattern.dart';
import 'package:asset_ledger/patterns/timing/timing_home_pattern.dart';
import 'package:asset_ledger/tokens/mapper/timing_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'records section switch does not define the pinned header height',
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
      expect(find.text('最近记录'), findsOneWidget);
      expect(find.text('项目外协'), findsOneWidget);
    },
  );

  testWidgets('records section switch still changes visible content', (
    tester,
  ) async {
    var section = TimingRecordsSection.recent;

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
                externalWorkItems: const [],
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
    expect(find.text('暂无项目外协记录'), findsNothing);

    await tester.tap(find.text('项目外协'));
    await tester.pump();

    expect(find.text('暂无项目外协记录'), findsOneWidget);
  });
}
