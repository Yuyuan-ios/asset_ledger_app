import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/project_id.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/services/account_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// R5.26-B4：timing rent 收入读路径优先 income_fen（缺失回退 income REAL）。
///
/// buildProjects.rentIncomeFen / calcMoneyFen 应读 [TimingRecord.incomeFen]
/// (= 存储 income_fen ?? round(income*100))，而非恒由 income 派生。
void main() {
  TimingRecord rent({required int id, required double income, int? incomeFen}) {
    return TimingRecord(
      id: id,
      deviceId: 1,
      startDate: 20260300 + id,
      contact: 'Alice',
      site: 'Yard A',
      type: TimingType.rent,
      startMeter: 0,
      endMeter: 0,
      hours: 0,
      income: income,
      incomeFen: incomeFen,
    );
  }

  final aliceProjectId = ProjectId.legacyFromParts(
    contact: 'Alice',
    site: 'Yard A',
  );

  group('timing rent income read path prefers income_fen', () {
    test('buildProjects rentIncomeFen uses stored income_fen over income', () {
      // 存储 income_fen 故意与 round(income*100) 不一致：必须以 income_fen 为准。
      final projects = AccountService.buildProjects(
        timingRecords: [rent(id: 1, income: 100.0, incomeFen: 12345)],
      );
      expect(projects[aliceProjectId]!.rentIncomeFen, 12345);
    });

    test('falls back to round(income*100) when income_fen is absent', () {
      final projects = AccountService.buildProjects(
        timingRecords: [
          rent(id: 1, income: 0.1), // -> 10
          rent(id: 2, income: 19.99), // -> 1999
        ],
      );
      expect(projects[aliceProjectId]!.rentIncomeFen, 10 + 1999);
    });

    test('calcMoneyFen receivable reflects preferred rent income_fen', () {
      final projects = AccountService.buildProjects(
        timingRecords: [rent(id: 1, income: 100.0, incomeFen: 12345)],
      );
      final money = AccountService.calcMoneyFen(
        agg: projects[aliceProjectId]!,
        devices: [
          Device(
            id: 1,
            name: 'SANY 1#',
            brand: 'SANY',
            defaultUnitPrice: 100,
            baseMeterHours: 0,
          ),
        ],
        rates: const [],
        payments: const [],
      );
      // 无 hours 应收，仅 rent：以存储 income_fen 12345 为准。
      expect(money.receivableFen, 12345);
    });

    test('mixed stored + legacy rows accumulate per record in fen', () {
      final projects = AccountService.buildProjects(
        timingRecords: [
          rent(id: 1, income: 100.0, incomeFen: 9999), // stored 9999
          rent(id: 2, income: 50.0), // legacy -> 5000
        ],
      );
      expect(projects[aliceProjectId]!.rentIncomeFen, 9999 + 5000);
    });
  });
}
