import '../../../data/models/account_payment.dart';
import '../../../data/models/project_id.dart';

enum AccountProjectKind { normal, merged }

class AccountExternalWorkProjectVM {
  final String importBatchId;
  final String displayName;
  final String sourceDisplayName;
  final String siteSummary;
  final int minYmd;
  final int payableFen;
  final int paidFen;
  final int recordCount;

  /// 该外协包是否已关联到本地项目（已关联仍显示在外协页，头像带链条角标）。
  final bool linked;

  /// 已关联到的本地项目 id（未关联为 null）。
  final String? linkedProjectId;

  const AccountExternalWorkProjectVM({
    required this.importBatchId,
    required this.displayName,
    required this.sourceDisplayName,
    required this.siteSummary,
    required this.minYmd,
    required this.payableFen,
    this.paidFen = 0,
    required this.recordCount,
    this.linked = false,
    this.linkedProjectId,
  });

  double get payable => payableFen / 100;

  double get payablePaidRatio {
    if (payableFen <= 0) return 1;
    return (paidFen / payableFen).clamp(0.0, 1.0).toDouble();
  }
}

class AccountComputed {
  final List<AccountProjectVM> projects;
  final double totalReceivable;
  final double totalReceived;
  final double totalWriteOff;
  final double totalRemaining;
  final double? totalRatio;
  final double? settlementRate;
  final List<AccountDeviceReceivable> deviceReceivables;

  const AccountComputed({
    required this.projects,
    required this.totalReceivable,
    required this.totalReceived,
    this.totalWriteOff = 0,
    required this.totalRemaining,
    required this.totalRatio,
    this.settlementRate,
    required this.deviceReceivables,
  });

  const AccountComputed.empty()
    : projects = const [],
      totalReceivable = 0,
      totalReceived = 0,
      totalWriteOff = 0,
      totalRemaining = 0,
      totalRatio = null,
      settlementRate = null,
      deviceReceivables = const [];
}

class AccountProjectVM {
  final String projectId;
  final String projectKey;
  final String displayName;
  final AccountProjectKind kind;
  final int? mergeGroupId;
  final List<String> memberProjectKeys;
  final List<String> memberProjectIds;
  final List<String> includedSites;
  final String? includedSitesText;

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
  final double writeOff;
  final double remaining;
  final double? ratio;
  final double? settlementRatio;

  final List<AccountPayment> payments;

  const AccountProjectVM({
    this.projectId = '',
    required this.projectKey,
    required this.displayName,
    this.kind = AccountProjectKind.normal,
    this.mergeGroupId,
    this.memberProjectKeys = const [],
    this.memberProjectIds = const [],
    this.includedSites = const [],
    this.includedSitesText,
    required this.minYmd,
    required this.deviceIds,
    required this.hoursByDevice,
    required this.rentIncomeTotal,
    required this.minRate,
    required this.isMultiDevice,
    required this.isMultiMode,
    required this.receivable,
    required this.received,
    this.writeOff = 0,
    required this.remaining,
    required this.ratio,
    this.settlementRatio,
    required this.payments,
  });

  String get effectiveProjectId {
    if (projectId.trim().isNotEmpty) return projectId.trim();
    return ProjectId.legacyFromKey(projectKey);
  }

  AccountProjectVM copyWith({
    String? displayName,
    double? receivable,
    double? received,
    double? writeOff,
    double? remaining,
    double? ratio,
    double? settlementRatio,
  }) {
    return AccountProjectVM(
      projectId: projectId,
      projectKey: projectKey,
      displayName: displayName ?? this.displayName,
      kind: kind,
      mergeGroupId: mergeGroupId,
      memberProjectKeys: memberProjectKeys,
      memberProjectIds: memberProjectIds,
      includedSites: includedSites,
      includedSitesText: includedSitesText,
      minYmd: minYmd,
      deviceIds: deviceIds,
      hoursByDevice: hoursByDevice,
      rentIncomeTotal: rentIncomeTotal,
      minRate: minRate,
      isMultiDevice: isMultiDevice,
      isMultiMode: isMultiMode,
      receivable: receivable ?? this.receivable,
      received: received ?? this.received,
      writeOff: writeOff ?? this.writeOff,
      remaining: remaining ?? this.remaining,
      ratio: ratio ?? this.ratio,
      settlementRatio: settlementRatio ?? this.settlementRatio,
      payments: payments,
    );
  }
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
