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

  /// 租金模式汇总（若你后续要展示 rent 部分，可以用）
  final double rentIncomeTotal;

  const ProjectAgg({
    required this.projectKey,
    required this.contact,
    required this.site,
    required this.minYmd,
    required this.deviceIds,
    required this.hoursByDevice,
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

      // hours：累计到 device
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
    // 设备默认单价映射
    final defaultRate = <int, double>{};
    for (final d in devices) {
      if (d.id != null) defaultRate[d.id!] = d.defaultUnitPrice;
    }

    // 覆盖单价映射（只取该项目）
    final override = <int, double>{};
    for (final r in rates) {
      if (r.projectKey != agg.projectKey) continue;
      override[r.deviceId] = r.rate;
    }

    // 1) 应收：sum(hours * effectiveRate)
    double receivable = 0.0;

    for (final entry in agg.hoursByDevice.entries) {
      final deviceId = entry.key;
      final hours = entry.value;

      final effRate = override[deviceId] ?? defaultRate[deviceId] ?? 0.0;
      receivable += hours * effRate;
    }

    // （可选）如果你未来决定 rent 也算应收，就加上：
    // receivable += agg.rentIncomeTotal;

    // 2) 已收：sum(payments)
    double received = 0.0;
    for (final p in payments) {
      if (p.projectKey != agg.projectKey) continue;
      received += p.amount;
    }

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
}

class _MutAgg {
  final String projectKey;
  final String contact;
  final String site;

  /// 项目首次计时日期（取最小 startDate）
  int minYmd = 99991231;

  final Map<int, double> hoursByDevice = {};
  double rentIncomeTotal = 0.0;

  _MutAgg(this.projectKey, this.contact, this.site);
}
