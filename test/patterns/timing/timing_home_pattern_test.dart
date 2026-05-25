import 'package:asset_ledger/components/layout/pinned_header_delegate.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/external_work_record.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/patterns/timing/timing_home_pattern.dart';
import 'package:asset_ledger/features/timing/state/timing_external_work_store.dart';
import 'package:asset_ledger/tokens/mapper/core_tokens.dart';
import 'package:asset_ledger/tokens/mapper/timing_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'records header shows only the current title at the pinned height',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TimingHomePattern(
            header: const SizedBox(height: 20),
            chart: const SizedBox(height: 80),
            recordsSection: TimingRecordsSection.recent,
            onRecordsSectionChanged: (_) {},
            records: const [],
            externalWorkItems: const [],
            deviceById: const {},
            deviceIndexById: const {},
            onImportExternalWork: () {},
            onLinkExternalWork: () {},
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
      expect(find.text('最近记录(0)'), findsOneWidget);
      expect(
        find.byKey(const Key('timing-recent-device-filter-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('timing-recent-device-filter-label')),
        findsNothing,
      );
      expect(find.text('最近记录'), findsNothing);
      expect(find.text('外协项目'), findsNothing);
      expect(find.text('导入'), findsNothing);
      expect(find.text('关联'), findsNothing);
    },
  );

  testWidgets('recent title counts top-level rows instead of raw records', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TimingHomePattern(
          header: const SizedBox(height: 20),
          chart: const SizedBox(height: 80),
          recordsSection: TimingRecordsSection.recent,
          onRecordsSectionChanged: (_) {},
          records: [
            _timingRecord(
              id: 1,
              deviceId: 1,
              contact: '李洋',
              site: '天眉乐',
              startMeter: 100,
              endMeter: 108,
              hours: 8,
            ),
            _timingRecord(
              id: 2,
              deviceId: 1,
              contact: '李洋',
              site: '天眉乐',
              startMeter: 108,
              endMeter: 116,
              hours: 8,
            ),
            _timingRecord(
              id: 3,
              deviceId: 2,
              contact: '王强',
              site: '五里山',
              startMeter: 200,
              endMeter: 205,
              hours: 5,
            ),
          ],
          externalWorkItems: const [],
          deviceById: const {},
          deviceIndexById: const {1: '1#', 2: '2#'},
          loading: false,
        ),
      ),
    );

    expect(find.text('最近记录(2)'), findsOneWidget);
    expect(find.text('最近记录(3)'), findsNothing);

    await tester.tap(find.text('李洋·天眉乐'));
    await tester.pumpAndSettle();

    expect(find.text('最近记录(2)'), findsOneWidget);
    expect(find.text('最近记录(4)'), findsNothing);
  });

  testWidgets('recent records filter menu filters by device and restores all', (
    tester,
  ) async {
    const hitachi = Device(
      id: 1,
      name: 'HITACHI 1#',
      brand: 'HITACHI',
      defaultUnitPrice: 100,
      baseMeterHours: 2000,
    );
    const sany = Device(
      id: 2,
      name: 'SANY 1#',
      brand: 'SANY',
      defaultUnitPrice: 120,
      baseMeterHours: 2000,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TimingHomePattern(
          header: const SizedBox(height: 20),
          chart: const SizedBox(height: 80),
          recordsSection: TimingRecordsSection.recent,
          onRecordsSectionChanged: (_) {},
          records: [
            _timingRecord(
              id: 1,
              deviceId: 1,
              contact: '张三',
              site: '天眉乐',
              startMeter: 100,
              endMeter: 108,
              hours: 8,
            ),
            _timingRecord(
              id: 2,
              deviceId: 1,
              contact: '李四',
              site: '尚义',
              startMeter: 108,
              endMeter: 116,
              hours: 8,
            ),
            _timingRecord(
              id: 3,
              deviceId: 2,
              contact: '王强',
              site: '五里山',
              startMeter: 200,
              endMeter: 205,
              hours: 5,
            ),
          ],
          externalWorkItems: const [],
          deviceById: const {1: hitachi, 2: sany},
          deviceIndexById: const {1: '1#', 2: '1#'},
          loading: false,
        ),
      ),
    );

    expect(find.text('最近记录(3)'), findsOneWidget);
    expect(
      find.byKey(const Key('timing-recent-device-filter-label')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const Key('timing-recent-device-filter-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('全部设备'), findsOneWidget);
    expect(find.text('HITACHI 1#'), findsOneWidget);
    expect(find.text('SANY 1#'), findsOneWidget);
    expect(find.text('✓'), findsOneWidget);

    await tester.tap(find.text('HITACHI 1#'));
    await tester.pumpAndSettle();

    expect(find.text('最近记录(2)'), findsOneWidget);
    final selectedLabel = tester.widget<Text>(
      find.byKey(const Key('timing-recent-device-filter-label')),
    );
    expect(selectedLabel.data, 'HITACHI 1#');
    expect(find.text('张三·天眉乐'), findsOneWidget);
    expect(find.text('李四·尚义'), findsOneWidget);
    expect(find.text('王强·五里山'), findsNothing);

    await tester.tap(
      find.byKey(const Key('timing-recent-device-filter-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('✓'), findsOneWidget);
    await tester.tap(find.text('全部设备'));
    await tester.pumpAndSettle();

    expect(find.text('最近记录(3)'), findsOneWidget);
    expect(
      find.byKey(const Key('timing-recent-device-filter-label')),
      findsNothing,
    );
    expect(find.text('王强·五里山'), findsOneWidget);
  });

  testWidgets('empty external work header shows import only', (tester) async {
    var importTapped = false;
    var linkTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: TimingHomePattern(
          header: const SizedBox(height: 20),
          chart: const SizedBox(height: 80),
          recordsSection: TimingRecordsSection.externalWork,
          onRecordsSectionChanged: (_) {},
          records: const [],
          externalWorkItems: const [],
          deviceById: const {},
          deviceIndexById: const {},
          onImportExternalWork: () => importTapped = true,
          onLinkExternalWork: () => linkTapped = true,
          loading: false,
        ),
      ),
    );

    expect(find.text('外协项目(0)'), findsOneWidget);
    expect(
      find.byKey(const Key('timing-recent-device-filter-button')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('timing-external-work-header-import')),
      findsOneWidget,
    );
    expect(find.text('导入'), findsOneWidget);
    expect(
      find.byKey(const Key('timing-external-work-header-link')),
      findsNothing,
    );
    expect(find.text('关联'), findsNothing);
    expect(find.text('导入外协项目包'), findsNothing);
    final emptyTitle = tester.widget<Text>(find.text('暂无外协项目记录'));
    final emptySubtitle = tester.widget<Text>(
      find.text('从他人分享的 .jzt 文件导入后，会显示在这里'),
    );
    expect(emptyTitle.style?.fontSize, 16);
    expect(emptySubtitle.style?.fontSize, 15);

    await tester.tap(
      find.byKey(const Key('timing-external-work-header-import')),
    );
    expect(importTapped, isTrue);
    expect(linkTapped, isFalse);
  });

  testWidgets('swiping records sections syncs the title without a capsule', (
    tester,
  ) async {
    var section = TimingRecordsSection.recent;
    var importTapped = false;
    var linkTapped = false;
    final externalItems = List.generate(3, _externalItem);

    Future<void> pump() async {
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return TimingHomePattern(
                header: const SizedBox(height: 20),
                chart: const SizedBox(height: 80),
                recordsSection: section,
                onRecordsSectionChanged: (next) {
                  setState(() => section = next);
                },
                records: const [],
                externalWorkItems: externalItems,
                deviceById: const {},
                deviceIndexById: const {},
                onImportExternalWork: () => importTapped = true,
                onLinkExternalWork: () => linkTapped = true,
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
    expect(find.text('最近记录(0)'), findsOneWidget);
    expect(
      find.byKey(const Key('timing-recent-device-filter-button')),
      findsOneWidget,
    );
    expect(find.text('外协项目(3)'), findsNothing);
    expect(find.text('最近记录'), findsNothing);
    expect(find.text('外协项目'), findsNothing);
    expect(find.text('导入'), findsNothing);
    expect(find.text('关联'), findsNothing);

    await tester.drag(find.byType(TabBarView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(section, TimingRecordsSection.externalWork);
    expect(find.text('外协项目(1)'), findsOneWidget);
    expect(
      find.byKey(const Key('timing-recent-device-filter-button')),
      findsNothing,
    );
    expect(find.text('外协项目(3)'), findsNothing);
    expect(find.text('外协项目(3条)'), findsNothing);
    expect(find.text('最近记录'), findsNothing);
    expect(find.text('外协项目'), findsNothing);
    expect(
      find.byKey(const Key('timing-external-work-header-import')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('timing-external-work-header-link')),
      findsOneWidget,
    );
    expect(find.text('导入'), findsOneWidget);
    expect(find.text('关联'), findsOneWidget);
    expect(find.byIcon(Icons.link), findsOneWidget);
    final importButton = tester.widget<TextButton>(
      find.descendant(
        of: find.byKey(const Key('timing-external-work-header-import')),
        matching: find.byType(TextButton),
      ),
    );
    final importButtonContent = importButton.child! as Row;
    final importText = importButtonContent.children[0] as Text;
    final importIcon = importButtonContent.children[2] as Icon;
    expect(importText.data, '导入');
    expect(importText.style?.color, AppColors.textPrimary);
    expect(importText.style?.fontSize, 15);
    expect(importText.style?.fontWeight, FontWeight.w600);
    expect(importIcon.icon, Icons.file_download_outlined);
    expect(importIcon.color, AppColors.textPrimary);
    expect(importIcon.size, 16);
    expect(importIcon.weight, 700);
    final linkButton = tester.widget<TextButton>(
      find.descendant(
        of: find.byKey(const Key('timing-external-work-header-link')),
        matching: find.byType(TextButton),
      ),
    );
    final linkButtonContent = linkButton.child! as Row;
    final linkText = linkButtonContent.children[0] as Text;
    final linkIcon = linkButtonContent.children[2] as Icon;
    expect(linkText.data, '关联');
    expect(linkText.style?.color, AppColors.textPrimary);
    expect(linkText.style?.fontSize, 15);
    expect(linkText.style?.fontWeight, FontWeight.w600);
    expect(linkIcon.icon, Icons.link);
    expect(linkIcon.color, AppColors.textPrimary);
    expect(linkIcon.size, 16);
    expect(linkIcon.weight, 700);

    await tester.tap(
      find.byKey(const Key('timing-external-work-header-import')),
    );
    await tester.tap(find.byKey(const Key('timing-external-work-header-link')));

    expect(importTapped, isTrue);
    expect(linkTapped, isTrue);
  });
}

TimingRecord _timingRecord({
  required int id,
  required int deviceId,
  required String contact,
  required String site,
  required double startMeter,
  required double endMeter,
  required double hours,
}) {
  return TimingRecord(
    id: id,
    deviceId: deviceId,
    startDate: 20260501,
    contact: contact,
    site: site,
    type: TimingType.hours,
    startMeter: startMeter,
    endMeter: endMeter,
    hours: hours,
    income: hours * 100,
  );
}

TimingExternalWorkRecordItem _externalItem(int index) {
  return TimingExternalWorkRecordItem(
    record: ExternalWorkRecord(
      id: 'r-$index',
      importBatchId: 'b-1',
      sourceShareId: 'share-1',
      sourceRecordUuid: 'src-$index',
      sourceInstallationUuid: 'install-1',
      originFingerprint: 'fp-$index',
      collaboratorName: '李工',
      contactSnapshot: '张三',
      siteSnapshot: '五里山',
      workDate: 20240101 + index,
      hoursMilli: 1000,
      sourceUnitPriceFen: 100,
      localUnitPriceFen: 100,
      amountFen: 100,
      createdAt: '2026-05-23T00:00:00.000Z',
      updatedAt: '2026-05-23T00:00:00.000Z',
    ),
  );
}
