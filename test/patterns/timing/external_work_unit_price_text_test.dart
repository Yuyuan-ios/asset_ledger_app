import 'package:asset_ledger/data/models/external_work_record.dart';
import 'package:asset_ledger/features/timing/state/timing_external_work_store.dart';
import 'package:asset_ledger/patterns/timing/external_work_records_pattern.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 详情页"单价"行的展示规则（协议升级后）：
/// - rent / 台班：固定显示"不适用"。
/// - hours 且任一单价字段非 null：显示真实单价 / h，0 也照常显示为 ¥0.00 / h
///   （0 是合法语义，不是未知）。
/// - hours 且两者均 null：显示"未知"，绝不再显示 ¥0。
void main() {
  Future<void> pump(WidgetTester tester, ExternalWorkRecord record) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExternalWorkRecordDetailContent(
            item: TimingExternalWorkRecordItem(record: record),
            onClose: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('hours record with known unit price shows "¥xxx / h"', (
    tester,
  ) async {
    await pump(
      tester,
      _record(
        recordKind: ExternalWorkRecordKind.hours,
        sourceUnitPriceFen: 20000,
        localUnitPriceFen: 20000,
        amountFen: 140000,
      ),
    );
    expect(find.text('¥200 / h'), findsOneWidget);
  });

  testWidgets(
    'hours record with null source AND local unit price shows "未知" (not ¥0)',
    (tester) async {
      await pump(
        tester,
        _record(
          recordKind: ExternalWorkRecordKind.hours,
          sourceUnitPriceFen: null,
          localUnitPriceFen: null,
          amountFen: 120000,
        ),
      );
      expect(find.text('未知'), findsOneWidget);
      expect(find.text('¥0 / h'), findsNothing);
      expect(find.text('¥0'), findsNothing);
    },
  );

  testWidgets('rent record always shows "不适用" regardless of unit price', (
    tester,
  ) async {
    await pump(
      tester,
      _record(
        recordKind: ExternalWorkRecordKind.rent,
        sourceUnitPriceFen: null,
        localUnitPriceFen: null,
        amountFen: 120000,
      ),
    );
    expect(find.text('不适用'), findsOneWidget);
    expect(find.text('未知'), findsNothing);
  });

  testWidgets(
    'hours record with local override surfaces local price over source',
    (tester) async {
      await pump(
        tester,
        _record(
          recordKind: ExternalWorkRecordKind.hours,
          sourceUnitPriceFen: 18000,
          localUnitPriceFen: 21000,
          amountFen: 147000,
        ),
      );
      expect(find.text('¥210 / h'), findsOneWidget);
    },
  );

  testWidgets(
    'hours record with legitimate 0 unit price shows "¥0 / h" (not 未知)',
    (tester) async {
      // 0 是合法的"真实单价为 0"语义（如赠送 / 抵账），不是 unknown。
      await pump(
        tester,
        _record(
          recordKind: ExternalWorkRecordKind.hours,
          sourceUnitPriceFen: 0,
          localUnitPriceFen: 0,
          amountFen: 0,
        ),
      );
      expect(find.text('¥0 / h'), findsOneWidget);
      expect(find.text('未知'), findsNothing);
    },
  );
}

ExternalWorkRecord _record({
  required ExternalWorkRecordKind recordKind,
  required int? sourceUnitPriceFen,
  required int? localUnitPriceFen,
  required int amountFen,
}) {
  return ExternalWorkRecord(
    id: 'r-1',
    importBatchId: 'b-1',
    sourceShareId: 's-1',
    sourceRecordUuid: 'src-1',
    sourceInstallationUuid: 'inst-1',
    originFingerprint: 'fp-1',
    collaboratorName: '李工',
    contactSnapshot: '张三',
    siteSnapshot: '工地A',
    workDate: 20240101,
    hoursMilli: 7000,
    sourceUnitPriceFen: sourceUnitPriceFen,
    localUnitPriceFen: localUnitPriceFen,
    amountFen: amountFen,
    recordKind: recordKind,
    createdAt: '2026-05-19T00:00:00.000Z',
    updatedAt: '2026-05-19T00:00:00.000Z',
  );
}
