import '../../core/money/amount_policy.dart';
import '../models/account_payment.dart';
import '../models/project_device_rate.dart';
import '../models/project_id.dart';
import '../models/project_key.dart';
import '../models/project_write_off.dart';
import '../models/timing_record.dart';
import '../models/device.dart';

const double _accountMoneyEpsilon = 0.0000001;

// =====================================================================
// ============================== AccountService（纯聚合） ==============================
// =====================================================================
//
// 设计目标：
// - 只做“项目聚合 + 金额计算”
// - 不读 DB、不依赖 Store
//
// 口径（你已确认）：
// - 项目身份 = project_id
// - contact/site 只做展示属性和 legacy fallback
// - 应收：sum(hours * 有效单价)
// - 有效单价：项目×设备覆盖优先，否则用 device 默认单价
// - 回款：来自 AccountPayment
// - 不允许超收：由 Store 做校验（Service 只给数）
// - 排序：按项目首次一条计时记录 ymd ASC / DESC 由 UI 决定（这里输出 minYmd）
// - “单价显示”：单设备显示数值；多设备显示“多设备”（UI层用 deviceIds.length 判断）
// =====================================================================

class ProjectAgg {
  final String projectId;
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

  /// 租金模式收入的整数分（fen）汇总。
  ///
  /// 由 [AccountService.buildProjects] 逐条 rent 记录 `round(income * 100)` 后
  /// 累加，是 fen 权威口径（避免先 double 求和再转 fen 的精度漂移）。可选默认 0，
  /// 兼容直接构造 [ProjectAgg] 的旧测试。
  final int rentIncomeFen;

  const ProjectAgg({
    this.projectId = '',
    required this.projectKey,
    required this.contact,
    required this.site,
    required this.minYmd,
    required this.deviceIds,
    required this.hoursByDevice,
    required this.normalHoursByDevice,
    required this.breakingHoursByDevice,
    required this.rentIncomeTotal,
    this.rentIncomeFen = 0,
  });

  ProjectKey get pk => ProjectKey.fromKey(projectKey);
}

class ProjectMoney {
  final double receivable;
  final double received;
  final double writeOff;
  final double remaining;

  /// 0~1（除零保护：不可算时返回 null）
  final double? ratio;
  final double? settlementRatio;

  const ProjectMoney({
    required this.receivable,
    required this.received,
    required this.writeOff,
    required this.remaining,
    required this.ratio,
    required this.settlementRatio,
  });
}

/// 项目金额的整数分（fen）原始口径载体（R2）。
///
/// 与 [ProjectMoney]（double 元，供 UI / 旧调用兼容）分工明确：本类只承载三笔
/// 权威整数分（应收 / 实收 / 核销），不做 remaining/ratio/overPaid/isSettled 的
/// 派生计算——那些交给 features 层的 `ProjectFinanceCalculator.summarizeTotals`
/// 统一计算，从而消除 double -> yuanToFen 的 round-trip 精度漂移。
///
/// 之所以放在 data 层而非直接返回 `ProjectFinanceSummary`：`AccountService`
/// 位于 data 层，不能 import features 层的 `ProjectFinanceCalculator`
/// （`no_data_layer_imports_from_features` 架构约束）。
class ProjectMoneyFen {
  final int receivableFen;
  final int receivedFen;
  final int writeOffFen;

  const ProjectMoneyFen({
    required this.receivableFen,
    required this.receivedFen,
    required this.writeOffFen,
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
      final projectId = t.effectiveProjectId;
      final mut = m.putIfAbsent(
        projectId,
        () => _MutAgg(projectId, key, contact, site),
      );

      // minYmd：项目首次计时日期（取最小 startDate）
      final ymd = t.startDate;
      if (ymd < mut.minYmd) mut.minYmd = ymd;

      // rent：only accumulate income.
      if (t.type == TimingType.rent) {
        // rentIncomeTotal 是 yuan 展示总额（REAL 兼容口径，保留）。
        mut.rentIncomeTotal += t.income;
        // R5.26-B4：fen 权威口径读优先 income_fen（[TimingRecord.incomeFen] =
        // 存储 income_fen ?? round(income*100)）。对一致数据与旧
        // `Money.fromYuan(t.income).fen` 逐记录等价；缺 fen 的 legacy 行自动回退。
        mut.rentIncomeFen += t.incomeFen;
        continue;
      }

      // hours：按模式累计。
      // S2 读路径切换：工时来源改读统一计量权威 [TimingRecord.hoursFromQuantity]
      // （quantityScaled = 存储 quantity_scaled ?? round(hours×1000)），hours
      // REAL 退为派生兜底。与旧 `+ t.hours` 的差异仅是逐记录对齐到毫时网格——
      // 后续应收经 AmountPolicy 时本就按毫时取整，对网格内数据逐记录等价。
      final target = t.isBreaking
          ? mut.breakingHoursByDevice
          : mut.normalHoursByDevice;
      target[t.deviceId] = (target[t.deviceId] ?? 0.0) + t.hoursFromQuantity;

      // 兼容旧口径：总工时
      mut.hoursByDevice[t.deviceId] =
          (mut.hoursByDevice[t.deviceId] ?? 0.0) + t.hoursFromQuantity;
    }

    // 输出不可变结构
    final out = <String, ProjectAgg>{};
    for (final e in m.entries) {
      final mut = e.value;
      final deviceIds = mut.hoursByDevice.keys.toList()..sort();

      out[e.key] = ProjectAgg(
        projectId: mut.projectId,
        projectKey: mut.projectKey,
        contact: mut.contact,
        site: mut.site,
        minYmd: mut.minYmd,
        deviceIds: deviceIds,
        hoursByDevice: Map.unmodifiable(mut.hoursByDevice),
        normalHoursByDevice: Map.unmodifiable(mut.normalHoursByDevice),
        breakingHoursByDevice: Map.unmodifiable(mut.breakingHoursByDevice),
        rentIncomeTotal: mut.rentIncomeTotal,
        rentIncomeFen: mut.rentIncomeFen,
      );
    }
    return out;
  }

  static ProjectMoney calcMoney({
    required ProjectAgg agg,
    required List<Device> devices,
    required List<ProjectDeviceRate> rates,
    required List<AccountPayment> payments,
    List<ProjectWriteOff> writeOffs = const [],
  }) {
    final effectiveRate = buildEffectiveRateMap(
      projectKey: agg.projectKey,
      projectId: agg.projectId,
      devices: devices,
      rates: rates,
      isBreaking: false,
    );
    final effectiveBreakingRate = buildEffectiveRateMap(
      projectKey: agg.projectKey,
      projectId: agg.projectId,
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
      receivable += _calculateHoursAmount(hours: hours, rate: effRate);
    }
    for (final entry in agg.breakingHoursByDevice.entries) {
      final deviceId = entry.key;
      final hours = entry.value;
      final effRate = effectiveBreakingRate[deviceId] ?? 0.0;
      receivable += _calculateHoursAmount(hours: hours, rate: effRate);
    }

    // rent：纳入应收（月租金额属于应收，不属于已收）
    receivable += agg.rentIncomeTotal;

    // 2) 已收：仅收款记录累计
    final received = sumReceivedByProject(
      projectKey: agg.projectKey,
      projectId: agg.projectId,
      payments: payments,
    );
    final writeOff = sumWriteOffByProject(
      projectKey: agg.projectKey,
      projectId: agg.projectId,
      writeOffs: writeOffs,
    );

    // 3) 剩余、真实回款率、结清率（除零保护）
    final rawRemaining = receivable - received - writeOff;
    final remaining = rawRemaining.abs() <= _accountMoneyEpsilon
        ? 0.0
        : rawRemaining;
    final ratio = (receivable <= _accountMoneyEpsilon)
        ? null
        : (received / receivable);
    final settlementRatio = (receivable <= _accountMoneyEpsilon)
        ? null
        : ((received + writeOff) / receivable);

    return ProjectMoney(
      receivable: receivable,
      received: received,
      writeOff: writeOff,
      remaining: remaining,
      ratio: ratio,
      settlementRatio: settlementRatio,
    );
  }

  /// fen-native 项目金额口径（R2）。
  ///
  /// 与 [calcMoney] 并行存在，互不替换：
  /// - [calcMoney] 返回 double 元，供 UI / 旧调用方（计时分析、图表、保存影响等）
  ///   兼容，行为不变。
  /// - 本方法返回整数分 [ProjectMoneyFen]，供 ComputeAccountSummaryUseCase 直出
  ///   fen，消除 `double -> yuanToFen` 的 round-trip 精度漂移。
  ///
  /// 口径：
  /// - receivableFen：工时收入按 [AmountPolicy] 整数分规则计算（毫工时 × 分/小时）；
  ///   租金/台班收入取 [ProjectAgg.rentIncomeFen]（buildProjects 逐记录 round 累加）。
  /// - receivedFen：累加 [AccountPayment.amountFen]（权威，不读 amount double）。
  /// - writeOffFen：累加 [ProjectWriteOff.amountFen]（权威，不读 amount double）。
  ///
  /// remaining / ratio / overPaid / isSettled 不在此计算，交由上层
  /// `ProjectFinanceCalculator.summarizeTotals` 统一处理。
  static ProjectMoneyFen calcMoneyFen({
    required ProjectAgg agg,
    required List<Device> devices,
    required List<ProjectDeviceRate> rates,
    required List<AccountPayment> payments,
    List<ProjectWriteOff> writeOffs = const [],
  }) {
    final effectiveRate = buildEffectiveRateMap(
      projectKey: agg.projectKey,
      projectId: agg.projectId,
      devices: devices,
      rates: rates,
      isBreaking: false,
    );
    final effectiveBreakingRate = buildEffectiveRateMap(
      projectKey: agg.projectKey,
      projectId: agg.projectId,
      devices: devices,
      rates: rates,
      isBreaking: true,
    );

    var receivableFen = 0;
    for (final entry in agg.normalHoursByDevice.entries) {
      receivableFen += _hoursAmountFen(
        hours: entry.value,
        rate: effectiveRate[entry.key] ?? 0.0,
      );
    }
    for (final entry in agg.breakingHoursByDevice.entries) {
      receivableFen += _hoursAmountFen(
        hours: entry.value,
        rate: effectiveBreakingRate[entry.key] ?? 0.0,
      );
    }
    // rent：纳入应收（与 calcMoney 一致），使用逐记录累加的 fen。
    receivableFen += agg.rentIncomeFen;

    final receivedFen = sumReceivedFenByProject(
      projectKey: agg.projectKey,
      projectId: agg.projectId,
      payments: payments,
    );
    final writeOffFen = sumWriteOffFenByProject(
      projectKey: agg.projectKey,
      projectId: agg.projectId,
      writeOffs: writeOffs,
    );

    return ProjectMoneyFen(
      receivableFen: receivableFen,
      receivedFen: receivedFen,
      writeOffFen: writeOffFen,
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
        projectId: agg.projectId,
        devices: devices,
        rates: rates,
        isBreaking: false,
      );
      final effectiveBreakingRate = buildEffectiveRateMap(
        projectKey: agg.projectKey,
        projectId: agg.projectId,
        devices: devices,
        rates: rates,
        isBreaking: true,
      );
      for (final entry in agg.normalHoursByDevice.entries) {
        final deviceId = entry.key;
        final hours = entry.value;
        final rate = effectiveRate[deviceId] ?? 0.0;
        totals[deviceId] =
            (totals[deviceId] ?? 0.0) +
            _calculateHoursAmount(hours: hours, rate: rate);
      }
      for (final entry in agg.breakingHoursByDevice.entries) {
        final deviceId = entry.key;
        final hours = entry.value;
        final rate = effectiveBreakingRate[deviceId] ?? 0.0;
        totals[deviceId] =
            (totals[deviceId] ?? 0.0) +
            _calculateHoursAmount(hours: hours, rate: rate);
      }
    }
    for (final t in timingRecords) {
      if (t.type != TimingType.rent) continue;
      if (t.income <= 0) continue;
      totals[t.deviceId] = (totals[t.deviceId] ?? 0.0) + t.income;
    }
    return totals;
  }

  static Map<int, double> buildEffectiveRateMap({
    String? projectKey,
    String? projectId,
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
    final targetProjectId = _resolveProjectId(
      projectId: projectId,
      projectKey: projectKey,
    );
    for (final r in rates) {
      if (r.effectiveProjectId != targetProjectId) continue;
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
      projectId: agg.projectId,
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
      projectId: agg.projectId,
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
    String? projectKey,
    String? projectId,
    required List<AccountPayment> payments,
    int? excludePaymentId,
  }) {
    double sum = 0.0;
    final targetProjectId = _resolveProjectId(
      projectId: projectId,
      projectKey: projectKey,
    );
    for (final p in payments) {
      if (p.effectiveProjectId != targetProjectId) continue;
      if (excludePaymentId != null && p.id == excludePaymentId) continue;
      sum += p.amount;
    }
    return sum;
  }

  static double sumWriteOffByProject({
    String? projectKey,
    String? projectId,
    required List<ProjectWriteOff> writeOffs,
  }) {
    double sum = 0.0;
    final targetProjectId = _resolveProjectId(
      projectId: projectId,
      projectKey: projectKey,
    );
    for (final writeOff in writeOffs) {
      if (writeOff.projectId != targetProjectId) continue;
      sum += writeOff.amount;
    }
    return sum;
  }

  /// fen 权威实收汇总：累加 [AccountPayment.amountFen]（派生自 amount_fen 列），
  /// 不读 amount double，避免跨记录 double 求和的浮点累积。
  static int sumReceivedFenByProject({
    String? projectKey,
    String? projectId,
    required List<AccountPayment> payments,
    int? excludePaymentId,
  }) {
    var sum = 0;
    final targetProjectId = _resolveProjectId(
      projectId: projectId,
      projectKey: projectKey,
    );
    for (final p in payments) {
      if (p.effectiveProjectId != targetProjectId) continue;
      if (excludePaymentId != null && p.id == excludePaymentId) continue;
      sum += p.amountFen;
    }
    return sum;
  }

  /// fen 权威核销汇总：累加 [ProjectWriteOff.amountFen]，不读 amount double。
  static int sumWriteOffFenByProject({
    String? projectKey,
    String? projectId,
    required List<ProjectWriteOff> writeOffs,
  }) {
    var sum = 0;
    final targetProjectId = _resolveProjectId(
      projectId: projectId,
      projectKey: projectKey,
    );
    for (final writeOff in writeOffs) {
      if (writeOff.projectId != targetProjectId) continue;
      sum += writeOff.amountFen;
    }
    return sum;
  }

  static String _resolveProjectId({String? projectId, String? projectKey}) {
    final normalizedId = projectId?.trim() ?? '';
    if (normalizedId.isNotEmpty) return normalizedId;
    return ProjectId.legacyFromKey(projectKey ?? '');
  }

  static double _calculateHoursAmount({
    required double hours,
    required double rate,
  }) {
    return AmountPolicy.calculateAmount(
      hours: WorkHours.fromHours(hours),
      unitPrice: UnitPrice.fromYuanPerHour(rate),
    ).yuan;
  }

  /// 工时收入的整数分：与 [_calculateHoursAmount] 同一 [AmountPolicy] 规则，
  /// 但直接取 `.fen` 不经 yuan double 中转。
  static int _hoursAmountFen({required double hours, required double rate}) {
    return AmountPolicy.calculateAmount(
      hours: WorkHours.fromHours(hours),
      unitPrice: UnitPrice.fromYuanPerHour(rate),
    ).fen;
  }
}

class _MutAgg {
  final String projectId;
  final String projectKey;
  final String contact;
  final String site;

  /// 项目首次计时日期（取最小 startDate）
  int minYmd = 99991231;

  final Map<int, double> hoursByDevice = {};
  final Map<int, double> normalHoursByDevice = {};
  final Map<int, double> breakingHoursByDevice = {};
  double rentIncomeTotal = 0.0;
  int rentIncomeFen = 0;

  _MutAgg(this.projectId, this.projectKey, this.contact, this.site);
}
