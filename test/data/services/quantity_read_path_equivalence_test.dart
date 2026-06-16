import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/project_id.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/services/account_service.dart';
import 'package:asset_ledger/data/services/timing_monthly_income_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// S2 读路径切换等价性：hours 工作量来源由 REAL hours 改读统一计量权威
/// [TimingRecord.quantityScaled]（= 存储 quantity_scaled ?? round(hours×1000)）。
///
/// 证明三件事：
/// 1. 毫时网格数据（真实录入粒度）逐记录等价——聚合与旧 `Σ hours` 完全一致；
/// 2. 存储 quantity_scaled 是权威——与 hours REAL 漂移时聚合采信 quantity；
/// 3. legacy 行（无存储值）回退派生，行为不变。
void main() {
  final projectId = ProjectId.legacyFromParts(contact: 'Alice', site: 'Yard A');

  TimingRecord hoursRecord({
    required int id,
    required double hours,
    int deviceId = 1,
  }) {
    return TimingRecord(
      id: id,
      deviceId: deviceId,
      startDate: 20260300 + id,
      contact: 'Alice',
      site: 'Yard A',
      type: TimingType.hours,
      startMeter: 0,
      endMeter: hours,
      hours: hours,
      income: 0,
    );
  }

  Map<String, Object?> hoursRow({
    required int id,
    required double hours,
    int? quantityScaled,
    int deviceId = 1,
  }) {
    return {
      'id': id,
      'project_id': projectId,
      'device_id': deviceId,
      'start_date': 20260300 + id,
      'contact': 'Alice',
      'site': 'Yard A',
      'type': 'hours',
      'start_meter': 0.0,
      'end_meter': hours,
      'hours': hours,
      'income_fen': 0,
      'unit': 'HOUR',
      'quantity_scaled': quantityScaled,
    };
  }

  test('grid-aligned hours aggregate exactly as the legacy hours sum', () {
    // 真实录入粒度（0.1h 网格 + 整数小时）的代表值,含纲要边界 239h。
    const gridHours = <double>[0.1, 0.5, 1.5, 7.5, 239.0, 0.3, 12.5];

    final records = [
      for (var i = 0; i < gridHours.length; i++)
        hoursRecord(id: i + 1, hours: gridHours[i]),
    ];
    final agg = AccountService.buildProjects(
      timingRecords: records,
    )[projectId]!;

    final legacySum = gridHours.fold<double>(0.0, (sum, h) => sum + h);
    expect(agg.hoursByDevice[1], legacySum);
    expect(agg.normalHoursByDevice[1], legacySum);
  });

  test('stored quantity_scaled wins over a drifted REAL hours value', () {
    // hours REAL 带亚毫时漂移(模拟历史浮点运算残留),存储 quantity 为权威。
    final records = [
      TimingRecord.fromMap(
        hoursRow(id: 1, hours: 7.4999996, quantityScaled: 7500),
      ),
      TimingRecord.fromMap(
        hoursRow(id: 2, hours: 0.1000004, quantityScaled: 100),
      ),
    ];
    final agg = AccountService.buildProjects(
      timingRecords: records,
    )[projectId]!;

    // 读路径采信 quantity:7.5 + 0.1,而非 REAL 漂移值之和。
    expect(agg.hoursByDevice[1], 7.5 + 0.1);
  });

  test('legacy rows without stored quantity fall back to derived hours', () {
    final row = hoursRow(id: 1, hours: 2.5)..remove('quantity_scaled');
    final agg = AccountService.buildProjects(
      timingRecords: [TimingRecord.fromMap(row)],
    )[projectId]!;

    expect(agg.hoursByDevice[1], 2.5);
  });

  test('hoursFromQuantity getter: stored wins, legacy derives, rent is 0', () {
    // 存储权威。
    expect(
      TimingRecord.fromMap(
        hoursRow(id: 1, hours: 7.4999996, quantityScaled: 7500),
      ).hoursFromQuantity,
      7.5,
    );
    // legacy 行派生(与旧 hours 对齐到毫时网格)。
    expect(hoursRecord(id: 2, hours: 2.5).hoursFromQuantity, 2.5);
    // rent 行计量未定 → 0(与旧 t.hours == 0.0 一致)。
    final rent = TimingRecord(
      id: 3,
      deviceId: 1,
      startDate: 20260303,
      contact: 'Alice',
      site: 'Yard A',
      type: TimingType.rent,
      startMeter: 0,
      endMeter: 0,
      hours: 0,
      income: 800,
    );
    expect(rent.hoursFromQuantity, 0.0);
  });

  test('monthly realtime income reads stored quantity over drifted hours', () {
    final devices = [
      Device(
        id: 1,
        name: 'Device 1',
        brand: 'Brand',
        defaultUnitPrice: 100,
        baseMeterHours: 0,
      ),
    ];
    List<double> compute(TimingRecord record) {
      return TimingMonthlyIncomeService.computeMonthlyIncomeRealtime(
        records: [record],
        devices: devices,
        rates: [],
        targetYear: 2026,
        targetMonth: 12,
        asOfDate: DateTime(2026, 12, 31),
      );
    }

    double total(List<double> monthly) =>
        monthly.fold<double>(0.0, (sum, v) => sum + v);

    // 存储 quantity 权威:漂移的 hours REAL 不影响实时收入。
    final drifted = TimingRecord.fromMap(
      hoursRow(id: 1, hours: 10.0000004, quantityScaled: 10000),
    );
    expect(total(compute(drifted)), closeTo(1000.0, 1e-9));

    // 网格数据:与旧 hours 路径输出一致(10h × 100 元/h)。
    final grid = hoursRecord(id: 2, hours: 10.0);
    expect(total(compute(grid)), closeTo(1000.0, 1e-9));
  });
}
