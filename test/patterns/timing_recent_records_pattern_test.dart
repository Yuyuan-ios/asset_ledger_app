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
}
