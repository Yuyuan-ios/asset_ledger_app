import 'package:sqflite/sqflite.dart';

import '../../../data/db/database.dart';
import '../../../data/models/account_payment.dart';
import '../../../data/models/project.dart';
import '../../../data/models/project_write_off.dart';
import '../../../data/repositories/account_payment_repository.dart';
import '../../../data/repositories/project_repository.dart';
import '../../../data/repositories/project_write_off_repository.dart';
import '../../../features/account/domain/entities/project_settlement_result.dart';
import '../../../features/account/domain/repositories/project_settlement_repository.dart';
import '../../../core/utils/format_utils.dart';

class LocalProjectSettlementRepository implements ProjectSettlementRepository {
  const LocalProjectSettlementRepository();

  @override
  Future<ProjectSettlementResult> settle(
    ProjectSettlementRequest request,
  ) async {
    return AppDatabase.inTransaction((txn) async {
      final projectRows = await txn.query(
        SqfliteProjectRepository.table,
        where: 'id = ?',
        whereArgs: [request.projectId],
        limit: 1,
      );
      if (projectRows.isEmpty) {
        throw StateError('项目不存在，无法结清');
      }
      final project = Project.fromMap(projectRows.single);
      final receivedBefore = await _sumByProjectId(
        txn,
        table: SqfliteAccountPaymentRepository.table,
        projectId: request.projectId,
      );
      final writeOffBefore = await _sumByProjectId(
        txn,
        table: SqfliteProjectWriteOffRepository.table,
        projectId: request.projectId,
      );
      final remainingBefore = _normalizeRemaining(
        request.receivable - receivedBefore - writeOffBefore,
      );

      if (remainingBefore <= projectSettlementEpsilon) {
        throw StateError('项目已结清，不能重复结清');
      }
      if (request.paymentAmount > remainingBefore + projectSettlementEpsilon) {
        throw StateError(
          '本次实收超出当前待收（待收约 ${FormatUtils.money(remainingBefore)}）',
        );
      }
      final settlementAmount = request.paymentAmount + request.writeOffAmount;
      if (settlementAmount > remainingBefore + projectSettlementEpsilon) {
        throw StateError(
          '结清金额超出当前待收（待收约 ${FormatUtils.money(remainingBefore)}）',
        );
      }

      int? paymentId;
      String? writeOffId;
      if (request.paymentAmount > projectSettlementEpsilon) {
        paymentId = await txn.insert(
          SqfliteAccountPaymentRepository.table,
          AccountPayment(
            projectId: request.projectId,
            projectKey: request.projectKey,
            ymd: request.ymd,
            amount: request.paymentAmount,
            note: request.note,
            createdAt: request.createdAtIso,
          ).toMap(),
        );
      }

      if (request.writeOffAmount > projectSettlementEpsilon) {
        final reason = request.writeOffReasonDbValue;
        writeOffId = request.writeOffId;
        if (reason == null || reason.trim().isEmpty || writeOffId == null) {
          throw StateError('核销信息不完整');
        }
        await txn.insert(
          SqfliteProjectWriteOffRepository.table,
          ProjectWriteOff(
            id: writeOffId,
            projectId: request.projectId,
            amount: request.writeOffAmount,
            reason: reason,
            note: request.note,
            writeOffDate: request.writeOffDate,
            createdAt: request.createdAtIso,
            updatedAt: request.createdAtIso,
          ).toMap(),
        );
      }

      final receivedAfter = receivedBefore + request.paymentAmount;
      final writeOffAfter = writeOffBefore + request.writeOffAmount;
      final remainingAfter = _normalizeRemaining(
        request.receivable - receivedAfter - writeOffAfter,
      );
      final settled = remainingAfter <= projectSettlementEpsilon;
      if (settled && project.status != ProjectStatus.settled) {
        await SqfliteProjectRepository.upsertWithExecutor(
          txn,
          project.copyWith(
            status: ProjectStatus.settled,
            settledAt: request.createdAtIso,
            updatedAt: request.createdAtIso,
          ),
        );
      }

      return ProjectSettlementResult(
        projectId: request.projectId,
        receivable: request.receivable,
        receivedBefore: receivedBefore,
        writeOffBefore: writeOffBefore,
        remainingBefore: remainingBefore,
        paymentAmount: request.paymentAmount,
        writeOffAmount: request.writeOffAmount,
        receivedAfter: receivedAfter,
        writeOffAfter: writeOffAfter,
        remainingAfter: remainingAfter,
        settled: settled,
        paymentId: paymentId,
        writeOffId: writeOffId,
      );
    });
  }

  @override
  Future<DeleteProjectWriteOffResult> deleteWriteOff(
    DeleteProjectWriteOffRequest request,
  ) async {
    return AppDatabase.inTransaction((txn) async {
      final projectRows = await txn.query(
        SqfliteProjectRepository.table,
        where: 'id = ?',
        whereArgs: [request.projectId],
        limit: 1,
      );
      if (projectRows.isEmpty) {
        throw StateError('项目不存在，无法删除核销');
      }
      final project = Project.fromMap(projectRows.single);

      final writeOffRows = await txn.query(
        SqfliteProjectWriteOffRepository.table,
        where: 'id = ? AND project_id = ?',
        whereArgs: [request.writeOffId, request.projectId],
        limit: 1,
      );
      if (writeOffRows.isEmpty) {
        throw StateError('核销记录不存在或已被删除');
      }
      final writeOff = ProjectWriteOff.fromMap(writeOffRows.single);

      final received = await _sumByProjectId(
        txn,
        table: SqfliteAccountPaymentRepository.table,
        projectId: request.projectId,
      );
      final writeOffBefore = await _sumByProjectId(
        txn,
        table: SqfliteProjectWriteOffRepository.table,
        projectId: request.projectId,
      );

      final deleted = await txn.delete(
        SqfliteProjectWriteOffRepository.table,
        where: 'id = ? AND project_id = ?',
        whereArgs: [request.writeOffId, request.projectId],
      );
      if (deleted != 1) {
        throw StateError('核销记录删除失败，请刷新后重试');
      }

      final writeOffAfter = await _sumByProjectId(
        txn,
        table: SqfliteProjectWriteOffRepository.table,
        projectId: request.projectId,
      );
      final remainingAfter = _normalizeRemaining(
        request.receivable - received - writeOffAfter,
      );
      final shouldRestoreActive =
          remainingAfter > projectSettlementEpsilon &&
          project.status == ProjectStatus.settled;
      if (shouldRestoreActive) {
        await SqfliteProjectRepository.upsertWithExecutor(
          txn,
          project.copyWith(
            status: ProjectStatus.active,
            settledAt: null,
            settledSnapshot: null,
            updatedAt: request.updatedAtIso,
          ),
        );
      }

      return DeleteProjectWriteOffResult(
        projectId: request.projectId,
        writeOffId: request.writeOffId,
        deletedAmount: writeOff.amount,
        receivable: request.receivable,
        received: received,
        writeOffBefore: writeOffBefore,
        writeOffAfter: writeOffAfter,
        remainingAfter: remainingAfter,
        restoredActive: shouldRestoreActive,
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

  static double _normalizeRemaining(double value) {
    return value.abs() <= projectSettlementEpsilon ? 0.0 : value;
  }
}
