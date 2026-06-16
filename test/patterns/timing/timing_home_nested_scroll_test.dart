import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/patterns/timing/timing_home_pattern.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// NestedScrollView 方案的关键保证：
/// - 图表随列表上滑收起（在 header 区，非吸顶）。
/// - 最近记录日期小标题继续吸顶（滚动后仍停在顶部，不随内容滚走）。
/// - 左右滑动可切换 tab。
void main() {
  TimingRecord rec(int ymd, int device, String contact) => TimingRecord(
    deviceId: device,
    startDate: ymd,
    contact: contact,
    site: 'S',
    type: TimingType.hours,
    startMeter: 0,
    endMeter: 1,
    hours: 1,
    income: 100,
  );

  Future<void> pump(WidgetTester tester, List<TimingRecord> records) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TimingHomePattern(
          header: const SizedBox(height: 20),
          chart: const SizedBox(key: Key('exp-chart'), height: 120),
          recordsSection: TimingRecordsSection.recent,
          onRecordsSectionChanged: (_) {},
          records: records,
          externalWorkItems: [],
          deviceById: const {},
          deviceIndexById: const {},
          loading: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('chart collapses on scroll while the date header stays pinned', (
    tester,
  ) async {
    // 顶部日期组 2024.01.10 做得很高（10 条不同设备的单条记录 → 同日期一组），
    // 第二组 2024.01.05 在下方。滚动量大于首组日期标题的初始偏移，但小于首组
    // 总高度，从而能区分"吸顶"与"随内容滚走"。
    final records = <TimingRecord>[
      for (var i = 0; i < 10; i++) rec(20240110, i, 'A$i'),
      rec(20240105, 99, 'B'),
    ];
    await pump(tester, records);

    // 初始：图表可见，首组日期标题可见。
    expect(find.byKey(const Key('exp-chart')), findsOneWidget);
    expect(find.text('2024.01.10'), findsOneWidget);

    // 在最近记录页内向上滚动。
    await tester.drag(
      find.byKey(const PageStorageKey<String>('timing-recent-tab')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    // 图表已随列表上滑收起（移出 header 区，不在树中）。
    expect(find.byKey(const Key('exp-chart')), findsNothing);
    // 日期小标题仍吸顶可见（若未吸顶，滚动 300 后它早已滚出视口）。
    expect(find.text('2024.01.10'), findsOneWidget);
    // 且停在视口顶部附近（远小于初始偏移 ~190）——证明是吸顶而非随内容滚走。
    expect(tester.getTopLeft(find.text('2024.01.10')).dy, lessThan(120));
  });

  testWidgets('swiping the tab body switches recent <-> external', (
    tester,
  ) async {
    var section = TimingRecordsSection.recent;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return TimingHomePattern(
              header: const SizedBox(height: 20),
              chart: const SizedBox(height: 80),
              recordsSection: section,
              onRecordsSectionChanged: (next) => setState(() => section = next),
              records: [],
              externalWorkItems: [],
              deviceById: const {},
              deviceIndexById: const {},
              loading: false,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('暂无外协项目记录'), findsNothing);

    await tester.drag(find.byType(TabBarView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(section, TimingRecordsSection.externalWork);
    expect(find.text('暂无外协项目记录'), findsOneWidget);

    await tester.drag(find.byType(TabBarView), const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(section, TimingRecordsSection.recent);
  });
}
