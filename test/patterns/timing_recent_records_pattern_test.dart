import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/patterns/timing/recent_records_pattern.dart';
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
