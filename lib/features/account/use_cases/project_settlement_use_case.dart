import '../../../data/models/project_write_off.dart';
import '../domain/entities/project_settlement_result.dart';
import '../domain/repositories/project_settlement_repository.dart';
import '../domain/services/project_finance_calculator.dart';

export '../domain/entities/project_settlement_result.dart';

class ProjectSettlementUseCase {
  ProjectSettlementUseCase({
    required ProjectSettlementRepository repository,
    DateTime Function()? now,
    String Function(String projectId, DateTime now)? writeOffIdFactory,
  }) : _repository = repository,
       _now = now ?? DateTime.now,
       _writeOffIdFactory = writeOffIdFactory;

  final ProjectSettlementRepository _repository;
  final DateTime Function() _now;
  final String Function(String projectId, DateTime now)? _writeOffIdFactory;

  Future<ProjectSettlementResult> execute({
    required String projectId,
    required String projectKey,
    required double receivable,
    required double paymentAmount,
    required double writeOffAmount,
    required ProjectWriteOffReason? writeOffReason,
    required int ymd,
    String? note,
  }) async {
    final normalizedProjectId = projectId.trim();
    final normalizedProjectKey = projectKey.trim();
    if (normalizedProjectId.isEmpty) {
      throw StateError('项目缺少稳定 ID');
    }
    if (normalizedProjectKey.isEmpty) {
      throw StateError('项目缺少兼容 key');
    }
    if (_fen(receivable) <= 0) {
      throw StateError('项目总额必须大于 0');
    }
    if (_fen(paymentAmount) < 0) {
      throw ArgumentError.value(paymentAmount, 'paymentAmount', '本次实收不能为负数');
    }
    if (_fen(writeOffAmount) < 0) {
      throw ArgumentError.value(writeOffAmount, 'writeOffAmount', '核销金额不能为负数');
    }

    final normalizedPaymentAmount = _zeroIfTiny(paymentAmount);
    final normalizedWriteOffAmount = _zeroIfTiny(writeOffAmount);
    if (_fen(normalizedWriteOffAmount) > 0 && writeOffReason == null) {
      throw StateError('请选择核销原因');
    }

    final settlementAmount = normalizedPaymentAmount + normalizedWriteOffAmount;
    if (_fen(settlementAmount) <= 0) {
      throw StateError('结清金额必须大于 0');
    }

    final now = _now().toUtc();
    return _repository.settle(
      ProjectSettlementRequest(
        projectId: normalizedProjectId,
        projectKey: normalizedProjectKey,
        receivable: receivable,
        paymentAmount: normalizedPaymentAmount,
        writeOffAmount: normalizedWriteOffAmount,
        writeOffReasonDbValue: writeOffReason?.dbValue,
        ymd: ymd,
        createdAtIso: now.toIso8601String(),
        writeOffDate: _writeOffDateFromYmd(ymd),
        note: _cleanNote(note),
        writeOffId: _fen(normalizedWriteOffAmount) > 0
            ? _writeOffId(normalizedProjectId, now)
            : null,
      ),
    );
  }

  Future<DeleteProjectWriteOffResult> deleteWriteOff({
    required String projectId,
    required String writeOffId,
    required double receivable,
  }) async {
    final normalizedProjectId = projectId.trim();
    final normalizedWriteOffId = writeOffId.trim();
    if (normalizedProjectId.isEmpty) {
      throw StateError('项目缺少稳定 ID');
    }
    if (normalizedWriteOffId.isEmpty) {
      throw StateError('核销记录 ID 不能为空');
    }
    if (_fen(receivable) <= 0) {
      throw StateError('项目总额必须大于 0');
    }

    return _repository.deleteWriteOff(
      DeleteProjectWriteOffRequest(
        projectId: normalizedProjectId,
        writeOffId: normalizedWriteOffId,
        receivable: receivable,
        updatedAtIso: _now().toUtc().toIso8601String(),
      ),
    );
  }

  Future<RevokeProjectSettlementStatusResult> revokeSettlementStatus({
    required String projectId,
  }) async {
    final normalizedProjectId = projectId.trim();
    if (normalizedProjectId.isEmpty) {
      throw StateError('项目缺少稳定 ID');
    }

    return _repository.revokeSettlementStatus(
      RevokeProjectSettlementStatusRequest(
        projectId: normalizedProjectId,
        updatedAtIso: _now().toUtc().toIso8601String(),
      ),
    );
  }

  String _writeOffId(String projectId, DateTime now) {
    final factory = _writeOffIdFactory;
    if (factory != null) return factory(projectId, now);
    return 'writeoff-$projectId-${now.microsecondsSinceEpoch}';
  }

  static int _fen(double yuan) => ProjectFinanceCalculator.yuanToFen(yuan);

  /// 把"四舍五入后不足 1 分"的金额归一为 0（fen 口径），保持原 _zeroIfTiny 语义。
  static double _zeroIfTiny(double value) {
    return _fen(value) == 0 ? 0.0 : value;
  }

  static String? _cleanNote(String? note) {
    final clean = note?.trim();
    if (clean == null || clean.isEmpty) return null;
    return clean;
  }

  static String _writeOffDateFromYmd(int ymd) {
    final year = ymd ~/ 10000;
    final month = (ymd ~/ 100) % 100;
    final day = ymd % 100;
    return '${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';
  }
}
