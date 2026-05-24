import 'package:asset_ledger/data/models/external_work_record.dart';
import 'package:asset_ledger/features/timing/state/timing_external_work_store.dart';
import 'package:asset_ledger/patterns/timing/external_work_records_pattern.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 计时页"项目外协记录"详情弹窗的"单价"行展示规则（来源事实视图）：
/// - rent / 台班：固定显示"不适用"。
/// - hours 且 sourceUnitPriceFen 非 null：显示 ¥xxx / h（0 也照常显示
///   `¥0 / h`，因为 0 是合法的"真实来源单价为 0"语义，不是 unknown）。
/// - hours 且 sourceUnitPriceFen 为 null：显示"未知"，绝不再显示 ¥0。
///
/// 关键不变量：详情卡这里**不**回退到 localUnitPriceFen。
/// localUnitPriceFen 是接收方本地复核的外协应付/结算单价，账户页外协卡片
/// 才用 `localUnitPriceFen ?? sourceUnitPriceFen` 作为有效应付价；
/// 在计时页 "来源记录详情" 拉它，会把接收方复核值伪装成来源事实。
void main() {
  Future<void> pump(WidgetTester tester, ExternalWorkRecord record) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExternalWorkRecordDetailContent(
            item: TimingExternalWorkRecordItem(record: record),
          ),
        ),
      ),
    );
  }

  testWidgets('hours record with known source unit price shows "¥xxx / h"', (
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

  testWidgets('hours record with null sourceUnitPriceFen shows "未知" (not ¥0)', (
    tester,
  ) async {
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
  });

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

  testWidgets('timing detail shows source price, NOT local override '
      '(source=¥180, local=¥210 → expect ¥180)', (tester) async {
    // 关键 regression：详情卡是"来源记录"，必须显示 ¥180。
    // localUnitPriceFen 是未来账户页外协应付的字段，不归这里显示。
    await pump(
      tester,
      _record(
        recordKind: ExternalWorkRecordKind.hours,
        sourceUnitPriceFen: 18000,
        localUnitPriceFen: 21000,
        amountFen: 126000,
      ),
    );
    expect(find.text('¥180 / h'), findsOneWidget);
    expect(find.text('¥210 / h'), findsNothing);
  });

  testWidgets(
    'timing detail surfaces 未知 when source is null even if local is set',
    (tester) async {
      // source 才是来源事实；source=null 时本地复核值不能冒名顶替 → "未知"。
      await pump(
        tester,
        _record(
          recordKind: ExternalWorkRecordKind.hours,
          sourceUnitPriceFen: null,
          localUnitPriceFen: 20000,
          amountFen: 140000,
        ),
      );
      expect(find.text('未知'), findsOneWidget);
      expect(find.text('¥200 / h'), findsNothing);
    },
  );

  testWidgets(
    'hours record with legitimate 0 source unit price shows "¥0 / h" (not 未知)',
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
