import 'package:asset_ledger/core/money/amount_policy.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:asset_ledger/data/models/project_id.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/services/account_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// S1 收口切片 1-4 等价性：账户单价读路径由 REAL double 切到 v35 fen 权威
/// （buildEffectiveRateFenMap），calcMoneyFen 直接消费整数分单价。
///
/// 证明三件事：
/// 1. 一致数据（fen == round(REAL×100)）下新读路径与旧
///    `UnitPrice.fromYuanPerHour(rate)` 公式逐点完全相等；
/// 2. 存储 fen 是权威——REAL 被脏数据污染时应收仍按 fen 计算；
/// 3. double 口径 buildEffectiveRateMap 恒等于 fen÷100（显示派生）。
void main() {
  final projectId = ProjectId.legacyFromParts(contact: 'Alice', site: 'Yard A');

  TimingRecord hoursRecord({
    required int id,
    required double hours,
    int deviceId = 1,
    bool isBreaking = false,
  }) {
    return TimingRecord(
      id: id,
      deviceId: deviceId,
      startDate: 20260600 + id,
      contact: 'Alice',
      site: 'Yard A',
      type: TimingType.hours,
      startMeter: 0,
      endMeter: hours,
      hours: hours,
      income: 0,
      isBreaking: isBreaking,
    );
  }

  Device device({
    required int id,
    required double defaultPrice,
    double? breakingPrice,
  }) {
    return Device(
      id: id,
      name: 'Device $id',
      brand: 'sany',
      defaultUnitPrice: defaultPrice,
      breakingUnitPrice: breakingPrice,
      baseMeterHours: 0,
    );
  }

  test(
    'consistent data: fen rate path equals the legacy yuan-rate formula',
    () {
      const hoursValues = <double>[0.1, 0.5, 7.5, 239.0, 12.5];
      const rate = 380.55;

      final records = [
        for (var i = 0; i < hoursValues.length; i++)
          hoursRecord(id: i + 1, hours: hoursValues[i]),
      ];
      final agg = AccountService.buildProjects(
        timingRecords: records,
      )[projectId]!;

      final money = AccountService.calcMoneyFen(
        agg: agg,
        devices: [device(id: 1, defaultPrice: rate)],
        rates: [],
        payments: [],
      );

      // 旧公式:逐设备 hours 聚合 × UnitPrice.fromYuanPerHour(rate)。
      final legacyFen = AmountPolicy.calculateAmount(
        hours: WorkHours.fromHours(agg.normalHoursByDevice[1]!),
        unitPrice: UnitPrice.fromYuanPerHour(rate),
      ).fen;
      expect(money.receivableFen, legacyFen);
    },
  );

  test('stored fen rate wins over dirty REAL unit prices', () {
    final agg = AccountService.buildProjects(
      timingRecords: [hoursRecord(id: 1, hours: 10.0)],
    )[projectId]!;

    // 设备默认单价:REAL 写脏(999999.0),fen=38050 才是权威 380.50 元/h。
    final dirtyDevice = Device.fromMap({
      'id': 1,
      'name': 'Device 1',
      'brand': 'sany',
      'default_unit_price': 999999.0,
      'default_unit_price_fen': 38050,
      'base_meter_hours': 0.0,
      'is_active': 1,
      'equipment_type': 'excavator',
    });

    final byDeviceDefault = AccountService.calcMoneyFen(
      agg: agg,
      devices: [dirtyDevice],
      rates: [],
      payments: [],
    );
    // 10h × 380.50 元/h = 3805.00 元。
    expect(byDeviceDefault.receivableFen, 380500);

    // 项目覆盖单价:REAL 写脏(0.01),rate_fen=40000 才是权威 400 元/h。
    final dirtyOverride = ProjectDeviceRate.fromMap({
      'project_id': projectId,
      'project_key': 'Alice||Yard A',
      'device_id': 1,
      'is_breaking': 0,
      'rate': 0.01,
      'rate_fen': 40000,
    });
    final byOverride = AccountService.calcMoneyFen(
      agg: agg,
      devices: [dirtyDevice],
      rates: [dirtyOverride],
      payments: [],
    );
    expect(byOverride.receivableFen, 400000);
  });

  test('breaking falls back to default fen when breaking fen is absent', () {
    final agg = AccountService.buildProjects(
      timingRecords: [hoursRecord(id: 1, hours: 2.0, isBreaking: true)],
    )[projectId]!;

    final withBreaking = AccountService.calcMoneyFen(
      agg: agg,
      devices: [device(id: 1, defaultPrice: 300, breakingPrice: 480)],
      rates: [],
      payments: [],
    );
    expect(withBreaking.receivableFen, 96000); // 2h × 480

    final withoutBreaking = AccountService.calcMoneyFen(
      agg: agg,
      devices: [device(id: 1, defaultPrice: 300)],
      rates: [],
      payments: [],
    );
    expect(withoutBreaking.receivableFen, 60000); // 2h × 300(回落 default)
  });

  test('double rate map is derived from the fen map (display only)', () {
    final devices = [
      device(id: 1, defaultPrice: 380.55),
      device(id: 2, defaultPrice: 99.99, breakingPrice: 120.01),
    ];
    final rates = [
      ProjectDeviceRate(projectKey: 'Alice||Yard A', deviceId: 1, rate: 400.5),
    ];

    for (final isBreaking in [false, true]) {
      final fenMap = AccountService.buildEffectiveRateFenMap(
        projectKey: 'Alice||Yard A',
        devices: devices,
        rates: rates,
        isBreaking: isBreaking,
      );
      final doubleMap = AccountService.buildEffectiveRateMap(
        projectKey: 'Alice||Yard A',
        devices: devices,
        rates: rates,
        isBreaking: isBreaking,
      );
      expect(doubleMap.keys.toSet(), fenMap.keys.toSet());
      for (final entry in fenMap.entries) {
        expect(doubleMap[entry.key], entry.value / 100.0);
      }
    }
  });
}
