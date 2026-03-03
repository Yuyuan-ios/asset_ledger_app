import '../../../data/models/account_payment.dart';
import '../../../data/models/device.dart';
import '../../../data/models/project_device_rate.dart';
import '../../../data/models/timing_record.dart';
import '../use_cases/compute_account_summary_use_case.dart';

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
class AccountStore {
  AccountStore({ComputeAccountSummaryUseCase? computeAccountSummaryUseCase})
    : _computeAccountSummaryUseCase =
          computeAccountSummaryUseCase ?? const ComputeAccountSummaryUseCase();

  final ComputeAccountSummaryUseCase _computeAccountSummaryUseCase;

  // =====================================================================
  // ============================== A) 聚合计算 ==============================
  // =====================================================================

  AccountComputed compute({
    required List<TimingRecord> timingRecords,
    required List<Device> devices,
    required List<ProjectDeviceRate> rates,
    required List<AccountPayment> payments,
  }) {
    return _computeAccountSummaryUseCase.execute(
      timingRecords: timingRecords,
      devices: devices,
      rates: rates,
      payments: payments,
    );
  }
}

class AccountComputed {
  final List<AccountProjectVM> projects;
  final double totalReceivable;
  final double totalReceived;
  final double totalRemaining;
  final double? totalRatio;
  final List<AccountDeviceReceivable> deviceReceivables;

  const AccountComputed({
    required this.projects,
    required this.totalReceivable,
    required this.totalReceived,
    required this.totalRemaining,
    required this.totalRatio,
    required this.deviceReceivables,
  });

  const AccountComputed.empty()
    : projects = const [],
      totalReceivable = 0,
      totalReceived = 0,
      totalRemaining = 0,
      totalRatio = null,
      deviceReceivables = const [];
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

class AccountDeviceReceivable {
  final int deviceId;
  final String name;
  final double amount;

  const AccountDeviceReceivable({
    required this.deviceId,
    required this.name,
    required this.amount,
  });
}
