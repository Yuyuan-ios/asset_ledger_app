import '../models/account_payment.dart';
import '../models/project_device_rate.dart';
import '../models/project_key.dart';
import '../models/timing_record.dart';
import '../models/device.dart';

// =====================================================================
// ============================== AccountService（纯聚合） ==============================
// =====================================================================
//
// 设计目标：
// - 只做“项目聚合 + 金额计算”
// - 不读 DB、不依赖 Store
//
// 口径（你已确认）：
// - 项目 = contact + site
// - 应收：sum(hours * 有效单价)
// - 有效单价：项目×设备覆盖优先，否则用 device 默认单价
// - 回款：来自 AccountPayment
// - 不允许超收：由 Store 做校验（Service 只给数）
// - 排序：按项目首次一条计时记录 ymd ASC / DESC 由 UI 决定（这里输出 minYmd）
// - “单价显示”：单设备显示数值；多设备显示“多设备”（UI层用 deviceIds.length 判断）
// =====================================================================

class ProjectAgg {
  final String projectKey;
  final String contact;
  final String site;

  /// 项目首次计时日期（取最小 startDate）
  final int minYmd;

  /// 项目涉及的设备集合（只统计 hours 类型的设备参与；rent 记录不参与单价）
  final List<int> deviceIds;

  /// 每台设备的总工时
  final Map<int, double> hoursByDevice;
  final Map<int, double> normalHoursByDevice;
  final Map<int, double> breakingHoursByDevice;

  /// 租金模式汇总（若你后续要展示 rent 部分，可以用）
  final double rentIncomeTotal;

  const ProjectAgg({
    required this.projectKey,
    required this.contact,
    required this.site,
    required this.minYmd,
    required this.deviceIds,
    required this.hoursByDevice,
    required this.normalHoursByDevice,
    required this.breakingHoursByDevice,
    required this.rentIncomeTotal,
  });

  ProjectKey get pk => ProjectKey.fromKey(projectKey);
}

class ProjectMoney {
  final double receivable;
  final double received;
  final double remaining;

  /// 0~1（除零保护：不可算时返回 null）
  final double? ratio;

  const ProjectMoney({
    required this.receivable,
    required this.received,
    required this.remaining,
    required this.ratio,
  });
}

class ProjectRateInfo {
  final double? minRate;
  final bool isMultiDevice;
  final bool isMultiMode;

  const ProjectRateInfo({
    required this.minRate,
    required this.isMultiDevice,
    required this.isMultiMode,
  });
}

class AccountService {
  const AccountService._();

  static Map<String, ProjectAgg> buildProjects({
    required List<TimingRecord> timingRecords,
  }) {
    final Map<String, _MutAgg> m = {};

    for (final t in timingRecords) {
      final contact = t.contact.trim();
      final site = t.site.trim();

      if (contact.isEmpty || site.isEmpty) continue;

      final key = ProjectKey.buildKey(contact: contact, site: site);
      final mut = m.putIfAbsent(key, () => _MutAgg(key, contact, site));

      // minYmd：项目首次计时日期（取最小 startDate）
      final ymd = t.startDate;
      if (ymd < mut.minYmd) mut.minYmd = ymd;

      // rent：只累计 income（供你后续显示）
      if (t.type == TimingType.rent) {
        mut.rentIncomeTotal += t.income;
        continue;
      }

      // hours：按模式累计
      final target = t.isBreaking
          ? mut.breakingHoursByDevice
          : mut.normalHoursByDevice;
      target[t.deviceId] = (target[t.deviceId] ?? 0.0) + t.hours;

      // 兼容旧口径：总工时
      mut.hoursByDevice[t.deviceId] =
          (mut.hoursByDevice[t.deviceId] ?? 0.0) + t.hours;
    }

    // 输出不可变结构
    final out = <String, ProjectAgg>{};
    for (final e in m.entries) {
      final mut = e.value;
      final deviceIds = mut.hoursByDevice.keys.toList()..sort();

      out[e.key] = ProjectAgg(
        projectKey: mut.projectKey,
        contact: mut.contact,
        site: mut.site,
        minYmd: mut.minYmd,
        deviceIds: deviceIds,
        hoursByDevice: Map.unmodifiable(mut.hoursByDevice),
        normalHoursByDevice: Map.unmodifiable(mut.normalHoursByDevice),
        breakingHoursByDevice: Map.unmodifiable(mut.breakingHoursByDevice),
        rentIncomeTotal: mut.rentIncomeTotal,
      );
    }
    return out;
  }

  static ProjectMoney calcMoney({
    required ProjectAgg agg,
    required List<Device> devices,
    required List<ProjectDeviceRate> rates,
    required List<AccountPayment> payments,
  }) {
    final effectiveRate = buildEffectiveRateMap(
      projectKey: agg.projectKey,
      devices: devices,
      rates: rates,
      isBreaking: false,
    );
    final effectiveBreakingRate = buildEffectiveRateMap(
      projectKey: agg.projectKey,
      devices: devices,
      rates: rates,
      isBreaking: true,
    );

    // 1) 应收：sum(hours * effectiveRate)
    double receivable = 0.0;

    for (final entry in agg.normalHoursByDevice.entries) {
      final deviceId = entry.key;
      final hours = entry.value;

      final effRate = effectiveRate[deviceId] ?? 0.0;
      receivable += hours * effRate;
    }
    for (final entry in agg.breakingHoursByDevice.entries) {
      final deviceId = entry.key;
      final hours = entry.value;
      final effRate = effectiveBreakingRate[deviceId] ?? 0.0;
      receivable += hours * effRate;
    }

    // rent：纳入应收（月租金额属于应收，不属于已收）
    receivable += agg.rentIncomeTotal;

    // 2) 已收：仅收款记录累计
    final received = sumReceivedByProject(
      projectKey: agg.projectKey,
      payments: payments,
    );

    // 3) 剩余 & 回款率（除零保护）
    final remaining = receivable - received;
    final ratio = (receivable <= 0.0000001) ? null : (received / receivable);

    return ProjectMoney(
      receivable: receivable,
      received: received,
      remaining: remaining,
      ratio: ratio,
    );
  }

  static Map<int, double> calcReceivableByDevice({
    required List<TimingRecord> timingRecords,
    required List<Device> devices,
    required List<ProjectDeviceRate> rates,
  }) {
    final projects = buildProjects(timingRecords: timingRecords);
    final totals = <int, double>{};

    for (final agg in projects.values) {
      final effectiveRate = buildEffectiveRateMap(
        projectKey: agg.projectKey,
        devices: devices,
        rates: rates,
        isBreaking: false,
      );
      final effectiveBreakingRate = buildEffectiveRateMap(
        projectKey: agg.projectKey,
        devices: devices,
        rates: rates,
        isBreaking: true,
      );
      for (final entry in agg.normalHoursByDevice.entries) {
        final deviceId = entry.key;
        final hours = entry.value;
        final rate = effectiveRate[deviceId] ?? 0.0;
        totals[deviceId] = (totals[deviceId] ?? 0.0) + hours * rate;
      }
      for (final entry in agg.breakingHoursByDevice.entries) {
        final deviceId = entry.key;
        final hours = entry.value;
        final rate = effectiveBreakingRate[deviceId] ?? 0.0;
        totals[deviceId] = (totals[deviceId] ?? 0.0) + hours * rate;
      }
    }
    return totals;
  }

  static Map<int, double> buildEffectiveRateMap({
    required String projectKey,
    required List<Device> devices,
    required List<ProjectDeviceRate> rates,
    bool isBreaking = false,
  }) {
    final defaultRate = <int, double>{};
    for (final d in devices) {
      if (d.id == null) continue;
      if (isBreaking) {
        defaultRate[d.id!] = d.breakingUnitPrice ?? d.defaultUnitPrice;
      } else {
        defaultRate[d.id!] = d.defaultUnitPrice;
      }
    }

    final override = <int, double>{};
    for (final r in rates) {
      if (r.projectKey != projectKey) continue;
      if (r.isBreaking != isBreaking) continue;
      override[r.deviceId] = r.rate;
    }

    final out = <int, double>{};
    for (final entry in defaultRate.entries) {
      final id = entry.key;
      out[id] = override[id] ?? entry.value;
    }
    for (final entry in override.entries) {
      out[entry.key] = entry.value;
    }
    return out;
  }

  static ProjectRateInfo calcRateInfo({
    required ProjectAgg agg,
    required List<Device> devices,
    required List<ProjectDeviceRate> rates,
  }) {
    final used = <double>[];
    final effectiveRate = buildEffectiveRateMap(
      projectKey: agg.projectKey,
      devices: devices,
      rates: rates,
    );
    for (final entry in agg.normalHoursByDevice.entries) {
      if (entry.value <= 0) continue;
      final rate = effectiveRate[entry.key] ?? 0.0;
      if (rate > 0) used.add(rate);
    }

    // 同一项目下若同一设备同时出现普通/破碎工时，则视为多模式
    var multiMode = false;
    for (final id in agg.deviceIds) {
      final normal = (agg.normalHoursByDevice[id] ?? 0) > 0;
      final breaking = (agg.breakingHoursByDevice[id] ?? 0) > 0;
      if (normal && breaking) {
        multiMode = true;
        break;
      }
    }

    final effectiveBreakingRate = buildEffectiveRateMap(
      projectKey: agg.projectKey,
      devices: devices,
      rates: rates,
      isBreaking: true,
    );
    for (final entry in agg.breakingHoursByDevice.entries) {
      if (entry.value <= 0) continue;
      final rate = effectiveBreakingRate[entry.key] ?? 0.0;
      if (rate > 0) used.add(rate);
    }

    if (used.isEmpty) {
      return const ProjectRateInfo(
        minRate: null,
        isMultiDevice: false,
        isMultiMode: false,
      );
    }

    used.sort();
    return ProjectRateInfo(
      minRate: used.first,
      isMultiDevice: agg.deviceIds.length > 1,
      isMultiMode: multiMode,
    );
  }

  static double sumReceivedByProject({
    required String projectKey,
    required List<AccountPayment> payments,
    int? excludePaymentId,
  }) {
    double sum = 0.0;
    for (final p in payments) {
      if (p.projectKey != projectKey) continue;
      if (excludePaymentId != null && p.id == excludePaymentId) continue;
      sum += p.amount;
    }
    return sum;
  }
}

class _MutAgg {
  final String projectKey;
  final String contact;
  final String site;

  /// 项目首次计时日期（取最小 startDate）
  int minYmd = 99991231;

  final Map<int, double> hoursByDevice = {};
  final Map<int, double> normalHoursByDevice = {};
  final Map<int, double> breakingHoursByDevice = {};
  double rentIncomeTotal = 0.0;

  _MutAgg(this.projectKey, this.contact, this.site);
}
