import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/external_import_batch.dart';
import 'package:asset_ledger/data/models/external_work_record.dart';
import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:asset_ledger/data/models/project_key.dart';
import 'package:asset_ledger/data/models/project_write_off.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/features/account/model/account_project_payment_display_vm.dart';
import 'package:asset_ledger/features/account/model/account_view_model.dart';
import 'package:asset_ledger/features/account/presentation/widgets/project_account_detail/project_account_settlement_pill.dart';
import 'package:asset_ledger/features/timing/state/timing_external_work_store.dart';
import 'package:asset_ledger/patterns/account/account_project_detail_sheet_pattern.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const shangyiKey = '李杰||尚义';
  const xiantanKey = '李杰||鲜滩';

  final devices = [
    const Device(
      id: 1,
      name: 'HITACHI 1#',
      brand: 'HITACHI',
      defaultUnitPrice: 100,
      baseMeterHours: 0,
    ),
    const Device(
      id: 2,
      name: 'SANY 1#',
      brand: 'SANY',
      defaultUnitPrice: 180,
      baseMeterHours: 0,
    ),
  ];

  final records = [
    const TimingRecord(
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
    const TimingRecord(
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
    const TimingRecord(
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

  Widget buildSheet({
    String? projectId,
    required String projectKey,
    required AccountComputed computed,
    required AccountOpenSingleRateEditor onEditDeviceRate,
    AccountDissolveMergeGroup? onDissolveMergeGroup,
    AccountOpenMergedPaymentEditor? onAddMergedPayment,
    AccountOpenMergedPaymentBatchEditor? onEditMergedPaymentBatch,
    AccountOpenMergedPaymentBatchEditor? onDeleteMergedPaymentBatch,
    AccountOpenProjectSettlement? onSettleProject,
    AccountDeleteProjectWriteOff? onDeleteWriteOff,
    AccountRevokeProjectWriteOff? onRevokeProjectWriteOff,
    List<ProjectWriteOff> writeOffs = const [],
    List<TimingExternalWorkRecordItem> externalWorkItems = const [],
    Set<String>? settledProjectIds,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AccountProjectDetailSheet(
            projectId: projectId,
            projectKey: projectKey,
            timingRecords: records,
            allDevices: devices,
            allPayments: const [],
            allWriteOffs: writeOffs,
            allRates: const [
              ProjectDeviceRate(projectKey: shangyiKey, deviceId: 1, rate: 100),
              ProjectDeviceRate(projectKey: xiantanKey, deviceId: 1, rate: 100),
              ProjectDeviceRate(projectKey: xiantanKey, deviceId: 2, rate: 180),
            ],
            allExternalWorkItems: externalWorkItems,
            computed: computed,
            settledProjectIds: settledProjectIds,
            onBatchEditRate: (_, _, _) async {},
            onEditDeviceRate: onEditDeviceRate,
            onAddPayment:
                ({required project, required allPayments, editing}) async {},
            onEditPayment:
                ({required project, required allPayments, editing}) async {},
            onDeletePayment: (_) async {},
            onDeleteWriteOff: onDeleteWriteOff,
            onRevokeProjectWriteOff: onRevokeProjectWriteOff,
            onSettleProject: onSettleProject,
            onDissolveMergeGroup: onDissolveMergeGroup,
            onAddMergedPayment: onAddMergedPayment,
            onEditMergedPaymentBatch: onEditMergedPaymentBatch,
            onDeleteMergedPaymentBatch: onDeleteMergedPaymentBatch,
          ),
        ),
      ),
    );
  }

  AccountProjectVM mergedProject({int? mergeGroupId = 1}) {
    return AccountProjectVM(
      projectId: 'merge:1',
      projectKey: 'merge:1',
      displayName: '李杰 + 合并2项目',
      kind: AccountProjectKind.merged,
      mergeGroupId: mergeGroupId,
      memberProjectKeys: const [shangyiKey, xiantanKey],
      memberProjectIds: const ['project:shangyi', 'project:xiantan'],
      includedSites: const ['尚义', '鲜滩'],
      includedSitesText: '尚义、鲜滩',
      minYmd: 20260501,
      deviceIds: const [1, 2],
      hoursByDevice: const {1: 303.9, 2: 20},
      rentIncomeTotal: 0,
      minRate: 100,
      isMultiDevice: true,
      isMultiMode: false,
      receivable: 10000,
      received: 5000,
      remaining: 5000,
      ratio: 0.5,
      payments: const [
        AccountPayment(
          id: 1,
          projectKey: shangyiKey,
          ymd: 20260501,
          amount: 5000,
          note: '现金',
          createdAt: '2026-05-16T01:01:00.000Z',
        ),
        AccountPayment(
          id: 2,
          projectKey: xiantanKey,
          ymd: 20260502,
          amount: 300,
          createdAt: '2026-05-16T01:02:00.000Z',
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
        AccountPayment(
          id: 4,
          projectKey: xiantanKey,
          ymd: 20260515,
          amount: 3510,
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

  testWidgets(
    'merged detail renders member rows and exposes merge settlement action',
    (tester) async {
      AccountProjectVM? editedProject;
      AccountProjectVM? dissolvedProject;
      AccountProjectVM? settledProject;
      AccountProjectPaymentDisplayVM? editedPaymentBatch;
      AccountProjectPaymentDisplayVM? deletedPaymentBatch;

      await tester.pumpWidget(
        buildSheet(
          projectKey: 'merge:1',
          computed: AccountComputed(
            projects: [mergedProject()],
            totalReceivable: 10000,
            totalReceived: 5000,
            totalRemaining: 5000,
            totalRatio: 0.5,
            deviceReceivables: const [],
          ),
          onEditDeviceRate: (project, _, _, _, _) async {
            editedProject = project;
          },
          onDissolveMergeGroup: (project) async {
            dissolvedProject = project;
          },
          onSettleProject: (project) async {
            settledProject = project;
          },
          onAddMergedPayment: (_) async {},
          onEditMergedPaymentBatch: (project, payment) async {
            editedPaymentBatch = payment;
          },
          onDeleteMergedPaymentBatch: (project, payment) async {
            deletedPaymentBatch = payment;
          },
        ),
      );

      expect(tester.takeException(), isNull);
      // 标题拆分为独立的 Text，方便各自省略。
      expect(find.text('李杰'), findsOneWidget);
      expect(find.text('合并2项目'), findsOneWidget);
      expect(find.text('尚义'), findsWidgets);
      expect(find.text('鲜滩'), findsWidgets);
      // 合并项目下每个地址块都展示 "⚙ 本地设备" 标签。
      expect(find.text('本地设备'), findsNWidgets(2));
      expect(find.text('HITACHI 1#'), findsNWidgets(2));
      expect(find.text('SANY 1#'), findsOneWidget);
      expect(find.text('64.9 h'), findsOneWidget);
      expect(find.text('239 h'), findsOneWidget);
      expect(find.text('20 h'), findsOneWidget);
      expect(find.text('已收 50.0%'), findsOneWidget);
      expect(find.text('待收 ¥5000'), findsOneWidget);
      expect(find.text('项目总额 ¥10000'), findsOneWidget);
      expect(find.text('结清'), findsOneWidget);
      expect(
        find.widgetWithText(ProjectAccountSettlementPill, '结清'),
        findsNothing,
      );
      expect(find.text('2026.05.15'), findsOneWidget);
      expect(find.text('合并分摊'), findsOneWidget);
      expect(find.text('备注：微信收款'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('合并分摊')).dy,
        lessThan(tester.getTopLeft(find.text('备注：微信收款')).dy),
      );
      expect(find.text('2026.05.02'), findsOneWidget);
      expect(find.text('¥300'), findsOneWidget);
      expect(find.text('2026.05.01'), findsOneWidget);
      expect(find.text('备注：现金'), findsOneWidget);
      expect(find.text('+ 新增收款'), findsOneWidget);
      expect(_containerWithColor(const Color(0xFFEAF7F5)), findsOneWidget);
      expect(find.text('批量修改'), findsNothing);
      expect(find.text('解除合并'), findsOneWidget);
      expect(_containerWithColor(const Color(0xFFF5F2EE)), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pump();

      expect(
        editedPaymentBatch?.type,
        AccountProjectPaymentDisplayType.mergeBatchPayment,
      );
      expect(editedPaymentBatch?.mergeBatchId, 'batch-1');

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();

      expect(
        deletedPaymentBatch?.type,
        AccountProjectPaymentDisplayType.mergeBatchPayment,
      );
      expect(deletedPaymentBatch?.mergeBatchId, 'batch-1');

      await tester.tap(find.text('修改').first);
      await tester.pump();

      expect(editedProject?.projectKey, shangyiKey);
      expect(editedProject?.projectKey, isNot('merge:1'));

      await tester.tap(find.text('解除合并'));
      await tester.pump();

      expect(dissolvedProject?.mergeGroupId, 1);

      await tester.tap(find.text('结清'));
      await tester.pump();

      expect(settledProject?.effectiveProjectId, 'merge:1');
    },
  );

  testWidgets(
    'merged detail hides dissolve action when mergeGroupId is missing',
    (tester) async {
      await tester.pumpWidget(
        buildSheet(
          projectKey: 'merge:1',
          computed: AccountComputed(
            projects: [mergedProject(mergeGroupId: null)],
            totalReceivable: 10000,
            totalReceived: 5000,
            totalRemaining: 5000,
            totalRatio: 0.5,
            deviceReceivables: const [],
          ),
          onEditDeviceRate: (_, _, _, _, _) async {},
          onDissolveMergeGroup: (_) async {},
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('解除合并'), findsNothing);
    },
  );

  testWidgets('normal detail keeps existing actions and edit project scope', (
    tester,
  ) async {
    AccountProjectVM? editedProject;
    AccountProjectVM? settledProject;
    final normalKey = ProjectKey.buildKey(contact: '李杰', site: '尚义');

    await tester.pumpWidget(
      buildSheet(
        projectKey: normalKey,
        computed: AccountComputed(
          projects: [
            AccountProjectVM(
              projectKey: normalKey,
              displayName: '李杰 + 尚义',
              minYmd: 20260501,
              deviceIds: const [1],
              hoursByDevice: const {1: 64.9},
              rentIncomeTotal: 0,
              minRate: 100,
              isMultiDevice: false,
              isMultiMode: false,
              receivable: 6490,
              received: 0,
              remaining: 6490,
              ratio: 0,
              payments: const [
                AccountPayment(
                  id: 9,
                  projectKey: shangyiKey,
                  ymd: 20260503,
                  amount: 1000,
                  note: '普通收款',
                ),
              ],
            ),
          ],
          totalReceivable: 6490,
          totalReceived: 0,
          totalRemaining: 6490,
          totalRatio: 0,
          deviceReceivables: const [],
        ),
        onEditDeviceRate: (project, _, _, _, _) async {
          editedProject = project;
        },
        onSettleProject: (project) async {
          settledProject = project;
        },
      ),
    );

    // 标题拆分为独立的 Text 元素，方便各自省略。
    expect(find.text('李杰'), findsOneWidget);
    // 普通项目标题已展示地址，"⚙ 本地设备" 区块不再重复地址。
    expect(find.text('尚义'), findsOneWidget);
    expect(find.text('设备'), findsNothing);
    expect(find.text('本地设备'), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.byIcon(Icons.location_on_outlined), findsNothing);
    expect(find.text('批量修改'), findsOneWidget);
    expect(find.text('+ 新增收款'), findsOneWidget);
    expect(find.text('结清'), findsOneWidget);
    expect(
      find.widgetWithText(ProjectAccountSettlementPill, '结清'),
      findsNothing,
    );
    expect(find.text('2026.05.03'), findsOneWidget);
    expect(find.text('¥1000'), findsOneWidget);
    expect(find.text('备注：普通收款'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    await tester.tap(find.text('修改').first);
    await tester.pump();

    expect(editedProject?.projectKey, normalKey);

    await tester.tap(find.text('结清'));
    await tester.pump();

    expect(settledProject?.projectKey, normalKey);
  });

  testWidgets('detail title uses linked external work icon without copy', (
    tester,
  ) async {
    final normalKey = ProjectKey.buildKey(contact: '李洋', site: '天眉乐');

    await tester.pumpWidget(
      buildSheet(
        projectKey: normalKey,
        computed: AccountComputed(
          projects: [
            AccountProjectVM(
              projectId: 'project:linked',
              projectKey: normalKey,
              displayName: '李洋•天眉乐 + 关联',
              hasLinkedExternalWork: true,
              minYmd: 20260521,
              deviceIds: const [1],
              hoursByDevice: const {1: 8.1},
              rentIncomeTotal: 0,
              minRate: 180,
              isMultiDevice: false,
              isMultiMode: false,
              receivable: 1458,
              received: 0,
              remaining: 1458,
              ratio: 0,
              payments: const [],
            ),
          ],
          totalReceivable: 1458,
          totalReceived: 0,
          totalRemaining: 1458,
          totalRatio: 0,
          deviceReceivables: const [],
        ),
        onEditDeviceRate: (_, _, _, _, _) async {},
        onSettleProject: (_) async {},
      ),
    );

    // 标题拆分为独立的 Text，验证两部分都被渲染。
    expect(find.text('李洋'), findsOneWidget);
    expect(find.text('天眉乐'), findsOneWidget);
    expect(find.textContaining('+ 关联'), findsNothing);
    expect(find.byTooltip('已关联外协记录'), findsOneWidget);

    final siteRect = tester.getRect(find.text('天眉乐'));
    final badgeRect = tester.getRect(
      find.byKey(const Key('account-project-detail-linked-external-work')),
    );
    final batchEditRect = tester.getRect(find.text('批量修改'));

    expect(badgeRect.left, greaterThan(siteRect.right));
    expect(badgeRect.left - siteRect.right, lessThan(16));
    expect(badgeRect.right, lessThan(batchEditRect.left));
  });

  testWidgets('settled detail shows project total and revoke action', (
    tester,
  ) async {
    final normalKey = ProjectKey.buildKey(contact: '甲方', site: '一号工地');
    ProjectWriteOff? deletedWriteOff;

    await tester.pumpWidget(
      buildSheet(
        projectKey: normalKey,
        computed: AccountComputed(
          projects: [
            AccountProjectVM(
              projectId: 'project:1',
              projectKey: normalKey,
              displayName: '甲方 + 一号工地',
              minYmd: 20260501,
              deviceIds: const [1],
              hoursByDevice: const {1: 12.6},
              rentIncomeTotal: 0,
              minRate: 100,
              isMultiDevice: false,
              isMultiMode: false,
              receivable: 1260,
              received: 1200,
              writeOff: 60,
              remaining: 0,
              ratio: 1200 / 1260,
              settlementRatio: 1,
              payments: const [],
            ),
          ],
          totalReceivable: 1260,
          totalReceived: 1200,
          totalWriteOff: 60,
          totalRemaining: 0,
          totalRatio: 1200 / 1260,
          settlementRate: 1,
          deviceReceivables: const [],
        ),
        writeOffs: const [
          ProjectWriteOff(
            id: 'write-off-1',
            projectId: 'project:1',
            amount: 60,
            reason: 'rounding',
            note: '尾款抹零',
            writeOffDate: '2026-05-18',
            createdAt: '2026-05-18T00:00:00.000Z',
            updatedAt: '2026-05-18T00:00:00.000Z',
          ),
        ],
        settledProjectIds: const {'project:1'},
        onEditDeviceRate: (_, _, _, _, _) async {},
        onSettleProject: (_) async {},
        onDeleteWriteOff: (writeOff) async {
          deletedWriteOff = writeOff;
        },
      ),
    );

    expect(find.text('项目总额 ¥1260'), findsOneWidget);
    expect(find.text('已结清'), findsOneWidget);
    expect(find.text('已结清，点此撤销'), findsOneWidget);
    expect(find.text('已收 95.2%'), findsNothing);
    expect(find.text('待收 ¥0'), findsNothing);
    expect(find.text('已核销 ¥60'), findsNothing);
    expect(find.text('核销记录'), findsNothing);
    expect(find.text('抹零'), findsNothing);
    expect(find.text('备注：尾款抹零'), findsNothing);
    expect(find.byTooltip('删除核销记录'), findsNothing);

    await tester.tap(find.text('已结清，点此撤销'));
    await tester.pump();

    expect(deletedWriteOff?.id, 'write-off-1');
  });

  testWidgets('detail matches write-off by stable project id', (tester) async {
    const sharedKey = '甲方||一号工地';
    ProjectWriteOff? deletedWriteOff;

    await tester.pumpWidget(
      buildSheet(
        projectId: 'project:settled',
        projectKey: sharedKey,
        computed: AccountComputed(
          projects: const [
            AccountProjectVM(
              projectId: 'project:active',
              projectKey: sharedKey,
              displayName: '甲方 + 一号工地',
              minYmd: 20260502,
              deviceIds: [1],
              hoursByDevice: {1: 10},
              rentIncomeTotal: 0,
              minRate: 100,
              isMultiDevice: false,
              isMultiMode: false,
              receivable: 1000,
              received: 0,
              remaining: 1000,
              ratio: 0,
              payments: [],
            ),
            AccountProjectVM(
              projectId: 'project:settled',
              projectKey: sharedKey,
              displayName: '甲方 + 一号工地',
              minYmd: 20260501,
              deviceIds: [1],
              hoursByDevice: {1: 12.6},
              rentIncomeTotal: 0,
              minRate: 100,
              isMultiDevice: false,
              isMultiMode: false,
              receivable: 1260,
              received: 1200,
              writeOff: 60,
              remaining: 0,
              ratio: 1200 / 1260,
              settlementRatio: 1,
              payments: [],
            ),
          ],
          totalReceivable: 2260,
          totalReceived: 1200,
          totalWriteOff: 60,
          totalRemaining: 1000,
          totalRatio: 1200 / 2260,
          settlementRate: 1260 / 2260,
          deviceReceivables: const [],
        ),
        writeOffs: const [
          ProjectWriteOff(
            id: 'write-off-settled',
            projectId: 'project:settled',
            amount: 60,
            reason: 'settlement',
            writeOffDate: '2026-05-18',
            createdAt: '2026-05-18T00:00:00.000Z',
            updatedAt: '2026-05-18T00:00:00.000Z',
          ),
        ],
        settledProjectIds: const {'project:settled'},
        onEditDeviceRate: (_, _, _, _, _) async {},
        onSettleProject: (_) async {},
        onDeleteWriteOff: (writeOff) async {
          deletedWriteOff = writeOff;
        },
      ),
    );

    expect(find.text('项目总额 ¥1260'), findsOneWidget);
    expect(find.text('已结清，点此撤销'), findsOneWidget);

    await tester.tap(find.text('已结清，点此撤销'));
    await tester.pump();

    expect(deletedWriteOff?.id, 'write-off-settled');
  });

  testWidgets(
    'settled detail can revoke by project callback from write-off total',
    (tester) async {
      final normalKey = ProjectKey.buildKey(contact: '甲方', site: '一号工地');
      AccountProjectVM? revokedProject;

      await tester.pumpWidget(
        buildSheet(
          projectKey: normalKey,
          computed: AccountComputed(
            projects: [
              AccountProjectVM(
                projectId: 'project:1',
                projectKey: normalKey,
                displayName: '甲方 + 一号工地',
                minYmd: 20260501,
                deviceIds: const [1],
                hoursByDevice: const {1: 12.6},
                rentIncomeTotal: 0,
                minRate: 100,
                isMultiDevice: false,
                isMultiMode: false,
                receivable: 1260,
                received: 1200,
                writeOff: 60,
                remaining: 0,
                ratio: 1200 / 1260,
                settlementRatio: 1,
                payments: const [],
              ),
            ],
            totalReceivable: 1260,
            totalReceived: 1200,
            totalWriteOff: 60,
            totalRemaining: 0,
            totalRatio: 1200 / 1260,
            settlementRate: 1,
            deviceReceivables: const [],
          ),
          writeOffs: const [
            ProjectWriteOff(
              id: 'write-off-1',
              projectId: 'project:1',
              amount: 60,
              reason: 'settlement',
              writeOffDate: '2026-05-18',
              createdAt: '2026-05-18T00:00:00.000Z',
              updatedAt: '2026-05-18T00:00:00.000Z',
            ),
          ],
          settledProjectIds: const {'project:1'},
          onEditDeviceRate: (_, _, _, _, _) async {},
          onSettleProject: (_) async {},
          onRevokeProjectWriteOff: (project) async {
            revokedProject = project;
          },
        ),
      );

      expect(find.text('已结清，点此撤销'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);

      await tester.tap(find.text('已结清，点此撤销'));
      await tester.pump();

      expect(find.byType(AlertDialog), findsNothing);
      expect(revokedProject?.effectiveProjectId, 'project:1');
    },
  );

  testWidgets(
    'settled merged detail can revoke merge-generated member write-offs',
    (tester) async {
      AccountProjectVM? revokedProject;

      await tester.pumpWidget(
        buildSheet(
          projectId: 'merge:1',
          projectKey: 'merge:1',
          computed: AccountComputed(
            projects: [
              mergedProject().copyWith(
                receivable: 10000,
                received: 9800,
                writeOff: 200,
                remaining: 0,
                ratio: 0.98,
                settlementRatio: 1,
              ),
            ],
            totalReceivable: 10000,
            totalReceived: 9800,
            totalWriteOff: 200,
            totalRemaining: 0,
            totalRatio: 0.98,
            settlementRate: 1,
            deviceReceivables: const [],
          ),
          writeOffs: const [
            ProjectWriteOff(
              id: 'writeoff-merge-1-0',
              projectId: 'project:shangyi',
              amount: 80,
              reason: 'settlement',
              writeOffDate: '2026-05-18',
              createdAt: '2026-05-18T00:00:00.000Z',
              updatedAt: '2026-05-18T00:00:00.000Z',
            ),
            ProjectWriteOff(
              id: 'writeoff-merge-1-1',
              projectId: 'project:xiantan',
              amount: 120,
              reason: 'settlement',
              writeOffDate: '2026-05-18',
              createdAt: '2026-05-18T00:00:00.000Z',
              updatedAt: '2026-05-18T00:00:00.000Z',
            ),
          ],
          settledProjectIds: const {'project:shangyi', 'project:xiantan'},
          onEditDeviceRate: (_, _, _, _, _) async {},
          onSettleProject: (_) async {},
          onRevokeProjectWriteOff: (project) async {
            revokedProject = project;
          },
        ),
      );

      expect(find.text('已结清，点此撤销'), findsOneWidget);

      await tester.tap(find.text('已结清，点此撤销'));
      await tester.pump();

      expect(revokedProject?.effectiveProjectId, 'merge:1');
    },
  );

  testWidgets(
    'settled detail without write-off shows total without cash claim',
    (tester) async {
      final normalKey = ProjectKey.buildKey(contact: '甲方', site: '一号工地');

      await tester.pumpWidget(
        buildSheet(
          projectKey: normalKey,
          computed: AccountComputed(
            projects: [
              AccountProjectVM(
                projectId: 'project:1',
                projectKey: normalKey,
                displayName: '甲方 + 一号工地',
                minYmd: 20260501,
                deviceIds: const [1],
                hoursByDevice: const {1: 12.6},
                rentIncomeTotal: 0,
                minRate: 100,
                isMultiDevice: false,
                isMultiMode: false,
                receivable: 1260,
                received: 1260,
                writeOff: 0,
                remaining: 0,
                ratio: 1,
                settlementRatio: 1,
                payments: const [],
              ),
            ],
            totalReceivable: 1260,
            totalReceived: 1260,
            totalRemaining: 0,
            totalRatio: 1,
            settlementRate: 1,
            deviceReceivables: const [],
          ),
          settledProjectIds: const {'project:1'},
          onEditDeviceRate: (_, _, _, _, _) async {},
          onSettleProject: (_) async {},
          onRevokeProjectWriteOff: (_) async {},
        ),
      );

      expect(find.text('项目总额 ¥1260'), findsOneWidget);
      expect(find.text('已结清'), findsWidgets);
      expect(find.text('实收 100.0%'), findsNothing);
      expect(find.text('待收 ¥0'), findsNothing);
      expect(find.text('撤销'), findsNothing);
      expect(find.text('已结清，点此撤销'), findsNothing);
    },
  );

  testWidgets('active fully paid detail does not show settled revoke action', (
    tester,
  ) async {
    final normalKey = ProjectKey.buildKey(contact: '甲方', site: '一号工地');

    await tester.pumpWidget(
      buildSheet(
        projectKey: normalKey,
        computed: AccountComputed(
          projects: [
            AccountProjectVM(
              projectId: 'project:1',
              projectKey: normalKey,
              displayName: '甲方 + 一号工地',
              minYmd: 20260501,
              deviceIds: const [1],
              hoursByDevice: const {1: 12.6},
              rentIncomeTotal: 0,
              minRate: 100,
              isMultiDevice: false,
              isMultiMode: false,
              receivable: 1260,
              received: 1260,
              writeOff: 0,
              remaining: 0,
              ratio: 1,
              settlementRatio: 1,
              payments: const [],
            ),
          ],
          totalReceivable: 1260,
          totalReceived: 1260,
          totalRemaining: 0,
          totalRatio: 1,
          settlementRate: 1,
          deviceReceivables: const [],
        ),
        settledProjectIds: const {},
        onEditDeviceRate: (_, _, _, _, _) async {},
        onSettleProject: (_) async {},
        onRevokeProjectWriteOff: (_) async {},
      ),
    );

    expect(find.text('已结清，点此撤销'), findsNothing);
    expect(find.text('项目总额 ¥1260'), findsOneWidget);
    expect(find.text('已结清'), findsWidgets);
    expect(find.text('已收 100.0%'), findsNothing);
  });

  testWidgets(
    'normal project with linked external work shows local and external sections',
    (tester) async {
      const linkedProjectId = 'project:linked-normal';
      final normalKey = ProjectKey.buildKey(contact: '李洋', site: '天眉乐');

      await tester.pumpWidget(
        buildSheet(
          projectId: linkedProjectId,
          projectKey: normalKey,
          computed: AccountComputed(
            projects: [
              AccountProjectVM(
                projectId: linkedProjectId,
                projectKey: normalKey,
                displayName: '李洋 · 天眉乐',
                hasLinkedExternalWork: true,
                minYmd: 20260501,
                deviceIds: const [1],
                hoursByDevice: const {1: 8.1},
                rentIncomeTotal: 0,
                minRate: 180,
                isMultiDevice: false,
                isMultiMode: false,
                receivable: 2718,
                received: 0,
                remaining: 2718,
                ratio: 0,
                payments: const [],
              ),
            ],
            totalReceivable: 2718,
            totalReceived: 0,
            totalRemaining: 2718,
            totalRatio: 0,
            deviceReceivables: const [],
          ),
          onEditDeviceRate: (_, _, _, _, _) async {},
          externalWorkItems: [
            _externalItem(
              recordId: 'r-1',
              batchId: 'batch-1',
              linkedProjectId: linkedProjectId,
              site: '天眉乐',
              sourceDisplayName: '余远',
              brand: 'Hitachi',
              hoursMilli: 7000,
            ),
          ],
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('本地设备'), findsOneWidget);
      expect(find.text('外协设备'), findsOneWidget);
      // header: ⚙ 外协设备 + "余远 · 天眉乐" (拆分为 name / separator / site)
      expect(find.text('余远'), findsOneWidget);
      expect(find.text('天眉乐'), findsWidgets);
      // 外协设备行：Hitachi·1条记录   7 h
      expect(find.text('Hitachi·1条记录'), findsOneWidget);
      expect(find.text('7 h'), findsOneWidget);
      // 外协设备 section 不渲染"修改"按钮（只有本地设备那一行才有）。
      expect(find.text('修改'), findsOneWidget);
    },
  );

  testWidgets(
    'merged project shows one external section per linked member batch',
    (tester) async {
      final merged = mergedProject();
      await tester.pumpWidget(
        buildSheet(
          projectKey: 'merge:1',
          computed: AccountComputed(
            projects: [merged],
            totalReceivable: 10000,
            totalReceived: 5000,
            totalRemaining: 5000,
            totalRatio: 0.5,
            deviceReceivables: const [],
          ),
          onEditDeviceRate: (_, _, _, _, _) async {},
          onDissolveMergeGroup: (_) async {},
          onAddMergedPayment: (_) async {},
          externalWorkItems: [
            _externalItem(
              recordId: 'r-shangyi',
              batchId: 'batch-shangyi',
              linkedProjectId: 'project:shangyi',
              site: '尚义',
              sourceDisplayName: '余远',
              brand: 'Hitachi',
              importedAt: '2026-05-15T08:00:00.000Z',
            ),
            _externalItem(
              recordId: 'r-xiantan',
              batchId: 'batch-xiantan',
              linkedProjectId: 'project:xiantan',
              site: '鲜滩',
              sourceDisplayName: '余远',
              brand: 'Hitachi',
              importedAt: '2026-05-16T08:00:00.000Z',
            ),
            _externalItem(
              recordId: 'r-unrelated',
              batchId: 'batch-other',
              linkedProjectId: 'project:other',
              site: '其他',
              sourceDisplayName: '王五',
              brand: 'Sany',
            ),
          ],
        ),
      );

      expect(tester.takeException(), isNull);
      // 两个本地地址块 + 两个外协包，共 4 次 "本地设备" / 2 次 "外协设备"。
      expect(find.text('本地设备'), findsNWidgets(2));
      expect(find.text('外协设备'), findsNWidgets(2));
      // 两个 batch 的设备摘要各一条。
      expect(find.text('Hitachi·1条记录'), findsNWidgets(2));
      // 未关联的 batch 不会出现在外协 section 中。
      expect(find.text('Sany·1条记录'), findsNothing);
    },
  );

  testWidgets(
    'project without linked external work hides 外协设备 section',
    (tester) async {
      final normalKey = ProjectKey.buildKey(contact: '李杰', site: '尚义');
      await tester.pumpWidget(
        buildSheet(
          projectKey: normalKey,
          computed: AccountComputed(
            projects: [
              AccountProjectVM(
                projectKey: normalKey,
                displayName: '李杰 · 尚义',
                minYmd: 20260501,
                deviceIds: const [1],
                hoursByDevice: const {1: 64.9},
                rentIncomeTotal: 0,
                minRate: 100,
                isMultiDevice: false,
                isMultiMode: false,
                receivable: 6490,
                received: 0,
                remaining: 6490,
                ratio: 0,
                payments: const [],
              ),
            ],
            totalReceivable: 6490,
            totalReceived: 0,
            totalRemaining: 6490,
            totalRatio: 0,
            deviceReceivables: const [],
          ),
          onEditDeviceRate: (_, _, _, _, _) async {},
          // 提供一条已关联到别的项目的外协记录，确认它不会被错误地展示。
          externalWorkItems: [
            _externalItem(
              recordId: 'r-other',
              batchId: 'batch-other',
              linkedProjectId: 'project:other',
              site: '其他工地',
              sourceDisplayName: '王五',
            ),
          ],
        ),
      );

      expect(find.text('本地设备'), findsOneWidget);
      expect(find.text('外协设备'), findsNothing);
    },
  );
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

Finder _containerWithColor(Color color) {
  return find.byWidgetPredicate((widget) {
    final decoration = widget is Container ? widget.decoration : null;
    return decoration is BoxDecoration && decoration.color == color;
  });
}
