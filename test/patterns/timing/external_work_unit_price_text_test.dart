import 'package:asset_ledger/data/models/external_work_record.dart';
import 'package:asset_ledger/features/timing/state/timing_external_work_store.dart';
import 'package:asset_ledger/patterns/timing/external_work_records_pattern.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 计时页"项目外协记录"详情弹窗的"单价"行展示规则（来源事实视图）：
/// - 从当前外协包 records 中按出现顺序汇总明确 sourceUnitPriceFen。
/// - 多个明确单价去重后用中文顿号连接。
/// - hours 且 sourceUnitPriceFen 非 null：显示 ¥xxx / h（0 也照常显示
///   `¥0 / h`，因为 0 是合法的"真实来源单价为 0"语义，不是 unknown）。
/// - rent / 台班或 sourceUnitPriceFen 为 null：不参与汇总。
/// - 没有任何明确来源单价时显示"未知"，绝不通过 amount / hours 反推。
///
/// 关键不变量：详情卡这里**不**回退到 localUnitPriceFen。
/// localUnitPriceFen 是接收方本地复核的外协应付/结算单价，账户页外协卡片
/// 才用 `localUnitPriceFen ?? sourceUnitPriceFen` 作为有效应付价；
/// 在计时页 "来源记录详情" 拉它，会把接收方复核值伪装成来源事实。
void main() {
  Future<void> pump(
    WidgetTester tester,
    ExternalWorkRecord record, {
    List<ExternalWorkRecord>? packageRecords,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExternalWorkRecordDetailContent(
            item: TimingExternalWorkRecordItem(record: record),
            packageItems: packageRecords
                ?.map((record) => TimingExternalWorkRecordItem(record: record))
                .toList(growable: false),
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

  testWidgets('rent record with no explicit source unit price shows "未知"', (
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
    expect(find.text('未知'), findsOneWidget);
    expect(find.text('不适用'), findsNothing);
  });

  testWidgets('package detail shows full source sites without ellipsis', (
    tester,
  ) async {
    final first = _record(
      id: 'r-1',
      siteSnapshot: '尚义',
      recordKind: ExternalWorkRecordKind.hours,
      sourceUnitPriceFen: 10000,
      localUnitPriceFen: 10000,
      amountFen: 100000,
    );

    await pump(
      tester,
      first,
      packageRecords: [
        first,
        _record(
          id: 'r-2',
          siteSnapshot: '富牛',
          recordKind: ExternalWorkRecordKind.hours,
          sourceUnitPriceFen: 18000,
          localUnitPriceFen: 18000,
          amountFen: 180000,
        ),
        _record(
          id: 'r-3',
          siteSnapshot: '青山湾',
          recordKind: ExternalWorkRecordKind.hours,
          sourceUnitPriceFen: 18000,
          localUnitPriceFen: 18000,
          amountFen: 180000,
        ),
      ],
    );

    expect(find.text('尚义+富牛+青山湾'), findsOneWidget);
    expect(find.textContaining('...'), findsNothing);
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

  testWidgets('package with multiple source prices shows all unique prices', (
    tester,
  ) async {
    final first = _record(
      id: 'r-1',
      recordKind: ExternalWorkRecordKind.hours,
      sourceUnitPriceFen: 10000,
      localUnitPriceFen: 10000,
      amountFen: 100000,
    );

    await pump(
      tester,
      first,
      packageRecords: [
        first,
        _record(
          id: 'r-2',
          recordKind: ExternalWorkRecordKind.hours,
          sourceUnitPriceFen: 18000,
          localUnitPriceFen: 18000,
          amountFen: 180000,
        ),
      ],
    );

    expect(find.text('¥100 / h、¥180 / h'), findsOneWidget);
  });

  testWidgets('package source prices are deduped in record order', (
    tester,
  ) async {
    final first = _record(
      id: 'r-1',
      recordKind: ExternalWorkRecordKind.hours,
      sourceUnitPriceFen: 10000,
      localUnitPriceFen: 10000,
      amountFen: 100000,
    );

    await pump(
      tester,
      first,
      packageRecords: [
        first,
        _record(
          id: 'r-2',
          recordKind: ExternalWorkRecordKind.hours,
          sourceUnitPriceFen: 10000,
          localUnitPriceFen: 10000,
          amountFen: 100000,
        ),
        _record(
          id: 'r-3',
          recordKind: ExternalWorkRecordKind.hours,
          sourceUnitPriceFen: 18000,
          localUnitPriceFen: 18000,
          amountFen: 180000,
        ),
      ],
    );

    expect(find.text('¥100 / h、¥180 / h'), findsOneWidget);
  });

  testWidgets('package ignores null/rent prices when explicit prices exist', (
    tester,
  ) async {
    final first = _record(
      id: 'r-1',
      recordKind: ExternalWorkRecordKind.hours,
      sourceUnitPriceFen: null,
      localUnitPriceFen: null,
      amountFen: 120000,
    );

    await pump(
      tester,
      first,
      packageRecords: [
        first,
        _record(
          id: 'r-2',
          recordKind: ExternalWorkRecordKind.rent,
          sourceUnitPriceFen: null,
          localUnitPriceFen: null,
          amountFen: 80000,
        ),
        _record(
          id: 'r-3',
          recordKind: ExternalWorkRecordKind.hours,
          sourceUnitPriceFen: 18000,
          localUnitPriceFen: 18000,
          amountFen: 180000,
        ),
      ],
    );

    expect(find.text('¥180 / h'), findsOneWidget);
    expect(find.text('未知'), findsNothing);
  });
}

ExternalWorkRecord _record({
  String id = 'r-1',
  String siteSnapshot = '工地A',
  required ExternalWorkRecordKind recordKind,
  required int? sourceUnitPriceFen,
  required int? localUnitPriceFen,
  required int amountFen,
}) {
  return ExternalWorkRecord(
    id: id,
    importBatchId: 'b-1',
    sourceShareId: 's-1',
    sourceRecordUuid: 'src-$id',
    sourceInstallationUuid: 'inst-1',
    originFingerprint: 'fp-1',
    collaboratorName: '李工',
    contactSnapshot: '张三',
    siteSnapshot: siteSnapshot,
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
