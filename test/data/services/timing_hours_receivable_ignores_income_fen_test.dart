import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/project_id.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/services/account_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// R5.26-B4：hours 应收仍由 hours × rate 重算，**不**因 income_fen 改变。
///
/// income / income_fen 对 hours 记录只是快照镜像；应收口径不读它。
void main() {
  test('hours receivable stays hours*rate even when income_fen is absurd', () {
    final projects = AccountService.buildProjects(
      timingRecords: [
        TimingRecord(
          id: 1,
          deviceId: 1,
          startDate: 20260301,
          contact: 'Alice',
          site: 'Yard A',
          type: TimingType.hours,
          startMeter: 0,
          endMeter: 8,
          hours: 8,
          // 故意把 income / income_fen 设成与 hours×rate 完全不符的荒谬值。
          income: 99999,
          incomeFen: 99999999,
        ),
      ],
    );

    final projectId = ProjectId.legacyFromParts(
      contact: 'Alice',
      site: 'Yard A',
    );
    final money = AccountService.calcMoneyFen(
      agg: projects[projectId]!,
      devices: [
        Device(
          id: 1,
          name: 'SANY 1#',
          brand: 'SANY',
          defaultUnitPrice: 100,
          baseMeterHours: 0,
        ),
      ],
      rates: [],
      payments: [],
    );

    // 8h × 100 元/h = 800 元 = 80000 分；income_fen 不参与 hours 应收。
    expect(money.receivableFen, 80000);
    // rent 口径未被 hours 记录污染。
    expect(projects[projectId]!.rentIncomeFen, 0);
  });
}
