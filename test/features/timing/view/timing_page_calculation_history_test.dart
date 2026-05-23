import 'package:asset_ledger/app/adapters/account_merge_dissolve_adapter.dart';
import 'package:asset_ledger/data/models/account_project_merge_group.dart';
import 'package:asset_ledger/data/models/account_project_merge_group_with_members.dart';
import 'package:asset_ledger/data/models/account_project_merge_member.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/external_import_batch.dart';
import 'package:asset_ledger/data/models/external_work_record.dart';
import 'package:asset_ledger/data/models/fuel_log.dart';
import 'package:asset_ledger/data/models/maintenance_record.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/repositories/account_project_merge_repository.dart';
import 'package:asset_ledger/data/repositories/device_repository.dart';
import 'package:asset_ledger/data/repositories/external_import_repository.dart';
import 'package:asset_ledger/data/repositories/external_work_record_repository.dart';
import 'package:asset_ledger/data/repositories/fuel_repository.dart';
import 'package:asset_ledger/data/repositories/maintenance_repository.dart';
import 'package:asset_ledger/data/repositories/project_repository.dart';
import 'package:asset_ledger/data/repositories/project_rate_repository.dart';
import 'package:asset_ledger/data/repositories/timing_repository.dart';
import 'package:asset_ledger/data/services/account_project_merge_service.dart';
import 'package:asset_ledger/data/services/project_resolver.dart';
import 'package:asset_ledger/features/account/state/account_store.dart';
import 'package:asset_ledger/features/account/state/project_rate_store.dart';
import 'package:asset_ledger/features/device/state/device_store.dart';
import 'package:asset_ledger/features/fuel/state/fuel_store.dart';
import 'package:asset_ledger/features/maintenance/state/maintenance_store.dart';
import 'package:asset_ledger/features/timing/application/controllers/timing_action_controller.dart';
import 'package:asset_ledger/data/models/timing_calculation_history.dart';
import 'package:asset_ledger/data/repositories/timing_calculation_history_repository.dart';
import 'package:asset_ledger/features/timing/state/timing_external_work_store.dart';
import 'package:asset_ledger/features/timing/state/timing_store.dart';
import 'package:asset_ledger/features/timing/use_cases/timing_merge_dissolve_port.dart';
import 'package:asset_ledger/features/timing/view/timing_page.dart';
import 'package:asset_ledger/tokens/mapper/core_tokens.dart';
import 'package:asset_ledger/tokens/mapper/timing_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('loads existing calculation histories when editing a record', (
    WidgetTester tester,
  ) async {
    final historyRepository = _FakeCalculationHistoryRepository(
      histories: [_history()],
    );

    await _pumpTimingPage(tester, historyRepository: historyRepository);

    await tester.tap(find.text('甲方·一号工地'));
    await tester.pumpAndSettle();

    expect(historyRepository.findCalls, [7]);
    expect(find.text('编辑计时'), findsOneWidget);

    await tester.tap(find.byTooltip('工时计算依据'));
    await tester.pumpAndSettle();

    expect(find.textContaining('[已保存]'), findsNothing);
    expect(
      find.textContaining('8 + 8 = 16.0 h', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('does not query calculation histories for new records', (
    WidgetTester tester,
  ) async {
    final historyRepository = _FakeCalculationHistoryRepository();

    await _pumpTimingPage(tester, historyRepository: historyRepository);

    await tester.tap(find.text('+ 新建'));
    await tester.pumpAndSettle();

    expect(historyRepository.findCalls, isEmpty);
    expect(find.text('新建计时'), findsOneWidget);
  });

  testWidgets('does not query or show calculator histories for rent records', (
    WidgetTester tester,
  ) async {
    final historyRepository = _FakeCalculationHistoryRepository(
      histories: [_history()],
    );

    await _pumpTimingPage(
      tester,
      timingRepository: _FakeTimingRepository(
        seed: [_record(type: TimingType.rent)],
      ),
      historyRepository: historyRepository,
    );

    await tester.tap(find.text('甲方·一号工地'));
    await tester.pumpAndSettle();

    expect(historyRepository.findCalls, isEmpty);
    expect(find.text('编辑计时'), findsOneWidget);
    expect(find.byTooltip('工时计算依据'), findsNothing);
  });

  testWidgets('history load failure does not block opening the editor', (
    WidgetTester tester,
  ) async {
    final historyRepository = _FakeCalculationHistoryRepository(
      shouldThrow: true,
    );

    await _pumpTimingPage(tester, historyRepository: historyRepository);

    await tester.tap(find.text('甲方·一号工地'));
    await tester.pumpAndSettle();

    expect(historyRepository.findCalls, [7]);
    expect(find.text('编辑计时'), findsOneWidget);
    expect(find.byTooltip('工时计算依据'), findsOneWidget);
  });

  testWidgets('canceling the editor does not save staged histories', (
    WidgetTester tester,
  ) async {
    final timingRepository = _FakeTimingRepository(seed: [_record()]);

    await _pumpTimingPage(
      tester,
      timingRepository: timingRepository,
      historyRepository: _FakeCalculationHistoryRepository(),
    );

    await tester.tap(find.text('甲方·一号工地'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();

    expect(timingRepository.saveCalls, 0);
    expect(timingRepository.savedCalculationHistories, isEmpty);
  });

  testWidgets('new timing editor keeps cancel action and hides delete', (
    WidgetTester tester,
  ) async {
    await _pumpTimingPage(
      tester,
      historyRepository: _FakeCalculationHistoryRepository(),
    );

    await tester.tap(find.text('+ 新建'));
    await tester.pumpAndSettle();

    expect(find.text('新建计时'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '取消'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '删除'), findsNothing);
  });

  testWidgets('editing timing shows destructive delete action', (
    WidgetTester tester,
  ) async {
    await _pumpTimingPage(
      tester,
      historyRepository: _FakeCalculationHistoryRepository(),
    );

    await tester.tap(find.text('甲方·一号工地'));
    await tester.pumpAndSettle();

    final deleteButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '删除'),
    );
    expect(
      deleteButton.style?.foregroundColor?.resolve(<WidgetState>{}),
      Colors.red.shade600,
    );
  });

  testWidgets('editing delete opens confirm dialog and cancel keeps record', (
    WidgetTester tester,
  ) async {
    final timingRepository = _FakeTimingRepository(seed: [_record()]);

    await _pumpTimingPage(
      tester,
      timingRepository: timingRepository,
      historyRepository: _FakeCalculationHistoryRepository(),
    );

    await tester.tap(find.text('甲方·一号工地'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();

    expect(find.text('删除计时记录'), findsOneWidget);
    expect(find.text('删除后不可恢复，确认删除这条记录吗？'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '取消').last);
    await tester.pumpAndSettle();

    expect(timingRepository.deletedIds, isEmpty);
    expect(find.text('编辑计时'), findsOneWidget);
    expect(find.text('甲方·一号工地'), findsOneWidget);
  });

  testWidgets('editing delete confirmation removes record and closes sheet', (
    WidgetTester tester,
  ) async {
    final timingRepository = _FakeTimingRepository(seed: [_record()]);

    await _pumpTimingPage(
      tester,
      timingRepository: timingRepository,
      historyRepository: _FakeCalculationHistoryRepository(),
    );

    await tester.tap(find.text('甲方·一号工地'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(timingRepository.deletedIds, [7]);
    expect(find.text('编辑计时'), findsNothing);
    expect(find.text('甲方·一号工地'), findsNothing);
  });

  testWidgets('recent timing records no longer expose swipe delete', (
    WidgetTester tester,
  ) async {
    await _pumpTimingPage(
      tester,
      historyRepository: _FakeCalculationHistoryRepository(),
    );

    expect(find.byType(Dismissible), findsNothing);
  });

  testWidgets('timing records section defaults to recent records', (
    WidgetTester tester,
  ) async {
    await _pumpTimingPage(
      tester,
      historyRepository: _FakeCalculationHistoryRepository(),
    );

    expect(find.text('最近记录(1)'), findsOneWidget);
    expect(find.text('最近记录'), findsNothing);
    expect(find.text('项目外协'), findsNothing);
    expect(find.text('甲方·一号工地'), findsOneWidget);
    expect(find.text('暂无项目外协记录'), findsNothing);
  });

  testWidgets('recent records reserve space above bottom tab bar', (
    WidgetTester tester,
  ) async {
    await _pumpTimingPage(
      tester,
      historyRepository: _FakeCalculationHistoryRepository(),
    );

    final spacer = tester.widget<SizedBox>(_bottomNavigationSpacer());

    expect(
      spacer.height,
      NavigationTokens.barHeight + TimingTokens.homeBottomGap,
    );
  });

  testWidgets('external work section shows empty scaffold', (
    WidgetTester tester,
  ) async {
    await _pumpTimingPage(
      tester,
      historyRepository: _FakeCalculationHistoryRepository(),
    );

    await _switchToExternalWork(tester);

    expect(find.text('项目外协(0)'), findsOneWidget);
    expect(find.text('项目外协(0条)'), findsNothing);
    expect(
      find.byKey(const Key('timing-external-work-header-import')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('timing-external-work-header-link')),
      findsNothing,
    );
    expect(find.text('导入'), findsOneWidget);
    expect(find.text('关联'), findsNothing);
    expect(find.text('导入项目外协包'), findsNothing);
    expect(find.text('暂无项目外协记录'), findsOneWidget);
    expect(find.text('从他人分享的 .jzt 文件导入后，会显示在这里'), findsOneWidget);
    expect(find.text('甲方·一号工地'), findsNothing);
  });

  testWidgets('external work section reserves space above bottom tab bar', (
    WidgetTester tester,
  ) async {
    await _pumpTimingPage(
      tester,
      historyRepository: _FakeCalculationHistoryRepository(),
    );

    await _switchToExternalWork(tester);

    final spacer = tester.widget<SizedBox>(_bottomNavigationSpacer());

    expect(
      spacer.height,
      NavigationTokens.barHeight + TimingTokens.homeBottomGap,
    );
  });

  testWidgets('can switch from external work section back to recent records', (
    WidgetTester tester,
  ) async {
    await _pumpTimingPage(
      tester,
      historyRepository: _FakeCalculationHistoryRepository(),
    );

    await _switchToExternalWork(tester);
    await _switchToRecentRecords(tester);

    expect(find.text('导入'), findsNothing);
    expect(find.text('关联'), findsNothing);
    expect(find.text('最近记录(1)'), findsOneWidget);
    expect(find.text('暂无项目外协记录'), findsNothing);
    expect(find.text('甲方·一号工地'), findsOneWidget);
  });

  testWidgets('recent records remain editable after switching sections', (
    WidgetTester tester,
  ) async {
    await _pumpTimingPage(
      tester,
      historyRepository: _FakeCalculationHistoryRepository(),
    );

    await _switchToExternalWork(tester);
    await _switchToRecentRecords(tester);
    await tester.tap(find.text('甲方·一号工地'));
    await tester.pumpAndSettle();

    expect(find.text('编辑计时'), findsOneWidget);
  });

  testWidgets('external work empty scaffold has no edit or delete entry', (
    WidgetTester tester,
  ) async {
    await _pumpTimingPage(
      tester,
      historyRepository: _FakeCalculationHistoryRepository(),
    );

    await _switchToExternalWork(tester);

    expect(find.text('新增'), findsNothing);
    expect(find.text('编辑计时'), findsNothing);
    expect(find.widgetWithText(TextButton, '删除'), findsNothing);
  });

  testWidgets('external work section renders imported records read-only list', (
    WidgetTester tester,
  ) async {
    await _pumpTimingPage(
      tester,
      historyRepository: _FakeCalculationHistoryRepository(),
      externalBatches: [_externalBatch()],
      externalRecords: [_externalRecord()],
    );

    await _switchToExternalWork(tester);

    expect(
      find.byKey(const Key('timing-external-work-header-import')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('timing-external-work-header-link')),
      findsOneWidget,
    );
    expect(find.text('导入项目外协包'), findsNothing);
    expect(find.text('2026年'), findsWidgets);
    expect(find.text('王师傅分享包 · 东区工地'), findsOneWidget);
    expect(find.text('CAT'), findsOneWidget);
    expect(find.text('2026.05.12'), findsOneWidget);
    expect(find.text('1条 / 8.5 h'), findsOneWidget);
    expect(find.text('¥987.65'), findsNothing);
    expect(find.text('¥123.45'), findsNothing);
    expect(find.text('batch-1'), findsNothing);
    expect(find.text('share-1'), findsNothing);
    expect(find.text('source-record-1'), findsNothing);
    expect(find.text('payload-sha256-hidden'), findsNothing);
  });

  testWidgets('tapping 关联 opens the link-to-project sheet skeleton', (
    WidgetTester tester,
  ) async {
    await _pumpTimingPage(
      tester,
      historyRepository: _FakeCalculationHistoryRepository(),
      externalBatches: [_externalBatch()],
      externalRecords: [_externalRecord()],
    );

    await _switchToExternalWork(tester);
    await tester.tap(find.byKey(const Key('timing-external-work-header-link')));
    await tester.pumpAndSettle();

    // 弹窗标题。
    expect(find.text('关联到项目'), findsOneWidget);
    // 外协包摘要次行（设备 · N条记录 · 累计工时）唯一存在于弹窗内。
    expect(find.text('CAT · 1条记录 · 8.5h'), findsOneWidget);
    // 不出现"合并X项目"。
    expect(find.textContaining('合并'), findsNothing);
    // 候选项目区已渲染（非空）。
    expect(find.text('选择要关联的项目'), findsOneWidget);
    expect(find.text('暂无可关联的自有项目'), findsNothing);
    // 确认关联按钮存在（占位，不写库）。
    expect(find.byKey(const Key('external-work-link-confirm')), findsOneWidget);
  });

  testWidgets(
    'external work section aggregates records in the same share group',
    (WidgetTester tester) async {
      await _pumpTimingPage(
        tester,
        historyRepository: _FakeCalculationHistoryRepository(),
        externalBatches: [
          _externalBatch(recordCount: 2, totalHoursMilli: 10500),
        ],
        externalRecords: [
          _externalRecord(),
          _externalRecord(
            id: 'external-2',
            sourceRecordUuid: 'source-record-2',
            workDate: 20260513,
            hoursMilli: 2000,
          ),
        ],
      );

      await _switchToExternalWork(tester);

      expect(find.text('项目外协(1)'), findsOneWidget);
      expect(find.text('项目外协(2)'), findsNothing);
      expect(find.text('王师傅分享包 · 东区工地'), findsOneWidget);
      expect(find.text('2026.05.12-2026.05.13'), findsNothing);
      expect(find.text('2026.05.12'), findsOneWidget);
      expect(find.text('2条 / 10.5 h'), findsOneWidget);
      expect(find.text('2026.05.13'), findsNothing);
    },
  );

  testWidgets('external work section keeps one share package as one top item', (
    WidgetTester tester,
  ) async {
    await _pumpTimingPage(
      tester,
      historyRepository: _FakeCalculationHistoryRepository(),
      externalBatches: [_externalBatch(recordCount: 2, totalHoursMilli: 10500)],
      externalRecords: [
        _externalRecord(siteSnapshot: '鲜滩'),
        _externalRecord(
          id: 'external-2',
          sourceRecordUuid: 'source-record-2',
          siteSnapshot: '五里山',
          workDate: 20260513,
          hoursMilli: 2000,
        ),
      ],
    );

    await _switchToExternalWork(tester);

    expect(find.text('项目外协(1)'), findsOneWidget);
    expect(find.text('项目外协(2)'), findsNothing);
    expect(find.text('王师傅分享包 · 鲜滩+五里山'), findsOneWidget);
    expect(find.text('王师傅分享包 · 鲜滩'), findsNothing);
    expect(find.text('王师傅分享包 · 五里山'), findsNothing);
    expect(find.text('2条 / 10.5 h'), findsOneWidget);
  });

  testWidgets('external work package opens representative detail', (
    WidgetTester tester,
  ) async {
    await _pumpTimingPage(
      tester,
      historyRepository: _FakeCalculationHistoryRepository(),
      externalBatches: [_externalBatch(recordCount: 2, totalHoursMilli: 10500)],
      externalRecords: [
        _externalRecord(),
        _externalRecord(
          id: 'external-2',
          sourceRecordUuid: 'source-record-2',
          workDate: 20260513,
          hoursMilli: 2000,
        ),
      ],
    );

    await _switchToExternalWork(tester);
    await tester.tap(find.text('王师傅分享包 · 东区工地'));
    await tester.pumpAndSettle();

    expect(find.text('项目外协记录'), findsOneWidget);
    expect(find.text('分享人'), findsOneWidget);
    expect(find.text('王师傅分享包'), findsOneWidget);
    expect(find.text('2026.05.12'), findsWidgets);
    expect(find.text('2026.05.13'), findsNothing);
    expect(find.text('8.5 h'), findsWidgets);
    expect(find.text('2.0 h'), findsNothing);
  });

  testWidgets('external work linked state controls link icon', (
    WidgetTester tester,
  ) async {
    await _pumpTimingPage(
      tester,
      historyRepository: _FakeCalculationHistoryRepository(),
      externalBatches: [_externalBatch()],
      externalRecords: [_externalRecord()],
    );

    await _switchToExternalWork(tester);
    expect(find.byIcon(Icons.link), findsOneWidget);

    await _pumpTimingPage(
      tester,
      historyRepository: _FakeCalculationHistoryRepository(),
      externalBatches: [_externalBatch()],
      externalRecords: [
        _externalRecord(linkedProjectId: 'project-1', projectReceivedFen: 0),
      ],
    );

    await _switchToExternalWork(tester);
    expect(find.byIcon(Icons.link), findsNWidgets(2));
  });

  testWidgets('confirming a candidate is a placeholder (no DB write)', (
    WidgetTester tester,
  ) async {
    await _pumpTimingPage(
      tester,
      historyRepository: _FakeCalculationHistoryRepository(),
      externalBatches: [_externalBatch()],
      externalRecords: [_externalRecord()],
    );

    await _switchToExternalWork(tester);
    await tester.tap(find.byKey(const Key('timing-external-work-header-link')));
    await tester.pumpAndSettle();

    // 选中第一个候选项目（projectId 由账户聚合生成，按 key 前缀定位）。
    final candidate = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key as ValueKey<String>).value.startsWith(
            'external-work-link-candidate-',
          ),
    );
    expect(candidate, findsWidgets);
    await tester.tap(candidate.first);
    await tester.pump();

    // 确认关联：仅占位提示，不写库。
    await tester.tap(find.byKey(const Key('external-work-link-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('关联写入将在下一阶段开放'), findsOneWidget);
  });

  testWidgets('external work item opens read-only detail sheet', (
    WidgetTester tester,
  ) async {
    await _pumpTimingPage(
      tester,
      historyRepository: _FakeCalculationHistoryRepository(),
      externalBatches: [_externalBatch()],
      externalRecords: [_externalRecord(linkedProjectId: 'project-1')],
    );

    await _switchToExternalWork(tester);
    await tester.tap(find.text('王师傅分享包 · 东区工地'));
    await tester.pumpAndSettle();

    expect(find.text('项目外协记录'), findsOneWidget);
    expect(find.text('从分享包导入'), findsOneWidget);
    expect(find.text('分享人'), findsOneWidget);
    expect(find.text('王师傅分享包'), findsOneWidget);
    expect(find.text('分享包'), findsNothing);
    expect(find.text('东区工地'), findsOneWidget);
    expect(find.text('CAT / 320D / 挖机'), findsOneWidget);
    expect(find.text('2026.05.12'), findsWidgets);
    expect(find.text('8.5 h'), findsWidgets);
    // 计时页外协详情显示来源事实单价（sourceUnitPriceFen=12000 → ¥120 / h），
    // 不显示接收方复核值 localUnitPriceFen=12345 → ¥123（那是账户页字段）。
    // 金额行仍是 ¥xxx。
    expect(find.text('¥120 / h'), findsOneWidget);
    expect(find.text('¥123 / h'), findsNothing);
    expect(find.text('¥1049'), findsOneWidget);
    expect(find.textContaining('已收到项目款'), findsNothing);
    expect(find.text('已收项目款'), findsNothing);
    expect(find.text('2026-05-13T10:00:00.000Z'), findsOneWidget);
    expect(find.text('已关联'), findsOneWidget);
    expect(find.text('这条记录来自他人分享，当前不可编辑。'), findsOneWidget);
    expect(find.text('不应展示的联系人'), findsNothing);
    expect(find.widgetWithText(FilledButton, '知道了'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '删除记录'), findsOneWidget);
    final closeButton = find.widgetWithText(FilledButton, '知道了');
    final deleteButton = find.widgetWithText(OutlinedButton, '删除记录');
    final buttonGap =
        tester.getTopLeft(deleteButton).dy -
        tester.getBottomLeft(closeButton).dy;
    expect(buttonGap, greaterThanOrEqualTo(20));
    expect(find.widgetWithText(FilledButton, '保存'), findsNothing);
    expect(find.widgetWithText(TextButton, '编辑'), findsNothing);
    expect(find.widgetWithText(TextButton, '删除'), findsNothing);
    expect(find.widgetWithText(TextButton, '关联项目'), findsNothing);
    expect(find.widgetWithText(TextButton, '合并'), findsNothing);
    expect(find.widgetWithText(TextButton, '抵扣'), findsNothing);
    expect(find.widgetWithText(TextButton, '核销'), findsNothing);
  });

  testWidgets(
    'external work detail shows project received payment when shared',
    (WidgetTester tester) async {
      await _pumpTimingPage(
        tester,
        historyRepository: _FakeCalculationHistoryRepository(),
        externalBatches: [_externalBatch()],
        externalRecords: [_externalRecord(projectReceivedFen: 98765)],
      );

      await _switchToExternalWork(tester);
      await tester.tap(find.text('王师傅分享包 · 东区工地'));
      await tester.pumpAndSettle();

      expect(find.text('已收项目款'), findsOneWidget);
      expect(find.text('¥988'), findsOneWidget);
      expect(find.textContaining('已收到项目款'), findsNothing);
      expect(find.textContaining('已收项目款：'), findsNothing);
    },
  );

  testWidgets('external work detail delete removes record from section', (
    WidgetTester tester,
  ) async {
    await _pumpTimingPage(
      tester,
      historyRepository: _FakeCalculationHistoryRepository(),
      externalBatches: [_externalBatch()],
      externalRecords: [_externalRecord()],
    );

    await _switchToExternalWork(tester);
    expect(find.text('王师傅分享包 · 东区工地'), findsOneWidget);

    await tester.tap(find.text('王师傅分享包 · 东区工地'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '删除记录'));
    await tester.pumpAndSettle();

    expect(find.text('删除项目外协记录'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(find.text('王师傅分享包 · 东区工地'), findsNothing);
    expect(find.text('暂无项目外协记录'), findsOneWidget);
    expect(find.text('已删除'), findsOneWidget);
  });

  testWidgets(
    'external work detail delete removes the whole import batch only',
    (WidgetTester tester) async {
      await _pumpTimingPage(
        tester,
        historyRepository: _FakeCalculationHistoryRepository(),
        externalBatches: [
          _externalBatch(
            recordCount: 3,
            totalHoursMilli: 12500,
            siteSummary: '鲜滩、五里山',
          ),
          _externalBatch(
            id: 'batch-2',
            sourceShareId: 'share-2',
            sourceDisplayName: '李师傅分享包',
            recordCount: 1,
            siteSummary: '北区工地',
          ),
        ],
        externalRecords: [
          _externalRecord(siteSnapshot: '鲜滩'),
          _externalRecord(
            id: 'external-2',
            sourceRecordUuid: 'source-record-2',
            siteSnapshot: '鲜滩',
            workDate: 20260513,
            hoursMilli: 2000,
          ),
          _externalRecord(
            id: 'external-3',
            sourceRecordUuid: 'source-record-3',
            siteSnapshot: '五里山',
            workDate: 20260514,
            hoursMilli: 2000,
          ),
          _externalRecord(
            id: 'external-other',
            importBatchId: 'batch-2',
            sourceShareId: 'share-2',
            sourceRecordUuid: 'source-record-other',
            siteSnapshot: '北区工地',
          ),
        ],
      );

      await _switchToExternalWork(tester);
      expect(find.text('项目外协(2)'), findsOneWidget);
      await tester.tap(find.text('王师傅分享包 · 鲜滩+五里山'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, '删除记录'));
      await tester.pumpAndSettle();

      expect(find.textContaining('分享包'), findsWidgets);
      expect(find.textContaining('全部 3 条'), findsOneWidget);
      expect(find.textContaining('不可恢复'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, '删除'));
      await tester.pumpAndSettle();

      expect(find.text('王师傅分享包 · 鲜滩'), findsNothing);
      expect(find.text('王师傅分享包 · 五里山'), findsNothing);
      expect(find.text('王师傅分享包 · 鲜滩+五里山'), findsNothing);
      expect(find.text('李师傅分享包 · 北区工地'), findsOneWidget);
    },
  );

  testWidgets(
    'keeps merge group after editing project address on same projectId',
    (WidgetTester tester) async {
      final timingRepository = _FakeTimingRepository(seed: [_record()]);
      final mergeRepository = _FakeAccountProjectMergeRepository(
        group: _mergeGroup(),
        members: _mergeMembers(),
      );

      await _pumpTimingPage(
        tester,
        timingRepository: timingRepository,
        historyRepository: _FakeCalculationHistoryRepository(),
        mergeRepository: mergeRepository,
      );

      await tester.tap(find.text('甲方·一号工地'));
      await tester.pumpAndSettle();

      await tester.enterText(_textFieldWithLabel('使用地址/工地'), '一号工地新址');
      await tester.tap(find.widgetWithText(FilledButton, '确定'));
      await tester.pumpAndSettle();

      expect(timingRepository.saveCalls, 1);
      expect(timingRepository.savedRecords.single.site, '一号工地新址');
      expect(mergeRepository.dissolvedGroupIds, isEmpty);
      expect(mergeRepository.group?.isActive, isTrue);
      expect(
        mergeRepository.members.every((member) => member.isActive),
        isTrue,
      );
    },
  );

  testWidgets(
    'does not show dissolve retry when only project attributes change',
    (WidgetTester tester) async {
      final timingRepository = _FakeTimingRepository(seed: [_record()]);
      final mergeRepository = _FakeAccountProjectMergeRepository(
        group: _mergeGroup(),
        members: _mergeMembers(),
        failDissolveCount: 1,
      );

      await _pumpTimingPage(
        tester,
        timingRepository: timingRepository,
        historyRepository: _FakeCalculationHistoryRepository(),
        mergeRepository: mergeRepository,
      );

      await tester.tap(find.text('甲方·一号工地'));
      await tester.pumpAndSettle();

      await tester.enterText(_textFieldWithLabel('使用地址/工地'), '一号工地新址');
      await tester.tap(find.widgetWithText(FilledButton, '确定'));
      await tester.pumpAndSettle();

      expect(timingRepository.saveCalls, 1);
      expect(mergeRepository.dissolvedGroupIds, isEmpty);
      expect(mergeRepository.group?.isActive, isTrue);
      expect(find.text('合并项目未解除'), findsNothing);
      expect(find.text('编辑计时'), findsNothing);
    },
  );

  testWidgets(
    'keeps merge group when editing hours without project key change',
    (WidgetTester tester) async {
      final timingRepository = _FakeTimingRepository(seed: [_record()]);
      final mergeRepository = _FakeAccountProjectMergeRepository(
        group: _mergeGroup(),
        members: _mergeMembers(),
      );

      await _pumpTimingPage(
        tester,
        timingRepository: timingRepository,
        historyRepository: _FakeCalculationHistoryRepository(),
        mergeRepository: mergeRepository,
      );

      await tester.tap(find.text('甲方·一号工地'));
      await tester.pumpAndSettle();

      await tester.tap(_textFieldWithLabel('工时（小时）'));
      await tester.pumpAndSettle();
      await _tapCalculatorTextKey(tester, '2');
      await _tapCalculatorTextKey(tester, '0');
      await tester.tap(find.widgetWithText(FilledButton, '=').last);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, '确定'));
      await tester.pumpAndSettle();

      expect(timingRepository.saveCalls, 1);
      expect(timingRepository.savedRecords.single.contact, '甲方');
      expect(timingRepository.savedRecords.single.site, '一号工地');
      expect(mergeRepository.dissolvedGroupIds, isEmpty);
      expect(mergeRepository.group?.isActive, isTrue);
    },
  );
}

Future<void> _pumpTimingPage(
  WidgetTester tester, {
  _FakeTimingRepository? timingRepository,
  required TimingCalculationHistoryRepository historyRepository,
  _FakeAccountProjectMergeRepository? mergeRepository,
  List<ExternalImportBatch> externalBatches = const [],
  List<ExternalWorkRecord> externalRecords = const [],
}) async {
  tester.view.physicalSize = const Size(800, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final deviceRepository = _FakeDeviceRepository(seed: [_device()]);
  final resolvedTimingRepository =
      timingRepository ?? _FakeTimingRepository(seed: [_record()]);
  final fuelRepository = _FakeFuelRepository();
  final maintenanceRepository = _FakeMaintenanceRepository();
  final rateRepository = _FakeProjectRateRepository();
  final externalWorkStore = TimingExternalWorkStore(
    importRepository: _FakeExternalImportRepository(seed: externalBatches),
    recordRepository: _FakeExternalWorkRecordRepository(seed: externalRecords),
  );
  final projectResolver = ProjectResolver(
    projectRepository: _FakeProjectRepository(),
    now: () => DateTime.utc(2026, 5, 15),
  );

  final deviceStore = DeviceStore(deviceRepository);
  final timingStore = TimingStore(resolvedTimingRepository);
  final fuelStore = FuelStore(fuelRepository);
  final maintenanceStore = MaintenanceStore(maintenanceRepository);
  final rateStore = ProjectRateStore(rateRepository);
  final accountStore = AccountStore();
  final resolvedMergeRepository =
      mergeRepository ?? _FakeAccountProjectMergeRepository();
  final mergeService = AccountProjectMergeService(
    repository: resolvedMergeRepository,
    now: () => DateTime.utc(2026, 5, 15, 1, 2, 3),
  );

  await deviceStore.loadAll();
  await timingStore.loadAll();
  await fuelStore.loadAll();
  await maintenanceStore.loadAll();
  await rateStore.loadAll();
  await accountStore.loadAll();
  await externalWorkStore.loadAll();

  await tester.pumpWidget(
    MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<DeviceStore>.value(value: deviceStore),
          ChangeNotifierProvider<TimingStore>.value(value: timingStore),
          ChangeNotifierProvider<FuelStore>.value(value: fuelStore),
          ChangeNotifierProvider<MaintenanceStore>.value(
            value: maintenanceStore,
          ),
          ChangeNotifierProvider<ProjectRateStore>.value(value: rateStore),
          ChangeNotifierProvider<AccountStore>.value(value: accountStore),
          ChangeNotifierProvider<TimingExternalWorkStore>.value(
            value: externalWorkStore,
          ),
          Provider<AccountProjectMergeService>.value(value: mergeService),
          Provider<TimingMergeDissolvePort>.value(
            value: AccountMergeDissolveAdapter(mergeService),
          ),
          Provider<ProjectResolver>.value(value: projectResolver),
          Provider<TimingActionController>.value(
            value: TimingActionController(
              calculationHistoryRepository: historyRepository,
              projectResolver: projectResolver,
            ),
          ),
        ],
        child: TimingPage(calculationHistoryRepository: historyRepository),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Device _device() {
  return const Device(
    id: 1,
    name: 'SANY 1#',
    brand: 'SANY',
    defaultUnitPrice: 100,
    baseMeterHours: 0,
  );
}

Finder _textFieldWithLabel(String label) {
  return find.byWidgetPredicate((widget) {
    return widget is TextField && widget.decoration?.labelText == label;
  });
}

Finder _bottomNavigationSpacer() {
  return find.byKey(const Key('timing-home-bottom-navigation-spacer'));
}

Future<void> _switchToExternalWork(WidgetTester tester) async {
  await tester.drag(find.byType(TabBarView), const Offset(-500, 0));
  await tester.pumpAndSettle();
}

Future<void> _switchToRecentRecords(WidgetTester tester) async {
  await tester.drag(find.byType(TabBarView), const Offset(500, 0));
  await tester.pumpAndSettle();
}

Future<void> _tapCalculatorTextKey(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(OutlinedButton, label).last);
  await tester.pumpAndSettle();
}

TimingRecord _record({TimingType type = TimingType.hours}) {
  return TimingRecord(
    id: 7,
    deviceId: 1,
    startDate: 20260514,
    contact: '甲方',
    site: '一号工地',
    type: type,
    startMeter: 0,
    endMeter: 16,
    hours: 16,
    income: 1600,
  );
}

TimingCalculationHistory _history() {
  return TimingCalculationHistory(
    id: 'saved-h1',
    timingRecordId: 7,
    createdAt: DateTime.utc(2026, 5, 13, 18, 20),
    expression: '8+8',
    result: 16.0,
    ticketCount: 2,
  );
}

ExternalImportBatch _externalBatch({
  String id = 'batch-1',
  String sourceShareId = 'share-1',
  String sourceDisplayName = '王师傅分享包',
  int recordCount = 1,
  int totalHoursMilli = 8500,
  int totalAmountFen = 104933,
  String siteSummary = '东区工地',
}) {
  return ExternalImportBatch(
    id: id,
    sourceShareId: sourceShareId,
    sourceDisplayName: sourceDisplayName,
    recordCount: recordCount,
    totalHoursMilli: totalHoursMilli,
    totalAmountFen: totalAmountFen,
    siteSummary: siteSummary,
    importedAt: '2026-05-13T10:00:00.000Z',
    createdAt: '2026-05-13T10:00:00.000Z',
    updatedAt: '2026-05-13T10:00:00.000Z',
  );
}

ExternalWorkRecord _externalRecord({
  String id = 'external-1',
  String importBatchId = 'batch-1',
  String sourceShareId = 'share-1',
  String sourceRecordUuid = 'source-record-1',
  String? linkedProjectId,
  int projectReceivedFen = 0,
  String siteSnapshot = '东区工地',
  String equipmentBrand = 'CAT',
  String equipmentModel = '320D',
  String equipmentType = '挖机',
  int workDate = 20260512,
  int hoursMilli = 8500,
}) {
  return ExternalWorkRecord(
    id: id,
    importBatchId: importBatchId,
    sourceShareId: sourceShareId,
    sourceRecordUuid: sourceRecordUuid,
    sourceInstallationUuid: 'source-installation-1',
    originFingerprint: 'payload-sha256-hidden',
    collaboratorName: '王师傅',
    contactSnapshot: '不应展示的联系人',
    siteSnapshot: siteSnapshot,
    equipmentBrand: equipmentBrand,
    equipmentModel: equipmentModel,
    equipmentType: equipmentType,
    workDate: workDate,
    hoursMilli: hoursMilli,
    sourceUnitPriceFen: 12000,
    localUnitPriceFen: 12345,
    amountFen: 104933,
    projectReceivedFen: projectReceivedFen,
    linkedProjectId: linkedProjectId,
    createdAt: '2026-05-13T10:05:00.000Z',
    updatedAt: '2026-05-13T10:05:00.000Z',
  );
}

class _FakeCalculationHistoryRepository
    implements TimingCalculationHistoryRepository {
  _FakeCalculationHistoryRepository({
    this.histories = const [],
    this.shouldThrow = false,
  });

  final List<TimingCalculationHistory> histories;
  final bool shouldThrow;
  final List<int> findCalls = [];

  @override
  Future<List<TimingCalculationHistory>> findByTimingRecordId(
    int timingRecordId,
  ) async {
    findCalls.add(timingRecordId);
    if (shouldThrow) throw Exception('load failed');
    return histories
        .where((history) => history.timingRecordId == timingRecordId)
        .toList();
  }

  @override
  Future<void> insertMany(
    int timingRecordId,
    List<TimingCalculationHistory> histories,
  ) async {}

  @override
  Future<void> deleteByTimingRecordId(int timingRecordId) async {}
}

class _FakeTimingRepository implements TimingRepository {
  _FakeTimingRepository({required List<TimingRecord> seed})
    : _records = List.of(seed);

  final List<TimingRecord> _records;
  final List<TimingRecord> savedRecords = [];
  final List<List<TimingCalculationHistory>> savedCalculationHistories = [];
  final List<int> deletedIds = [];
  var saveCalls = 0;

  @override
  Future<List<TimingRecord>> listAll() async => List.of(_records);

  @override
  Future<int> insert(TimingRecord record) async => 1;

  @override
  Future<int> update(TimingRecord record) async => 1;

  @override
  Future<TimingRecord> saveWithCalculationHistories(
    TimingRecord record, {
    List<TimingCalculationHistory> calculationHistories = const [],
  }) async {
    saveCalls++;
    savedRecords.add(record);
    savedCalculationHistories.add(List.of(calculationHistories));
    return record.id == null ? record.copyWith(id: 1) : record;
  }

  @override
  Future<int> deleteById(int id) async {
    deletedIds.add(id);
    return 1;
  }

  @override
  Future<int> deleteByIds(Iterable<int> ids) async => ids.length;

  @override
  Future<int> deleteByDeviceId(int deviceId) async => 1;
}

class _FakeExternalImportRepository implements ExternalImportRepository {
  _FakeExternalImportRepository({required List<ExternalImportBatch> seed})
    : _batches = List.of(seed);

  final List<ExternalImportBatch> _batches;

  @override
  Future<void> insertBatch(ExternalImportBatch batch) async {
    _batches.add(batch);
  }

  @override
  Future<ExternalImportBatch?> findBatchById(String id) async {
    for (final batch in _batches) {
      if (batch.id == id) return batch;
    }
    return null;
  }

  @override
  Future<List<ExternalImportBatch>> listBatches() async => List.of(_batches);
}

class _FakeExternalWorkRecordRepository
    implements ExternalWorkRecordRepository {
  _FakeExternalWorkRecordRepository({required List<ExternalWorkRecord> seed})
    : _records = List.of(seed);

  final List<ExternalWorkRecord> _records;

  @override
  Future<void> insertRecord(ExternalWorkRecord record) async {
    _records.add(record);
  }

  @override
  Future<void> insertRecords(List<ExternalWorkRecord> records) async {
    _records.addAll(records);
  }

  @override
  Future<List<ExternalWorkRecord>> listByBatchId(String batchId) async {
    return _records
        .where((record) => record.importBatchId == batchId)
        .toList(growable: false);
  }

  @override
  Future<List<ExternalWorkRecord>> listByLinkedProjectId(
    String projectId,
  ) async {
    return _records
        .where((record) => record.linkedProjectId == projectId)
        .toList(growable: false);
  }

  @override
  Future<int> deleteById(String recordId) async {
    final before = _records.length;
    _records.removeWhere((record) => record.id == recordId);
    return before - _records.length;
  }

  @override
  Future<int> deleteByBatchId(String batchId) async {
    final before = _records.length;
    _records.removeWhere((record) => record.importBatchId == batchId);
    return before - _records.length;
  }

  @override
  Future<int> updateLocalFields({
    required String recordId,
    int? localUnitPriceFen,
    Object? linkedProjectId = _externalSentinel,
    ExternalWorkRecordStatus? status,
    Object? note = _externalSentinel,
    required String updatedAt,
  }) async {
    return 0;
  }
}

const _externalSentinel = Object();

class _FakeDeviceRepository implements DeviceRepository {
  _FakeDeviceRepository({required List<Device> seed}) : _devices = seed;

  final List<Device> _devices;

  @override
  Future<List<Device>> listAll() async => List.of(_devices);

  @override
  Future<List<Device>> listActive() async {
    return _devices.where((device) => device.isActive).toList();
  }

  @override
  Future<Device?> getByIdOrNull(int id) async {
    for (final device in _devices) {
      if (device.id == id) return device;
    }
    return null;
  }

  @override
  Future<Device?> findById(int id) => getByIdOrNull(id);

  @override
  Future<int> insert(Device device) async => 1;

  @override
  Future<int> update(Device device) async => 1;

  @override
  Future<int> setActive(int id, bool active) async => 1;

  @override
  Future<int> deleteById(int id) async => 1;
}

class _FakeFuelRepository implements FuelRepository {
  @override
  Future<List<FuelLog>> listAll() async => const [];

  @override
  Future<int> insert(FuelLog log) async => 1;

  @override
  Future<int> update(FuelLog log) async => 1;

  @override
  Future<int> deleteById(int id) async => 1;

  @override
  Future<int> deleteByDeviceId(int deviceId) async => 1;
}

class _FakeMaintenanceRepository implements MaintenanceRepository {
  @override
  Future<List<MaintenanceRecord>> listAll() async => const [];

  @override
  Future<int> insert(MaintenanceRecord record) async => 1;

  @override
  Future<void> update(MaintenanceRecord record) async {}

  @override
  Future<void> deleteById(int id) async {}
}

class _FakeProjectRateRepository implements ProjectRateRepository {
  @override
  Future<List<ProjectDeviceRate>> listAll() async => const [];

  @override
  Future<int> upsert(ProjectDeviceRate rate) async => 1;

  @override
  Future<int> delete(
    String projectKey,
    int deviceId, {
    String? projectId,
    bool isBreaking = false,
  }) async {
    return 1;
  }

  @override
  Future<int> deleteByProjectKey(String projectKey) async => 1;
}

class _FakeProjectRepository implements ProjectRepository {
  final inserted = <Project>[];

  @override
  Future<List<Project>> listAll() async => inserted;

  @override
  Future<Project?> findById(String id) async {
    for (final project in inserted) {
      if (project.id == id) return project;
    }
    return null;
  }

  @override
  Future<List<Project>> findActiveByContactSite({
    required String contact,
    required String site,
  }) async {
    return inserted
        .where((project) {
          return project.contact == contact.trim() &&
              project.site == site.trim() &&
              project.status == ProjectStatus.active;
        })
        .toList(growable: false);
  }

  @override
  Future<void> insert(Project project) async {
    inserted.add(project);
  }

  @override
  Future<Project> findOrCreateLegacyProject({
    required String contact,
    required String site,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> upsert(Project project) async {
    inserted.add(project);
  }
}

AccountProjectMergeGroup _mergeGroup() {
  return const AccountProjectMergeGroup(
    id: 1,
    contact: '甲方',
    createdAt: '2026-05-15T00:00:00.000Z',
  );
}

List<AccountProjectMergeMember> _mergeMembers() {
  return const [
    AccountProjectMergeMember(
      id: 1,
      groupId: 1,
      projectKey: '甲方||一号工地',
      contact: '甲方',
      site: '一号工地',
      sortOrder: 0,
      createdAt: '2026-05-15T00:00:00.000Z',
    ),
    AccountProjectMergeMember(
      id: 2,
      groupId: 1,
      projectKey: '甲方||二号工地',
      contact: '甲方',
      site: '二号工地',
      sortOrder: 1,
      createdAt: '2026-05-15T00:00:00.000Z',
    ),
  ];
}

class _FakeAccountProjectMergeRepository
    implements AccountProjectMergeRepository {
  _FakeAccountProjectMergeRepository({
    this.group,
    List<AccountProjectMergeMember> members = const [],
    this.failDissolveCount = 0,
  }) : members = List.of(members);

  AccountProjectMergeGroup? group;
  List<AccountProjectMergeMember> members;
  int failDissolveCount;
  final List<int> dissolvedGroupIds = [];

  @override
  Future<AccountProjectMergeGroupWithMembers> createGroupWithMembers({
    required AccountProjectMergeGroup group,
    required List<AccountProjectMergeMember> members,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> dissolveGroup({
    required int groupId,
    required String dissolvedAt,
  }) async {
    if (failDissolveCount > 0) {
      failDissolveCount -= 1;
      throw StateError('dissolve failed');
    }
    dissolvedGroupIds.add(groupId);
    group = group?.copyWith(isActive: false, dissolvedAt: dissolvedAt);
    members = [
      for (final member in members)
        if (member.groupId == groupId)
          member.copyWith(isActive: false)
        else
          member,
    ];
  }

  @override
  Future<AccountProjectMergeGroup?> getGroupById(int groupId) async {
    final current = group;
    if (current == null || current.id != groupId) return null;
    return current;
  }

  @override
  Future<List<AccountProjectMergeMember>> listActiveMembers() async {
    return members.where((member) => member.isActive).toList();
  }

  @override
  Future<List<AccountProjectMergeMember>> listActiveMembersByProjectKeys(
    List<String> projectKeys,
  ) async {
    final keySet = projectKeys.map((key) => key.trim()).toSet();
    return members.where((member) {
      return member.isActive && keySet.contains(member.projectKey);
    }).toList();
  }

  @override
  Future<List<AccountProjectMergeMember>> listActiveMembersByProjectIds(
    List<String> projectIds,
  ) async {
    final projectIdSet = projectIds.map((id) => id.trim()).toSet();
    return members.where((member) {
      return member.isActive &&
          projectIdSet.contains(member.effectiveProjectId);
    }).toList();
  }

  @override
  Future<List<AccountProjectMergeGroup>> listActiveGroups() async {
    final current = group;
    if (current == null || !current.isActive) return const [];
    return [current];
  }

  @override
  Future<List<AccountProjectMergeGroupWithMembers>>
  listActiveGroupsWithMembers() async {
    final current = group;
    if (current == null || !current.isActive) return const [];
    return [
      AccountProjectMergeGroupWithMembers(
        group: current,
        members: await listActiveMembers(),
      ),
    ];
  }

  @override
  Future<List<AccountProjectMergeMember>> listMembersByGroupId(
    int groupId,
  ) async {
    return members.where((member) => member.groupId == groupId).toList();
  }
}
