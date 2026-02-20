import 'package:flutter/foundation.dart';

import '../models/account_payment.dart';
import '../models/device.dart';
import '../models/project_device_rate.dart';
import '../models/timing_record.dart';
import '../services/account_service.dart';

/// AccountStore（聚合/派生 Store）
///
/// 设计目标：
/// - 只做“原始数据 -> UI VM”的转换（可复用、可测试）
/// - 不读 DB、不依赖 Repo、不做 CRUD（CRUD 放在 AccountPaymentStore）
///
/// 输入：timingRecords / devices / rates / payments
/// 输出：AccountComputed（项目列表 VM + 总览）
///
/// 口径：
/// - 项目聚合：使用 AccountService.buildProjects
/// - 金额计算：使用 AccountService.calcMoney
/// - 项目日期：统一使用 agg.minYmd（项目最早计时日期）
/// - 排序：minYmd DESC（越晚越靠前，越早越靠后）
///
/// ✅ S2：筛选状态放在 Store（账户页只负责触发弹窗/设置筛选条件）
class AccountStore extends ChangeNotifier {
  AccountStore();

  // =====================================================================
  // ============================== A) 项目筛选状态 ==============================
  // =====================================================================

  /// 项目筛选关键词：匹配 displayName（联系人 + 工地）
  String _projectFilterKeyword = '';

  String get projectFilterKeyword => _projectFilterKeyword;

  /// 设置筛选关键词（空字符串表示不筛选）
  void setProjectFilterKeyword(String v) {
    final nv = v.trim();
    if (nv == _projectFilterKeyword) return;
    _projectFilterKeyword = nv;
    notifyListeners();
  }

  /// 清空筛选
  void clearProjectFilter() {
    if (_projectFilterKeyword.isEmpty) return;
    _projectFilterKeyword = '';
    notifyListeners();
  }

  /// 根据当前筛选条件过滤项目列表（不改数据，只返回过滤结果）
  List<AccountProjectVM> filterProjects(List<AccountProjectVM> projects) {
    final q = _projectFilterKeyword.trim().toLowerCase();
    if (q.isEmpty) return projects;

    return projects
        .where((p) => p.displayName.toLowerCase().contains(q))
        .toList();
  }

  // =====================================================================
  // ============================== B) 聚合计算 ==============================
  // =====================================================================

  AccountComputed compute({
    required List<TimingRecord> timingRecords,
    required List<Device> devices,
    required List<ProjectDeviceRate> rates,
    required List<AccountPayment> payments,
  }) {
    final projects = AccountService.buildProjects(timingRecords: timingRecords);

    // 按项目“最早计时日期”降序（越晚越靠前；越早越靠后）
    final keys = projects.keys.toList()
      ..sort((a, b) => projects[b]!.minYmd.compareTo(projects[a]!.minYmd));

    final items = <AccountProjectVM>[];
    double totalReceivable = 0.0;
    double totalReceived = 0.0;

    for (final k in keys) {
      final agg = projects[k]!;

      final money = AccountService.calcMoney(
        agg: agg,
        devices: devices,
        rates: rates,
        payments: payments,
      );

      totalReceivable += money.receivable;
      totalReceived += money.received;

      final rateInfo = buildRateInfo(agg: agg, devices: devices, rates: rates);

      items.add(
        AccountProjectVM(
          projectKey: agg.projectKey,
          displayName: agg.pk.displayName,
          minYmd: agg.minYmd,
          deviceIds: agg.deviceIds,
          hoursByDevice: agg.hoursByDevice,
          rentIncomeTotal: agg.rentIncomeTotal,
          minRate: rateInfo.minRate,
          isMultiDevice: rateInfo.isMultiDevice,
          receivable: money.receivable,
          received: money.received,
          remaining: money.remaining,
          ratio: money.ratio,
          payments:
              payments.where((p) => p.projectKey == agg.projectKey).toList()
                ..sort((a, b) => b.ymd.compareTo(a.ymd)),
        ),
      );
    }

    final remaining = totalReceivable - totalReceived;
    final ratio = (totalReceivable <= 0.0000001)
        ? null
        : (totalReceived / totalReceivable);

    return AccountComputed(
      projects: items,
      totalReceivable: totalReceivable,
      totalReceived: totalReceived,
      totalRemaining: remaining,
      totalRatio: ratio,
    );
  }

  /// 构建项目单价信息（最小单价 + 多设备标记）
  RateInfo buildRateInfo({
    required ProjectAgg agg,
    required List<Device> devices,
    required List<ProjectDeviceRate> rates,
  }) {
    final defaultRate = <int, double>{};
    for (final d in devices) {
      if (d.id != null) defaultRate[d.id!] = d.defaultUnitPrice;
    }

    final override = <int, double>{};
    for (final r in rates) {
      if (r.projectKey != agg.projectKey) continue;
      override[r.deviceId] = r.rate;
    }

    final used = <double>[];
    for (final id in agg.deviceIds) {
      final eff = override[id] ?? defaultRate[id] ?? 0.0;
      if (eff > 0) used.add(eff);
    }

    if (used.isEmpty) {
      return const RateInfo(minRate: null, isMultiDevice: false);
    }

    used.sort();
    return RateInfo(
      minRate: used.first,
      isMultiDevice: agg.deviceIds.length > 1,
    );
  }
}

class AccountComputed {
  final List<AccountProjectVM> projects;
  final double totalReceivable;
  final double totalReceived;
  final double totalRemaining;
  final double? totalRatio;

  const AccountComputed({
    required this.projects,
    required this.totalReceivable,
    required this.totalReceived,
    required this.totalRemaining,
    required this.totalRatio,
  });

  const AccountComputed.empty()
    : projects = const [],
      totalReceivable = 0,
      totalReceived = 0,
      totalRemaining = 0,
      totalRatio = null;
}

class AccountProjectVM {
  final String projectKey;
  final String displayName;

  /// 项目最早计时日期（YYYYMMDD）
  final int minYmd;

  final List<int> deviceIds;
  final Map<int, double> hoursByDevice;
  final double rentIncomeTotal;

  final double? minRate;
  final bool isMultiDevice;

  final double receivable;
  final double received;
  final double remaining;
  final double? ratio;

  final List<AccountPayment> payments;

  const AccountProjectVM({
    required this.projectKey,
    required this.displayName,
    required this.minYmd,
    required this.deviceIds,
    required this.hoursByDevice,
    required this.rentIncomeTotal,
    required this.minRate,
    required this.isMultiDevice,
    required this.receivable,
    required this.received,
    required this.remaining,
    required this.ratio,
    required this.payments,
  });
}

class RateInfo {
  final double? minRate;
  final bool isMultiDevice;

  const RateInfo({required this.minRate, required this.isMultiDevice});
}
