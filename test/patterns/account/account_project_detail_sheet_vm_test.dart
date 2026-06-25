import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/external_import_batch.dart';
import 'package:asset_ledger/data/models/external_work_record.dart';
import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:asset_ledger/data/models/project_key.dart';
import 'package:asset_ledger/data/models/project_write_off.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/features/account/model/account_view_model.dart';
import 'package:asset_ledger/features/timing/state/timing_external_work_store.dart';
import 'package:asset_ledger/patterns/account/account_project_detail_sheet_vm.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const shangyiKey = '李杰||尚义';
  const xiantanKey = '李杰||鲜滩';
  const shangyiProjectId = 'project:shangyi';
  const xiantanProjectId = 'project:xiantan';
  final normalKey = ProjectKey.buildKey(contact: '李杰', site: '尚义');

  final devices = [
    Device(
      id: 1,
      name: 'HITACHI 1#',
      brand: 'HITACHI',
      defaultUnitPrice: 100,
      baseMeterHours: 0,
    ),
    Device(
      id: 2,
      name: 'SANY 1#',
      brand: 'SANY',
      defaultUnitPrice: 180,
      baseMeterHours: 0,
    ),
  ];

  final records = [
    TimingRecord(
      projectId: shangyiProjectId,
      deviceId: 1,
      startDate: 20260501,
      contact: '李杰',
      site: '尚义',
      type: TimingType.hours,
      startMeter: 0,
      endMeter: 64.9,
      hours: 64.9,
      income: 6490,
    ),
    TimingRecord(
      projectId: xiantanProjectId,
      deviceId: 1,
      startDate: 20260502,
      contact: '李杰',
      site: '鲜滩',
      type: TimingType.hours,
      startMeter: 0,
      endMeter: 239,
      hours: 239,
      income: 23900,
    ),
    TimingRecord(
      projectId: xiantanProjectId,
      deviceId: 2,
      startDate: 20260502,
      contact: '李杰',
      site: '鲜滩',
      type: TimingType.hours,
      startMeter: 0,
      endMeter: 20,
      hours: 20,
      income: 3600,
    ),
  ];

  final rates = [
    ProjectDeviceRate(
      projectId: shangyiProjectId,
      projectKey: shangyiKey,
      deviceId: 1,
      rate: 100,
    ),
    ProjectDeviceRate(
      projectId: xiantanProjectId,
      projectKey: xiantanKey,
      deviceId: 1,
      rate: 100,
    ),
    ProjectDeviceRate(
      projectId: xiantanProjectId,
      projectKey: xiantanKey,
      deviceId: 2,
      rate: 180,
    ),
  ];

  AccountProjectDetailSheetVmBuilder builderFor({
    required List<AccountProjectVM> projects,
    List<TimingRecord>? timingRecords,
    List<Device>? allDevices,
    List<ProjectDeviceRate>? allRates,
    List<ProjectWriteOff> writeOffs = const [],
    List<TimingExternalWorkRecordItem> externalWorkItems = const [],
    Set<String>? settledProjectIds,
  }) {
    return AccountProjectDetailSheetVmBuilder(
      computed: AccountComputed(
        projects: projects,
        totalReceivable: 0,
        totalReceived: 0,
        totalRemaining: 0,
        totalRatio: 0,
        deviceReceivables: [],
      ),
      timingRecords: timingRecords ?? records,
      allDevices: allDevices ?? devices,
      allWriteOffs: writeOffs,
      allRates: allRates ?? rates,
      allExternalWorkItems: externalWorkItems,
      settledProjectIds: settledProjectIds,
    );
  }

  AccountProjectVM normalProject({
    String projectId = shangyiProjectId,
    double receivable = 6490,
    double remaining = 6490,
    double writeOff = 0,
    bool linked = false,
  }) {
    return AccountProjectVM(
      projectId: projectId,
      projectKey: normalKey,
      displayName: '李杰 + 尚义',
      hasLinkedExternalWork: linked,
      minYmd: 20260501,
      deviceIds: [1],
      hoursByDevice: const {1: 64.9},
      rentIncomeTotal: 0,
      minRate: 100,
      isMultiDevice: false,
      isMultiMode: false,
      receivable: receivable,
      received: receivable - remaining - writeOff,
      writeOff: writeOff,
      remaining: remaining,
      ratio: 0,
      payments: [],
    );
  }

  AccountProjectVM mergedProject({
    int? mergeGroupId = 1,
    double writeOff = 0,
    double remaining = 5000,
    List<String> memberProjectIds = const [shangyiProjectId, xiantanProjectId],
  }) {
    return AccountProjectVM(
      projectId: 'merge:1',
      projectKey: 'merge:1',
      displayName: '李杰 + 合并2项目',
      kind: AccountProjectKind.merged,
      mergeGroupId: mergeGroupId,
      memberProjectKeys: [shangyiKey, xiantanKey],
      memberProjectIds: memberProjectIds,
      minYmd: 20260501,
      deviceIds: [1, 2],
      hoursByDevice: const {1: 303.9, 2: 20},
      rentIncomeTotal: 0,
      minRate: 100,
      isMultiDevice: true,
      isMultiMode: false,
      receivable: 10000,
      received: 10000 - remaining - writeOff,
      writeOff: writeOff,
      remaining: remaining,
      ratio: 0.5,
      payments: [
        AccountPayment(
          id: 1,
          projectKey: shangyiKey,
          ymd: 20260501,
          amount: 5000,
          note: '现金',
          createdAt: '2026-05-16T01:01:00.000Z',
        ),
        AccountPayment(
          id: 3,
          projectKey: shangyiKey,
          ymd: 20260515,
          amount: 1490,
          sourceType: AccountPayment.sourceTypeMergeAllocation,
          mergeGroupId: 1,
          mergeBatchId: 'batch-1',
          mergeBatchTotalAmount: 5000,
          mergeBatchNote: '微信收款',
          createdAt: '2026-05-16T01:03:00.000Z',
        ),
      ],
    );
  }

  group('build / 命中', () {
    test('returns null when no project matches', () {
      final vm = builderFor(
        projects: [normalProject()],
      ).build(projectKey: '不存在||工地');
      expect(vm, isNull);
    });

    test('prefers stable project id over key when provided', () {
      final builder = builderFor(
        projects: [
          normalProject(projectId: 'project:active', remaining: 1000),
          normalProject(projectId: 'project:settled', remaining: 0),
        ],
      );
      final vm = builder.build(
        projectId: 'project:settled',
        projectKey: normalKey,
      );
      expect(vm, isNotNull);
      expect(vm!.project.effectiveProjectId, 'project:settled');
    });
  });

  group('normal 项目展示派生', () {
    test('derives used devices, hours and rates', () {
      final vm = builderFor(
        projects: [normalProject()],
      ).build(projectKey: normalKey);

      expect(vm, isNotNull);
      expect(vm!.isMerged, isFalse);
      expect(vm.usedDevices.map((d) => d.id), [1]);
      expect(vm.normalHoursByDevice, {1: 64.9});
      expect(vm.breakingHoursByDevice, isEmpty);
      expect(vm.deviceRates, {1: 100});
      expect(vm.mergedDetailRows, isEmpty);
      expect(vm.mergedPaymentDisplayItems, isEmpty);
    });

    test('derives project override rates from rateFen', () {
      final vm = builderFor(
        projects: [normalProject()],
        allRates: [
          ProjectDeviceRate(
            projectId: shangyiProjectId,
            projectKey: shangyiKey,
            deviceId: 1,
            rate: 9999,
            rateFen: 12345,
          ),
        ],
      ).build(projectKey: normalKey);

      expect(vm!.deviceRates, {1: 123.45});
    });
  });

  group('结清判定', () {
    test('uses settledProjectIds when provided', () {
      final vm = builderFor(
        projects: [normalProject(remaining: 6490)],
        settledProjectIds: const {shangyiProjectId},
      ).build(projectKey: normalKey);
      expect(vm!.isProjectSettled, isTrue);
    });

    test('falls back to remaining when settledProjectIds is null', () {
      final settled = builderFor(
        projects: [normalProject(remaining: 0)],
      ).build(projectKey: normalKey);
      expect(settled!.isProjectSettled, isTrue);

      final active = builderFor(
        projects: [normalProject(remaining: 6490)],
      ).build(projectKey: normalKey);
      expect(active!.isProjectSettled, isFalse);
    });
  });

  group('核销筛选与撤销判定', () {
    ProjectWriteOff writeOff(
      String id,
      String projectId, {
      double amount = 60,
    }) {
      return ProjectWriteOff(
        id: id,
        projectId: projectId,
        amount: amount,
        reason: 'settlement',
        writeOffDate: '2026-05-18',
        createdAt: '2026-05-18T00:00:00.000Z',
        updatedAt: '2026-05-18T00:00:00.000Z',
      );
    }

    test('filters write-offs by project identity id', () {
      final vm = builderFor(
        projects: [normalProject(writeOff: 60, remaining: 0)],
        writeOffs: [
          writeOff('w-1', shangyiProjectId),
          writeOff('w-other', 'project:other'),
        ],
      ).build(projectKey: normalKey);

      expect(vm!.writeOffs.map((w) => w.id), ['w-1']);
    });

    test('hasUniqueWriteOffForRevoke requires positive write-off total', () {
      final revokable = builderFor(
        projects: [normalProject(writeOff: 60, remaining: 0)],
        writeOffs: [writeOff('w-1', shangyiProjectId)],
      ).build(projectKey: normalKey);
      expect(revokable!.hasUniqueWriteOffForRevoke, isTrue);

      final noTotal = builderFor(
        projects: [normalProject(writeOff: 0, remaining: 0)],
        writeOffs: [writeOff('w-1', shangyiProjectId)],
      ).build(projectKey: normalKey);
      expect(noTotal!.hasUniqueWriteOffForRevoke, isFalse);
    });

    test('deletableWriteOffTarget: normal returns first write-off', () {
      final vm = builderFor(
        projects: [normalProject(writeOff: 60, remaining: 0)],
        writeOffs: [writeOff('w-1', shangyiProjectId)],
      ).build(projectKey: normalKey);
      expect(vm!.deletableWriteOffTarget?.id, 'w-1');
    });

    test(
      'deletableWriteOffTarget: merged with multiple write-offs is null',
      () {
        final vm = builderFor(
          projects: [mergedProject(writeOff: 200, remaining: 0)],
          writeOffs: [
            writeOff('writeoff-merge-1-0', 'project:shangyi', amount: 80),
            writeOff('writeoff-merge-1-1', 'project:xiantan', amount: 120),
          ],
          settledProjectIds: const {'project:shangyi', 'project:xiantan'},
        ).build(projectId: 'merge:1', projectKey: 'merge:1');

        expect(vm!.deletableWriteOffTarget, isNull);
        // 合并组生成的核销前缀一致 → 可整体撤销。
        expect(vm.hasUniqueWriteOffForRevoke, isTrue);
      },
    );

    test(
      'deletableWriteOffTarget: merged with single write-off returns it',
      () {
        final vm = builderFor(
          projects: [mergedProject(writeOff: 80, remaining: 0)],
          writeOffs: [
            writeOff('writeoff-merge-1-0', 'project:shangyi', amount: 80),
          ],
          settledProjectIds: const {'project:shangyi'},
        ).build(projectId: 'merge:1', projectKey: 'merge:1');

        expect(vm!.deletableWriteOffTarget?.id, 'writeoff-merge-1-0');
      },
    );
  });

  group('merged 明细与收款展示', () {
    test('builds member detail rows in member order', () {
      final vm = builderFor(
        projects: [mergedProject()],
      ).build(projectId: 'merge:1', projectKey: 'merge:1');

      expect(vm!.isMerged, isTrue);
      // 尚义 dev1(64.9) + 鲜滩 dev1(239) + 鲜滩 dev2(20) = 3 行。
      expect(vm.mergedDetailRows.length, 3);
      expect(vm.mergedDetailRows.first.label, '尚义');
      expect(vm.mergedDetailRows.first.deviceLabel, 'HITACHI 1#');
      expect(vm.mergedDetailRows.map((r) => r.hours), [64.9, 239, 20]);
      expect(vm.mergedPaymentDisplayItems, isNotEmpty);
    });
  });

  group('外协设备明细行', () {
    test('matches active records linked to the project', () {
      final vm = builderFor(
        projects: [normalProject(projectId: 'project:linked', linked: true)],
        externalWorkItems: [
          _externalItem(
            recordId: 'r-1',
            batchId: 'batch-1',
            linkedProjectId: 'project:linked',
            site: '尚义',
            sourceDisplayName: '余远',
            brand: 'Hitachi',
          ),
          _externalItem(
            recordId: 'r-other',
            batchId: 'batch-other',
            linkedProjectId: 'project:other',
            site: '别处',
            sourceDisplayName: '王五',
          ),
        ],
      ).build(projectId: 'project:linked', projectKey: normalKey);

      expect(vm!.externalWorkRows.length, 1);
      expect(vm.externalWorkRows.first.importBatchId, 'batch-1');
    });

    test('merged ignores external work linked to synthetic merge id', () {
      final vm = builderFor(
        projects: [mergedProject()],
        externalWorkItems: [
          _externalItem(
            recordId: 'r-synthetic',
            batchId: 'batch-synthetic',
            linkedProjectId: 'merge:1',
            site: '尚义',
            sourceDisplayName: '余远',
          ),
        ],
      ).build(projectId: 'merge:1', projectKey: 'merge:1');

      expect(vm!.externalWorkRows, isEmpty);
    });
  });
}

TimingExternalWorkRecordItem _externalItem({
  required String recordId,
  required String batchId,
  required String linkedProjectId,
  required String site,
  required String sourceDisplayName,
  String brand = 'Hitachi',
  int hoursMilli = 7000,
  int amountFen = 12600,
  int sourceUnitPriceFen = 18000,
  String importedAt = '2026-05-15T08:00:00.000Z',
  ExternalImportBatchStatus batchStatus = ExternalImportBatchStatus.active,
}) {
  final batch = ExternalImportBatch(
    id: batchId,
    sourceShareId: 'share-$batchId',
    sourceDisplayName: sourceDisplayName,
    recordCount: 1,
    totalHoursMilli: hoursMilli,
    totalAmountFen: amountFen,
    siteSummary: site,
    importedAt: importedAt,
    createdAt: importedAt,
    updatedAt: importedAt,
    status: batchStatus,
  );
  final record = ExternalWorkRecord(
    id: recordId,
    importBatchId: batchId,
    sourceShareId: 'share-$batchId',
    sourceRecordUuid: 'src-$recordId',
    sourceInstallationUuid: 'inst-$batchId',
    originFingerprint: 'fp-$batchId',
    collaboratorName: sourceDisplayName,
    contactSnapshot: sourceDisplayName,
    siteSnapshot: site,
    equipmentBrand: brand,
    workDate: 20260501,
    hoursMilli: hoursMilli,
    sourceUnitPriceFen: sourceUnitPriceFen,
    localUnitPriceFen: sourceUnitPriceFen,
    amountFen: amountFen,
    linkedProjectId: linkedProjectId,
    createdAt: importedAt,
    updatedAt: importedAt,
  );
  return TimingExternalWorkRecordItem(record: record, batch: batch);
}
