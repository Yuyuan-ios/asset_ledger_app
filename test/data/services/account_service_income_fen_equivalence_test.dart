import 'package:asset_ledger/core/money/amount_policy.dart';
import 'package:asset_ledger/data/models/project_id.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/services/account_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// R5.26-B4 等价性：对一致数据（income_fen == round(income*100)）新读路径输出与
/// 旧 `Money.fromYuan(income).fen` 完全一致，证明 B4 不改变现有 account 汇总输出。
void main() {
  const incomes = <double>[
    0.1,
    0.01,
    19.99,
    100.0,
    800.0,
    200.5,
    1234.56,
    0.03,
  ];

  final projectId = ProjectId.legacyFromParts(contact: 'Alice', site: 'Yard A');

  List<TimingRecord> buildRents({required bool withStoredFen}) {
    var id = 0;
    return [
      for (final income in incomes)
        TimingRecord(
          id: ++id,
          deviceId: 1,
          startDate: 20260300 + id,
          contact: 'Alice',
          site: 'Yard A',
          type: TimingType.rent,
          startMeter: 0,
          endMeter: 0,
          hours: 0,
          income: income,
          // 一致数据：存储 income_fen 恰为 round(income*100)。
          incomeFen: withStoredFen ? Money.fromYuan(income).fen : null,
        ),
    ];
  }

  test(
    'rentIncomeFen equals legacy Money.fromYuan sum for consistent data',
    () {
      final expectedLegacyFen = incomes.fold<int>(
        0,
        (sum, income) => sum + Money.fromYuan(income).fen,
      );

      final withStored = AccountService.buildProjects(
        timingRecords: buildRents(withStoredFen: true),
      )[projectId]!.rentIncomeFen;
      final fallback = AccountService.buildProjects(
        timingRecords: buildRents(withStoredFen: false),
      )[projectId]!.rentIncomeFen;

      // 新读路径（存储 fen）== 旧公式；回退路径（无 fen）也 == 旧公式。
      expect(withStored, expectedLegacyFen);
      expect(fallback, expectedLegacyFen);
      expect(withStored, fallback);
    },
  );

  test('fromMap-backfilled income_fen yields the same aggregate', () {
    // 模拟 B3 回填后从 DB 读出的行（income_fen == round(income*100)）。
    final records = [
      for (var i = 0; i < incomes.length; i++)
        TimingRecord.fromMap({
          'id': i + 1,
          'device_id': 1,
          'start_date': 20260301 + i,
          'contact': 'Alice',
          'site': 'Yard A',
          'type': 'rent',
          'start_meter': 0,
          'end_meter': 0,
          'hours': 0,
          'income_fen': Money.fromYuan(incomes[i]).fen,
        }),
    ];
    final expectedLegacyFen = incomes.fold<int>(
      0,
      (sum, income) => sum + Money.fromYuan(income).fen,
    );
    expect(
      AccountService.buildProjects(
        timingRecords: records,
      )[projectId]!.rentIncomeFen,
      expectedLegacyFen,
    );
  });
}
