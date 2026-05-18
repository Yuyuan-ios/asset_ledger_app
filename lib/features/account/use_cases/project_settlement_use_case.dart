import 'package:sqflite/sqflite.dart';

import '../../../core/utils/format_utils.dart';
import '../../../data/db/database.dart';
import '../../../data/models/account_payment.dart';
import '../../../data/models/project.dart';
import '../../../data/models/project_write_off.dart';
import '../../../data/repositories/account_payment_repository.dart';
import '../../../data/repositories/project_repository.dart';
import '../../../data/repositories/project_write_off_repository.dart';

const double projectSettlementEpsilon = 0.000001;

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
    if (paymentAmount > projectSettlementEpsilon &&
        writeOffAmount > projectSettlementEpsilon) {
      return '已收款 ${FormatUtils.money(paymentAmount)}，核销 ${FormatUtils.money(writeOffAmount)}';
    }
    if (paymentAmount > projectSettlementEpsilon) {
      return settled ? '已结清' : '已收款 ${FormatUtils.money(paymentAmount)}';
    }
    if (writeOffAmount > projectSettlementEpsilon) {
      return settled ? '已结清' : '已核销 ${FormatUtils.money(writeOffAmount)}';
    }
    return settled ? '已结清' : '保存成功';
  }
}

class ProjectSettlementUseCase {
  ProjectSettlementUseCase({
    DateTime Function()? now,
    String Function(String projectId, DateTime now)? writeOffIdFactory,
  }) : _now = now ?? DateTime.now,
       _writeOffIdFactory = writeOffIdFactory;

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
    if (receivable <= projectSettlementEpsilon) {
      throw StateError('项目总额必须大于 0');
    }
    if (paymentAmount < -projectSettlementEpsilon) {
      throw ArgumentError.value(paymentAmount, 'paymentAmount', '本次实收不能为负数');
    }
    if (writeOffAmount < -projectSettlementEpsilon) {
      throw ArgumentError.value(writeOffAmount, 'writeOffAmount', '核销金额不能为负数');
    }

    final normalizedPaymentAmount = _zeroIfTiny(paymentAmount);
    final normalizedWriteOffAmount = _zeroIfTiny(writeOffAmount);
    if (normalizedWriteOffAmount > projectSettlementEpsilon &&
        writeOffReason == null) {
      throw StateError('请选择核销原因');
    }

    final settlementAmount = normalizedPaymentAmount + normalizedWriteOffAmount;
    if (settlementAmount <= projectSettlementEpsilon) {
      throw StateError('结清金额必须大于 0');
    }

    final cleanNote = _cleanNote(note);
    final now = _now().toUtc();
    final nowIso = now.toIso8601String();
    final writeOffDate = _writeOffDateFromYmd(ymd);

    return AppDatabase.inTransaction((txn) async {
      final projectRows = await txn.query(
        SqfliteProjectRepository.table,
        where: 'id = ?',
        whereArgs: [normalizedProjectId],
        limit: 1,
      );
      if (projectRows.isEmpty) {
        throw StateError('项目不存在，无法结清');
      }
      final project = Project.fromMap(projectRows.single);
      final receivedBefore = await _sumByProjectId(
        txn,
        table: SqfliteAccountPaymentRepository.table,
        projectId: normalizedProjectId,
      );
      final writeOffBefore = await _sumByProjectId(
        txn,
        table: SqfliteProjectWriteOffRepository.table,
        projectId: normalizedProjectId,
      );
      final remainingBefore = _normalizeRemaining(
        receivable - receivedBefore - writeOffBefore,
      );

      if (remainingBefore <= projectSettlementEpsilon) {
        throw StateError('项目已结清，不能重复结清');
      }
      if (normalizedPaymentAmount >
          remainingBefore + projectSettlementEpsilon) {
        throw StateError(
          '本次实收超出当前待收（待收约 ${FormatUtils.money(remainingBefore)}）',
        );
      }
      if (settlementAmount > remainingBefore + projectSettlementEpsilon) {
        throw StateError(
          '结清金额超出当前待收（待收约 ${FormatUtils.money(remainingBefore)}）',
        );
      }

      int? paymentId;
      String? writeOffId;
      if (normalizedPaymentAmount > projectSettlementEpsilon) {
        paymentId = await txn.insert(
          SqfliteAccountPaymentRepository.table,
          AccountPayment(
            projectId: normalizedProjectId,
            projectKey: normalizedProjectKey,
            ymd: ymd,
            amount: normalizedPaymentAmount,
            note: cleanNote,
            createdAt: nowIso,
          ).toMap(),
        );
      }

      if (normalizedWriteOffAmount > projectSettlementEpsilon) {
        writeOffId = _writeOffId(normalizedProjectId, now);
        await txn.insert(
          SqfliteProjectWriteOffRepository.table,
          ProjectWriteOff(
            id: writeOffId,
            projectId: normalizedProjectId,
            amount: normalizedWriteOffAmount,
            reason: writeOffReason!.dbValue,
            note: cleanNote,
            writeOffDate: writeOffDate,
            createdAt: nowIso,
            updatedAt: nowIso,
          ).toMap(),
        );
      }

      final receivedAfter = receivedBefore + normalizedPaymentAmount;
      final writeOffAfter = writeOffBefore + normalizedWriteOffAmount;
      final remainingAfter = _normalizeRemaining(
        receivable - receivedAfter - writeOffAfter,
      );
      final settled = remainingAfter <= projectSettlementEpsilon;
      if (settled && project.status != ProjectStatus.settled) {
        await SqfliteProjectRepository.upsertWithExecutor(
          txn,
          project.copyWith(
            status: ProjectStatus.settled,
            settledAt: nowIso,
            updatedAt: nowIso,
          ),
        );
      }

      return ProjectSettlementResult(
        projectId: normalizedProjectId,
        receivable: receivable,
        receivedBefore: receivedBefore,
        writeOffBefore: writeOffBefore,
        remainingBefore: remainingBefore,
        paymentAmount: normalizedPaymentAmount,
        writeOffAmount: normalizedWriteOffAmount,
        receivedAfter: receivedAfter,
        writeOffAfter: writeOffAfter,
        remainingAfter: remainingAfter,
        settled: settled,
        paymentId: paymentId,
        writeOffId: writeOffId,
      );
    });
  }

  Future<double> _sumByProjectId(
    DatabaseExecutor executor, {
    required String table,
    required String projectId,
  }) async {
    final rows = await executor.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM $table WHERE project_id = ?',
      [projectId],
    );
    return (rows.single['total'] as num?)?.toDouble() ?? 0.0;
  }

  String _writeOffId(String projectId, DateTime now) {
    final factory = _writeOffIdFactory;
    if (factory != null) return factory(projectId, now);
    return 'writeoff-$projectId-${now.microsecondsSinceEpoch}';
  }

  static double _zeroIfTiny(double value) {
    return value.abs() <= projectSettlementEpsilon ? 0.0 : value;
  }

  static double _normalizeRemaining(double value) {
    return value.abs() <= projectSettlementEpsilon ? 0.0 : value;
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
