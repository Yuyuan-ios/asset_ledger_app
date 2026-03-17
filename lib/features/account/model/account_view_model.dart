import '../../../data/models/account_payment.dart';

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
  final bool isMultiMode;

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
    required this.isMultiMode,
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
