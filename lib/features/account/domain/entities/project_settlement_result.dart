import '../../../../core/utils/format_utils.dart';
import '../services/project_finance_calculator.dart';

/// 阶段 C Step 5：金额判断统一走 fen 整数。yuan double 转 fen 后比较，
/// 不再使用浮点 epsilon。
int _fen(double yuan) => ProjectFinanceCalculator.yuanToFen(yuan);

class ProjectSettlementResult {
  const ProjectSettlementResult({
    required this.projectId,
    required this.receivable,
    required this.receivedBefore,
    required this.writeOffBefore,
    required this.remainingBefore,
    required this.paymentAmount,
    required this.writeOffAmount,
    required this.receivedAfter,
    required this.writeOffAfter,
    required this.remainingAfter,
    required this.settled,
    this.paymentId,
    this.writeOffId,
  });

  final String projectId;
  final double receivable;
  final double receivedBefore;
  final double writeOffBefore;
  final double remainingBefore;
  final double paymentAmount;
  final double writeOffAmount;
  final double receivedAfter;
  final double writeOffAfter;
  final double remainingAfter;
  final bool settled;
  final int? paymentId;
  final String? writeOffId;

  String get successMessage {
    final hasPayment = _fen(paymentAmount) > 0;
    final hasWriteOff = _fen(writeOffAmount) > 0;
    if (hasPayment && hasWriteOff) {
      return '已收款 ${FormatUtils.money(paymentAmount)}，核销 ${FormatUtils.money(writeOffAmount)}';
    }
    if (hasPayment) {
      return settled ? '已结清' : '已收款 ${FormatUtils.money(paymentAmount)}';
    }
    if (hasWriteOff) {
      return settled ? '已结清' : '已核销 ${FormatUtils.money(writeOffAmount)}';
    }
    return settled ? '已结清' : '保存成功';
  }
}

class DeleteProjectWriteOffResult {
  const DeleteProjectWriteOffResult({
    required this.projectId,
    required this.writeOffId,
    required this.deletedAmount,
    required this.receivable,
    required this.received,
    required this.writeOffBefore,
    required this.writeOffAfter,
    required this.remainingAfter,
    required this.restoredActive,
  });

  final String projectId;
  final String writeOffId;
  final double deletedAmount;
  final double receivable;
  final double received;
  final double writeOffBefore;
  final double writeOffAfter;
  final double remainingAfter;
  final bool restoredActive;

  String get successMessage {
    if (restoredActive) {
      return '已删除核销，待收恢复 ${FormatUtils.money(remainingAfter)}';
    }
    return '已删除核销';
  }
}

class RevokeProjectSettlementStatusResult {
  const RevokeProjectSettlementStatusResult({
    required this.projectId,
    required this.restoredActive,
  });

  final String projectId;
  final bool restoredActive;
}
