import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:asset_ledger/data/models/account_project_merge_group.dart';
import 'package:asset_ledger/data/models/account_project_merge_group_with_members.dart';
import 'package:asset_ledger/data/models/account_project_merge_member.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/project_id.dart';
import 'package:asset_ledger/data/models/project_write_off.dart';
import 'package:asset_ledger/data/services/account_service.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/features/account/domain/services/project_finance_calculator.dart';
import 'package:asset_ledger/features/account/model/account_view_model.dart';
import 'package:asset_ledger/features/account/use_cases/compute_account_summary_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

/// R2：财务 fen 收口 —— calcMoneyFen 接入 ProjectFinanceCalculator 与
/// ComputeAccountSummaryUseCase 后的端到端口径锁定。
void main() {
  final oneDevice100 = [
    Device(
      id: 1,
      name: 'SANY 1#',
      brand: 'SANY',
      defaultUnitPrice: 100,
      baseMeterHours: 0,
    ),
  ];

  ProjectMoneyFen receivable1000Fen({
    List<AccountPayment> payments = const [],
  }) {
    const agg = ProjectAgg(
      projectKey: 'Alpha||Site X',
      contact: 'Alpha',
      site: 'Site X',
      minYmd: 20260301,
      deviceIds: [1],
      hoursByDevice: {1: 10},
      normalHoursByDevice: {1: 10},
      breakingHoursByDevice: {},
      rentIncomeTotal: 0,
    );
    return AccountService.calcMoneyFen(
      agg: agg,
      devices: oneDevice100,
      rates: const [],
      payments: payments,
    );
  }

  group('calcMoneyFen feeds ProjectFinanceCalculator.summarizeTotals', () {
    test('received + write-off < receivable -> remaining > 0, not settled', () {
      final money = receivable1000Fen(
        payments: [
          AccountPayment(
            id: 1,
            projectKey: 'Alpha||Site X',
            ymd: 20260310,
            amount: 600,
          ),
        ],
      );
      final summary = ProjectFinanceCalculator.summarizeTotals(
        receivableFen: money.receivableFen,
        receivedFen: money.receivedFen,
        writeOffFen: money.writeOffFen,
        toleranceFen: 1,
      );

      expect(money.receivableFen, 100000);
      expect(money.receivedFen, 60000);
      expect(summary.remainingFen, 40000);
      expect(summary.overPaidFen, 0);
      expect(summary.isSettled, isFalse);
      expect(summary.cashRate, closeTo(0.6, 0.000001));
    });

    test('received + write-off == receivable -> remaining 0, settled', () {
      const agg = ProjectAgg(
        projectKey: 'Alpha||Site X',
        contact: 'Alpha',
        site: 'Site X',
        minYmd: 20260301,
        deviceIds: [1],
        hoursByDevice: {1: 10},
        normalHoursByDevice: {1: 10},
        breakingHoursByDevice: {},
        rentIncomeTotal: 0,
      );
      final money = AccountService.calcMoneyFen(
        agg: agg,
        devices: oneDevice100,
        rates: const [],
        payments: [
          AccountPayment(
            id: 1,
            projectKey: 'Alpha||Site X',
            ymd: 20260310,
            amount: 600,
          ),
        ],
        writeOffs: [_writeOff(projectKey: 'Alpha||Site X', amount: 400)],
      );
      final summary = ProjectFinanceCalculator.summarizeTotals(
        receivableFen: money.receivableFen,
        receivedFen: money.receivedFen,
        writeOffFen: money.writeOffFen,
        toleranceFen: 1,
      );

      expect(summary.remainingFen, 0);
      expect(summary.overPaidFen, 0);
      expect(summary.isSettled, isTrue);
      expect(summary.settlementRate, closeTo(1.0, 0.000001));
    });

    test('received > receivable -> negative remaining, explicit overPaid', () {
      final money = receivable1000Fen(
        payments: [
          AccountPayment(
            id: 1,
            projectKey: 'Alpha||Site X',
            ymd: 20260310,
            amount: 1100,
          ),
        ],
      );
      final summary = ProjectFinanceCalculator.summarizeTotals(
        receivableFen: money.receivableFen,
        receivedFen: money.receivedFen,
        writeOffFen: money.writeOffFen,
        toleranceFen: 1,
      );

      expect(summary.remainingFen, -10000);
      expect(summary.overPaidFen, 10000);
      expect(summary.isSettled, isTrue);
    });
  });

  group('ComputeAccountSummaryUseCase merged fen accumulation', () {
    test('merged total equals exact sum of member fen receivables', () {
      const useCase = ComputeAccountSummaryUseCase();

      final result = useCase.execute(
        timingRecords: const [
          // 成员 A：租金 333.33 元。
          TimingRecord(
            id: 1,
            deviceId: 1,
            startDate: 20260301,
            contact: '李杰',
            site: '尚义',
            type: TimingType.rent,
            startMeter: 0,
            endMeter: 0,
            hours: 0,
            income: 333.33,
          ),
          // 成员 B：租金 666.67 元。
          TimingRecord(
            id: 2,
            deviceId: 1,
            startDate: 20260302,
            contact: '李杰',
            site: '鲜滩',
            type: TimingType.rent,
            startMeter: 0,
            endMeter: 0,
            hours: 0,
            income: 666.67,
          ),
        ],
        devices: oneDevice100,
        rates: const [],
        payments: [
          AccountPayment(
            id: 1,
            projectKey: '李杰||尚义',
            ymd: 20260401,
            amount: 400,
          ),
        ],
        activeMergeGroups: const [
          AccountProjectMergeGroupWithMembers(
            group: AccountProjectMergeGroup(
              id: 1,
              contact: '李杰',
              createdAt: '2026-05-15T00:00:00.000Z',
            ),
            members: [
              AccountProjectMergeMember(
                id: 1,
                groupId: 1,
                projectKey: '李杰||尚义',
                contact: '李杰',
                site: '尚义',
                sortOrder: 0,
                createdAt: '2026-05-15T00:00:00.000Z',
              ),
              AccountProjectMergeMember(
                id: 2,
                groupId: 1,
                projectKey: '李杰||鲜滩',
                contact: '李杰',
                site: '鲜滩',
                sortOrder: 1,
                createdAt: '2026-05-15T00:00:00.000Z',
              ),
            ],
          ),
        ],
      );

      final merged = result.projects.singleWhere(
        (project) => project.kind == AccountProjectKind.merged,
      );

      // 333.33 + 666.67 = 1000.00 元（逐成员 fen 累加，不做二次 rounding）。
      expect(merged.receivable, closeTo(1000.0, 0.000001));
      expect(merged.received, closeTo(400.0, 0.000001));
      expect(merged.remaining, closeTo(600.0, 0.000001));
    });
  });

  group('ComputeAccountSummaryUseCase legacy parity', () {
    test('rent-only project keeps whole-yuan totals unchanged', () {
      const useCase = ComputeAccountSummaryUseCase();

      final result = useCase.execute(
        timingRecords: const [
          TimingRecord(
            id: 1,
            deviceId: 1,
            startDate: 20260301,
            contact: 'Alice',
            site: 'Yard A',
            type: TimingType.rent,
            startMeter: 0,
            endMeter: 0,
            hours: 0,
            income: 22000,
          ),
        ],
        devices: oneDevice100,
        rates: const [],
        payments: [],
      );

      expect(result.totalReceivable, 22000);
      expect(result.projects.single.receivable, 22000);
    });
  });

  group('AccountComputed.moneyFenByProjectId 权威快照直出', () {
    test('按真实 project_id 暴露 calcMoneyFen 结果,与 VM double 一致', () {
      const useCase = ComputeAccountSummaryUseCase();
      final projectId = ProjectId.legacyFromParts(contact: 'Alpha', site: 'X');
      final result = useCase.execute(
        timingRecords: [
          TimingRecord(
            id: 1,
            deviceId: 1,
            projectId: projectId,
            startDate: 20260301,
            contact: 'Alpha',
            site: 'X',
            type: TimingType.hours,
            startMeter: 0,
            endMeter: 10,
            hours: 10,
            income: 0,
          ),
        ],
        devices: oneDevice100,
        rates: const [],
        payments: [
          AccountPayment(
            id: 1,
            projectId: projectId,
            projectKey: 'Alpha||X',
            ymd: 20260310,
            amount: 600,
          ),
        ],
      );

      final fen = result.moneyFenByProjectId[projectId];
      expect(fen, isNotNull, reason: '权威快照必须按真实 project_id 暴露');
      expect(fen!.receivableFen, 100000);
      expect(fen.receivedFen, 60000);
      expect(fen.writeOffFen, 0);

      final vm = result.projects.single;
      expect(
        ProjectFinanceCalculator.yuanToFen(vm.receivable),
        fen.receivableFen,
        reason: 'fen 快照与 double VM 对一致数据相等(直出 vs 派生)',
      );
    });
  });
}

ProjectWriteOff _writeOff({
  required String projectKey,
  required double amount,
}) {
  return ProjectWriteOff(
    id: 'wo-$projectKey',
    projectId: ProjectId.legacyFromKey(projectKey),
    amount: amount,
    reason: ProjectWriteOffReason.rounding.dbValue,
    writeOffDate: '2026-03-10',
    createdAt: '2026-03-10T00:00:00.000Z',
    updatedAt: '2026-03-10T00:00:00.000Z',
  );
}
