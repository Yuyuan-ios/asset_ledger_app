import 'package:asset_ledger/data/models/external_import_batch.dart';
import 'package:asset_ledger/data/models/external_work_record.dart';
import 'package:asset_ledger/features/timing/state/timing_external_work_store.dart';
import 'package:asset_ledger/patterns/timing/external_work_records_pattern.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(List<Widget> slivers) => MaterialApp(
  home: Scaffold(body: CustomScrollView(slivers: slivers)),
);

Widget _statefulHost(
  List<TimingExternalWorkRecordItem> items, {
  ValueChanged<TimingExternalWorkRecordItem>? onTapRecord,
}) {
  return MaterialApp(
    home: Scaffold(
      body: _ExternalWorkRecordsStateHost(
        items: items,
        onTapRecord: onTapRecord,
      ),
    ),
  );
}

void main() {
  testWidgets('empty state keeps import entry out of the content area', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        buildTimingExternalWorkRecordSlivers(
          items: const [],
          expandedAggregateKeys: const {},
          onToggleAggregate: (_) {},
        ),
      ),
    );

    expect(find.text('从他人分享的 .jzt 文件导入后，会显示在这里'), findsOneWidget);
    expect(find.text('导入项目外协包'), findsNothing);
    // 主文案使用 .jzt，不暴露 .jztshare 扩展名（regression）
    expect(find.textContaining('.jztshare'), findsNothing);
  });

  testWidgets('groups one import batch into one package row summary', (
    tester,
  ) async {
    final items = [
      _item(
        record: _record(
          id: 'record-1',
          siteSnapshot: '鲜滩',
          equipmentBrand: 'Hitachi',
          workDate: 20260323,
          hoursMilli: 50000,
        ),
      ),
      _item(
        record: _record(
          id: 'record-2',
          sourceRecordUuid: 'source-2',
          siteSnapshot: '尚义',
          equipmentBrand: 'SANY',
          workDate: 20260324,
          hoursMilli: 60000,
        ),
      ),
      _item(
        record: _record(
          id: 'record-3',
          sourceRecordUuid: 'source-3',
          siteSnapshot: '鲜滩',
          equipmentBrand: 'Hitachi',
          workDate: 20260325,
          hoursMilli: 40000,
        ),
      ),
      _item(
        record: _record(
          id: 'record-4',
          sourceRecordUuid: 'source-4',
          siteSnapshot: '尚义',
          equipmentBrand: 'SANY',
          workDate: 20260326,
          hoursMilli: 39000,
        ),
      ),
      _item(
        record: _record(
          id: 'record-5',
          sourceRecordUuid: 'source-5',
          siteSnapshot: '鲜滩',
          equipmentBrand: 'Hitachi',
          workDate: 20260327,
          hoursMilli: 50000,
        ),
      ),
    ];

    await tester.pumpWidget(
      _host(
        buildTimingExternalWorkRecordSlivers(
          items: items,
          expandedAggregateKeys: const {},
          onToggleAggregate: (_) {},
        ),
      ),
    );

    expect(timingExternalWorkTopLevelCount(items), 1);
    expect(find.text('2026年'), findsOneWidget);
    expect(find.text('余远•鲜滩+尚义'), findsOneWidget);
    expect(
      find.textContaining('Hitachi等2台•5条记录', findRichText: true),
      findsOneWidget,
    );
    final subtitle = tester.widget<RichText>(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText() == 'Hitachi等2台•5条记录',
      ),
    );
    final spans = (subtitle.text as TextSpan).children!;
    final deviceNameSpan = spans[0] as TextSpan;
    final deviceCountSpan = spans[1] as TextSpan;
    expect(deviceNameSpan.text, 'Hitachi');
    expect(deviceNameSpan.style?.fontWeight, FontWeight.w700);
    expect(deviceCountSpan.text, '等2台');
    expect(deviceCountSpan.style?.fontWeight, FontWeight.w400);
    expect(find.text('2026.03.23'), findsOneWidget);
    expect(find.text('239.0 h'), findsOneWidget);
    expect(find.textContaining('合并'), findsNothing);
    expect(find.textContaining('-2026.03.27'), findsNothing);
  });

  testWidgets('multi record package shows compact device and count summary', (
    tester,
  ) async {
    final items = [
      for (var i = 0; i < 5; i += 1)
        _item(
          record: _record(
            id: 'record-$i',
            sourceRecordUuid: 'source-$i',
            equipmentBrand: 'Hitachi',
            hoursMilli: i == 0 ? 39000 : 50000,
          ),
        ),
    ];

    await tester.pumpWidget(
      _host(
        buildTimingExternalWorkRecordSlivers(
          items: items,
          expandedAggregateKeys: const {},
          onToggleAggregate: (_) {},
        ),
      ),
    );

    expect(
      find.textContaining('Hitachi•5条记录', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('239.0 h'), findsOneWidget);
  });

  testWidgets('splits same-year packages into source-name cards', (
    tester,
  ) async {
    final zhangPackage = _item(
      batch: _batch(
        id: 'batch-zhang',
        sourceShareId: 'share-zhang',
        sourceDisplayName: '张俊',
        importedAt: '2026-05-21T08:00:00.000Z',
      ),
      record: _record(
        id: 'record-zhang',
        sourceShareId: 'share-zhang',
        sourceRecordUuid: 'source-zhang',
        collaboratorName: '张俊',
        siteSnapshot: '天眉乐',
        workDate: 20260521,
      ),
    );
    final yuPackageA = _item(
      batch: _batch(
        id: 'batch-yu-a',
        sourceShareId: 'share-yu-a',
        sourceDisplayName: '余远',
        importedAt: '2026-05-01T08:00:00.000Z',
      ),
      record: _record(
        id: 'record-yu-a',
        sourceShareId: 'share-yu-a',
        sourceRecordUuid: 'source-yu-a',
        siteSnapshot: '五里山',
        workDate: 20260501,
      ),
    );
    final yuPackageB = _item(
      batch: _batch(
        id: 'batch-yu-b',
        sourceShareId: 'share-yu-b',
        sourceDisplayName: '余远',
        importedAt: '2026-03-23T08:00:00.000Z',
      ),
      record: _record(
        id: 'record-yu-b',
        sourceShareId: 'share-yu-b',
        sourceRecordUuid: 'source-yu-b',
        siteSnapshot: '鲜滩',
        workDate: 20260323,
      ),
    );

    await tester.pumpWidget(
      _host(
        buildTimingExternalWorkRecordSlivers(
          items: [yuPackageA, zhangPackage, yuPackageB],
          expandedAggregateKeys: const {},
          onToggleAggregate: (_) {},
        ),
      ),
    );

    final cards = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_ExternalWorkRecordGroupCard',
    );

    expect(find.text('2026年'), findsOneWidget);
    expect(
      timingExternalWorkTopLevelCount([yuPackageA, zhangPackage, yuPackageB]),
      3,
    );
    expect(cards, findsNWidgets(2));
    expect(
      find.descendant(of: cards.at(0), matching: find.text('张俊•天眉乐')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: cards.at(1), matching: find.textContaining('余远•')),
      findsNWidgets(2),
    );
  });

  testWidgets('single record package omits count and expand arrow', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        buildTimingExternalWorkRecordSlivers(
          items: [_item()],
          expandedAggregateKeys: const {},
          onToggleAggregate: (_) {},
        ),
      ),
    );

    expect(find.text('Hitachi'), findsOneWidget);
    expect(find.textContaining('1条记录'), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
  });

  testWidgets('tapping package count toggles children without opening detail', (
    tester,
  ) async {
    final items = [
      _item(
        record: _record(
          id: 'record-1',
          sourceRecordUuid: 'source-1',
          equipmentModel: null,
          equipmentType: 'excavator',
        ),
      ),
      _item(
        record: _record(
          id: 'record-2',
          sourceRecordUuid: 'source-2',
          workDate: 20260324,
          hoursMilli: 2000,
          equipmentModel: null,
          equipmentType: 'excavator',
        ),
      ),
    ];
    var tapped = false;

    await tester.pumpWidget(
      _statefulHost(items, onTapRecord: (_) => tapped = true),
    );

    expect(find.text('2026.03.24'), findsNothing);
    await tester.tap(find.textContaining('Hitachi•2条记录', findRichText: true));
    await tester.pumpAndSettle();

    expect(tapped, isFalse);
    expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
    expect(find.text('2026.03.24'), findsOneWidget);
    expect(find.text('协'), findsOneWidget);
    expect(find.text('Hitachi'), findsNWidgets(2));
    expect(find.text('Hitachi / excavator'), findsNothing);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
    await tester.pumpAndSettle();
    expect(find.text('2026.03.24'), findsNothing);
  });

  testWidgets('tapping package outside count opens detail target', (
    tester,
  ) async {
    final items = [
      _item(
        record: _record(id: 'record-1', sourceRecordUuid: 'source-1'),
      ),
      _item(
        record: _record(
          id: 'record-2',
          sourceRecordUuid: 'source-2',
          workDate: 20260324,
          hoursMilli: 2000,
        ),
      ),
    ];
    TimingExternalWorkRecordItem? tapped;

    await tester.pumpWidget(
      _statefulHost(items, onTapRecord: (item) => tapped = item),
    );

    await tester.tap(find.text('余远•五里山'));
    await tester.pump();

    expect(tapped?.record.id, 'record-1');
  });

  testWidgets('sorts import packages by imported time descending', (
    tester,
  ) async {
    final oldItem = _item(
      batch: _batch(id: 'batch-old', importedAt: '2026-05-01T08:00:00.000Z'),
      record: _record(
        id: 'record-old',
        importBatchId: 'batch-old',
        sourceShareId: 'share-old',
        sourceRecordUuid: 'source-old',
        siteSnapshot: '旧工地',
      ),
    );
    final newItem = _item(
      batch: _batch(id: 'batch-new', importedAt: '2026-05-03T08:00:00.000Z'),
      record: _record(
        id: 'record-new',
        importBatchId: 'batch-new',
        sourceShareId: 'share-new',
        sourceRecordUuid: 'source-new',
        siteSnapshot: '新工地',
      ),
    );

    await tester.pumpWidget(
      _host(
        buildTimingExternalWorkRecordSlivers(
          items: [oldItem, newItem],
          expandedAggregateKeys: const {},
          onToggleAggregate: (_) {},
        ),
      ),
    );

    expect(
      tester.getTopLeft(find.text('余远•新工地')).dy,
      lessThan(tester.getTopLeft(find.text('余远•旧工地')).dy),
    );
  });

  testWidgets('uses earliest work date year for package grouping', (
    tester,
  ) async {
    final item = _item(
      batch: _batch(importedAt: '2027-01-02T08:00:00.000Z'),
      record: _record(workDate: 20261231),
    );

    await tester.pumpWidget(
      _host(
        buildTimingExternalWorkRecordSlivers(
          items: [item],
          expandedAggregateKeys: const {},
          onToggleAggregate: (_) {},
        ),
      ),
    );

    expect(find.text('2026年'), findsOneWidget);
    expect(find.text('2027年'), findsNothing);
  });

  testWidgets('linked package avatar adds a link badge only when linked', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        buildTimingExternalWorkRecordSlivers(
          items: [_item()],
          expandedAggregateKeys: const {},
          onToggleAggregate: (_) {},
        ),
      ),
    );

    expect(find.text('协'), findsOneWidget);
    expect(
      find.byKey(const Key('external-work-avatar-link-badge')),
      findsNothing,
    );

    await tester.pumpWidget(
      _host(
        buildTimingExternalWorkRecordSlivers(
          items: [_item(record: _record(linkedProjectId: 'project-1'))],
          expandedAggregateKeys: const {},
          onToggleAggregate: (_) {},
        ),
      ),
    );

    expect(find.text('协'), findsOneWidget);
    expect(
      find.byKey(const Key('external-work-avatar-link-badge')),
      findsOneWidget,
    );
  });
}

class _ExternalWorkRecordsStateHost extends StatefulWidget {
  const _ExternalWorkRecordsStateHost({required this.items, this.onTapRecord});

  final List<TimingExternalWorkRecordItem> items;
  final ValueChanged<TimingExternalWorkRecordItem>? onTapRecord;

  @override
  State<_ExternalWorkRecordsStateHost> createState() =>
      _ExternalWorkRecordsStateHostState();
}

class _ExternalWorkRecordsStateHostState
    extends State<_ExternalWorkRecordsStateHost> {
  final Set<String> expanded = {};

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: buildTimingExternalWorkRecordSlivers(
        items: widget.items,
        expandedAggregateKeys: expanded,
        onToggleAggregate: (key) {
          setState(() {
            if (!expanded.add(key)) expanded.remove(key);
          });
        },
        onTapRecord: widget.onTapRecord,
      ),
    );
  }
}

TimingExternalWorkRecordItem _item({
  ExternalImportBatch? batch,
  ExternalWorkRecord? record,
}) {
  final resolvedBatch = batch ?? _batch();
  final resolvedRecord = (record ?? _record()).copyWith(
    importBatchId: resolvedBatch.id,
  );
  return TimingExternalWorkRecordItem(
    record: resolvedRecord,
    batch: resolvedBatch,
  );
}

ExternalImportBatch _batch({
  String id = 'batch-1',
  String sourceShareId = 'share-1',
  String sourceDisplayName = '余远',
  String siteSummary = '合并2项目',
  String importedAt = '2026-03-30T08:00:00.000Z',
}) {
  return ExternalImportBatch(
    id: id,
    sourceShareId: sourceShareId,
    sourceDisplayName: sourceDisplayName,
    recordCount: 1,
    totalHoursMilli: 1000,
    totalAmountFen: 1000,
    siteSummary: siteSummary,
    importedAt: importedAt,
    createdAt: importedAt,
    updatedAt: importedAt,
  );
}

ExternalWorkRecord _record({
  String id = 'record-1',
  String importBatchId = 'batch-1',
  String sourceShareId = 'share-1',
  String sourceRecordUuid = 'source-1',
  String collaboratorName = '余远',
  String siteSnapshot = '五里山',
  String equipmentBrand = 'Hitachi',
  String? equipmentModel = 'ZX200',
  String equipmentType = '挖机',
  int workDate = 20260323,
  int hoursMilli = 1000,
  String? linkedProjectId,
}) {
  return ExternalWorkRecord(
    id: id,
    importBatchId: importBatchId,
    sourceShareId: sourceShareId,
    sourceRecordUuid: sourceRecordUuid,
    sourceInstallationUuid: 'installation-1',
    originFingerprint: 'fingerprint-$id',
    collaboratorName: collaboratorName,
    contactSnapshot: '联系人',
    siteSnapshot: siteSnapshot,
    equipmentBrand: equipmentBrand,
    equipmentModel: equipmentModel,
    equipmentType: equipmentType,
    workDate: workDate,
    hoursMilli: hoursMilli,
    sourceUnitPriceFen: 1000,
    localUnitPriceFen: null,
    amountFen: 1000,
    projectReceivedFen: 0,
    linkedProjectId: linkedProjectId,
    createdAt: '2026-03-30T08:00:00.000Z',
    updatedAt: '2026-03-30T08:00:00.000Z',
  );
}
