import '../../../data/models/account_payment.dart';
import '../../../data/models/project_id.dart';

enum AccountProjectKind { normal, merged }

const double _accountProjectDisplaySettlementEpsilon = 0.000001;

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

/// 单项目金额的整数分权威快照（按真实 project_id 键控,合并卡按成员求和）。
///
/// 供设备台账等下游直接消费 fen,避免从 double VM 值 round-trip 回 fen
/// 的派生口径(无损但非权威直出,口径变化时会漂移)。
class AccountProjectMoneyFenVM {
  final int receivableFen;
  final int receivedFen;
  final int writeOffFen;

  const AccountProjectMoneyFenVM({
    required this.receivableFen,
    required this.receivedFen,
    required this.writeOffFen,
  });
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

  /// 整数分权威口径（calcMoneyFen 直出,键为真实 project_id）。
  final Map<String, AccountProjectMoneyFenVM> moneyFenByProjectId;

  const AccountComputed({
    required this.projects,
    required this.totalReceivable,
    required this.totalReceived,
    this.totalWriteOff = 0,
    required this.totalRemaining,
    required this.totalRatio,
    this.settlementRate,
    required this.deviceReceivables,
    this.moneyFenByProjectId = const {},
  });

  const AccountComputed.empty()
    : projects = const [],
      totalReceivable = 0,
      totalReceived = 0,
      totalWriteOff = 0,
      totalRemaining = 0,
      totalRatio = null,
      settlementRate = null,
      deviceReceivables = const [],
      moneyFenByProjectId = const {};
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

  /// 真实项目状态：来自 `Project.status == settled`，用于业务动作边界。
  final bool isSettled;

  /// 卡片展示状态：真实已结清，或当前财务口径下已收/核销覆盖总应收。
  final bool isSettledForDisplay;
  final bool hasLinkedExternalWork;

  /// 项目最早计时日期（YYYYMMDD）
  final int minYmd;

  final List<int> deviceIds;
  final Map<int, double> hoursByDevice;
  final double externalWorkHours;
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
    this.isSettled = false,
    bool? isSettledForDisplay,
    this.hasLinkedExternalWork = false,
    required this.minYmd,
    required this.deviceIds,
    required this.hoursByDevice,
    this.externalWorkHours = 0,
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
  }) : isSettledForDisplay =
           isSettledForDisplay ??
           (isSettled ||
               (receivable > _accountProjectDisplaySettlementEpsilon &&
                   receivable - received - writeOff <=
                       _accountProjectDisplaySettlementEpsilon));

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
    double? externalWorkHours,
    bool? isSettled,
    bool? isSettledForDisplay,
    bool? hasLinkedExternalWork,
  }) {
    final nextIsSettled = isSettled ?? this.isSettled;
    final nextReceivable = receivable ?? this.receivable;
    final nextReceived = received ?? this.received;
    final nextWriteOff = writeOff ?? this.writeOff;

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
      isSettled: nextIsSettled,
      isSettledForDisplay:
          isSettledForDisplay ??
          _deriveSettledForDisplay(
            isSettled: nextIsSettled,
            receivable: nextReceivable,
            received: nextReceived,
            writeOff: nextWriteOff,
          ),
      hasLinkedExternalWork:
          hasLinkedExternalWork ?? this.hasLinkedExternalWork,
      minYmd: minYmd,
      deviceIds: deviceIds,
      hoursByDevice: hoursByDevice,
      externalWorkHours: externalWorkHours ?? this.externalWorkHours,
      rentIncomeTotal: rentIncomeTotal,
      minRate: minRate,
      isMultiDevice: isMultiDevice,
      isMultiMode: isMultiMode,
      receivable: nextReceivable,
      received: nextReceived,
      writeOff: nextWriteOff,
      remaining: remaining ?? this.remaining,
      ratio: ratio ?? this.ratio,
      settlementRatio: settlementRatio ?? this.settlementRatio,
      payments: payments,
    );
  }
}

bool _deriveSettledForDisplay({
  required bool isSettled,
  required double receivable,
  required double received,
  required double writeOff,
}) {
  if (isSettled) return true;
  if (receivable <= _accountProjectDisplaySettlementEpsilon) return false;
  return receivable - received - writeOff <=
      _accountProjectDisplaySettlementEpsilon;
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
