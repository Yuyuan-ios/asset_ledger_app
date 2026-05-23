import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/patterns/timing/recent_records_pattern.dart';
import 'package:asset_ledger/tokens/mapper/timing_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders device index in bold on timing recent records', (
    WidgetTester tester,
  ) async {
    const device = Device(
      id: 1,
      name: 'SANY 1#',
      brand: 'SANY',
      defaultUnitPrice: 120,
      baseMeterHours: 2000,
    );
    const record = TimingRecord(
      id: 1,
      deviceId: 1,
      startDate: 20260317,
      contact: '赵六',
      site: '尚义',
      type: TimingType.hours,
      startMeter: 2096,
      endMeter: 2105,
      hours: 9,
      income: 1080,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SectionRecentRecords(
            records: const [record],
            deviceById: const {1: device},
            deviceIndexById: const {1: '1#'},
          ),
        ),
      ),
    );

    final indexText = tester.widget<Text>(find.text('1#'));
    expect(indexText.style?.fontWeight, FontWeight.w700);
    expect(find.textContaining('条记录', findRichText: true), findsNothing);
  });

  testWidgets('shows aggregate record count and keeps children expandable', (
    WidgetTester tester,
  ) async {
    await _pumpSectionRecentRecords(
      tester,
      records: const [
        TimingRecord(
          id: 10,
          deviceId: 1,
          startDate: 20260501,
          contact: '李洋',
          site: '天眉乐',
          type: TimingType.hours,
          startMeter: 100,
          endMeter: 108,
          hours: 8,
          income: 1440,
        ),
        TimingRecord(
          id: 11,
          deviceId: 1,
          startDate: 20260501,
          contact: '李洋',
          site: '天眉乐',
          type: TimingType.hours,
          startMeter: 108,
          endMeter: 116.1,
          hours: 8.1,
          income: 1458,
        ),
      ],
    );

    expect(find.textContaining('2条记录', findRichText: true), findsOneWidget);
    expect(find.textContaining('工时调整', findRichText: true), findsNothing);
    expect(find.text('误差 0.0，累计 16.1 h'), findsOneWidget);

    final aggregateSubtitle = tester.widget<RichText>(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText().contains('2条记录'),
      ),
    );
    final aggregateSpan = aggregateSubtitle.text as TextSpan;
    final countSpan = aggregateSpan.children!.whereType<TextSpan>().firstWhere(
      (span) => span.text?.contains('2条记录') ?? false,
    );
    expect(countSpan.style?.fontSize, TimingTokens.recordValueFontSize - 1);
    expect(countSpan.style?.fontWeight, FontWeight.w400);
    expect(countSpan.style?.height, 1);

    await tester.tap(find.text('李洋·天眉乐'));
    await tester.pump();

    expect(find.text('8.0 h'), findsOneWidget);
    expect(find.text('8.1 h'), findsOneWidget);
  });

  testWidgets('sliver aggregate row shows three-record count', (
    WidgetTester tester,
  ) async {
    const records = [
      TimingRecord(
        id: 20,
        deviceId: 1,
        startDate: 20260502,
        contact: '王强',
        site: '五里山',
        type: TimingType.hours,
        startMeter: 200,
        endMeter: 204,
        hours: 4,
        income: 720,
      ),
      TimingRecord(
        id: 21,
        deviceId: 1,
        startDate: 20260502,
        contact: '王强',
        site: '五里山',
        type: TimingType.hours,
        startMeter: 204,
        endMeter: 209,
        hours: 5,
        income: 900,
      ),
      TimingRecord(
        id: 22,
        deviceId: 1,
        startDate: 20260502,
        contact: '王强',
        site: '五里山',
        type: TimingType.hours,
        startMeter: 209,
        endMeter: 216,
        hours: 7,
        income: 1260,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: buildTimingRecentRecordSlivers(
              records: records,
              deviceById: const {1: _device},
              deviceIndexById: const {1: '1#'},
              locallyRemovedKeys: const <String>{},
              expandedAggregateKeys: const <String>{},
              onToggleAggregate: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('3条记录', findRichText: true), findsOneWidget);
    expect(find.textContaining('工时调整', findRichText: true), findsNothing);
    expect(find.text('误差 0.0，累计 16.0 h'), findsOneWidget);
  });

  testWidgets('hides zero hours for rent recent record and keeps amount', (
    WidgetTester tester,
  ) async {
    const device = Device(
      id: 1,
      name: 'HITACHI 1#',
      brand: 'HITACHI',
      defaultUnitPrice: 120,
      baseMeterHours: 2000,
    );
    const record = TimingRecord(
      id: 2,
      deviceId: 1,
      startDate: 20260516,
      contact: '周亮',
      site: '成都',
      type: TimingType.rent,
      startMeter: 6180.7,
      endMeter: 6180.7,
      hours: 0,
      income: 22000,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SectionRecentRecords(
            records: const [record],
            deviceById: const {1: device},
            deviceIndexById: const {1: '1#'},
          ),
        ),
      ),
    );

    expect(find.text('0.0 h'), findsNothing);
    expect(find.text('¥22000'), findsOneWidget);
  });

  testWidgets('shows rent recent record hours when actual hours exist', (
    WidgetTester tester,
  ) async {
    const device = Device(
      id: 1,
      name: 'HITACHI 1#',
      brand: 'HITACHI',
      defaultUnitPrice: 120,
      baseMeterHours: 2000,
    );
    const record = TimingRecord(
      id: 3,
      deviceId: 1,
      startDate: 20260516,
      contact: '周亮',
      site: '成都',
      type: TimingType.rent,
      startMeter: 6180.7,
      endMeter: 6184.7,
      hours: 4,
      income: 22000,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SectionRecentRecords(
            records: const [record],
            deviceById: const {1: device},
            deviceIndexById: const {1: '1#'},
          ),
        ),
      ),
    );

    expect(find.text('4.0 h'), findsOneWidget);
    expect(find.text('¥22000'), findsOneWidget);
  });
}

const _device = Device(
  id: 1,
  name: 'SANY 1#',
  brand: 'SANY',
  defaultUnitPrice: 120,
  baseMeterHours: 2000,
);

Future<void> _pumpSectionRecentRecords(
  WidgetTester tester, {
  required List<TimingRecord> records,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SectionRecentRecords(
          records: records,
          deviceById: const {1: _device},
          deviceIndexById: const {1: '1#'},
        ),
      ),
    ),
  );
}
