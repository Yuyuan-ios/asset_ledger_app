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
      if (request.writeOffAmount > projectSettlementEpsilon) {
        final existingWriteOffCount = await _countByProjectId(
          txn,
          table: SqfliteProjectWriteOffRepository.table,
          projectId: request.projectId,
        );
        if (existingWriteOffCount > 0) {
          throw StateError('该项目已存在核销记录，请先撤销后再处理。');
        }
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
  Future<ProjectSettlementResult> settleMerged(
    MergedProjectSettlementRequest request,
  ) async {
    return AppDatabase.inTransaction((txn) async {
      if (request.members.isEmpty) {
        throw StateError('合并项目没有可结清的成员项目');
      }
      if (request.allocations.isEmpty) {
        throw StateError('合并项目没有可结清的成员项目');
      }
      if (request.writeOffAmount <= projectSettlementEpsilon) {
        throw StateError('结清金额必须大于 0');
      }
      final reason = request.writeOffReasonDbValue;
      if (reason == null || reason.trim().isEmpty) {
        throw StateError('请选择核销原因');
      }

      var receivedBefore = 0.0;
      var writeOffBefore = 0.0;
      var allocatedWriteOff = 0.0;
      final memberProjects = <String, Project>{};
      final memberById = {
        for (final member in request.members) member.projectId: member,
      };

      for (final member in request.members) {
        final projectRows = await txn.query(
          SqfliteProjectRepository.table,
          where: 'id = ?',
          whereArgs: [member.projectId],
          limit: 1,
        );
        if (projectRows.isEmpty) {
          throw StateError('成员项目不存在，无法结清');
        }
        final project = Project.fromMap(projectRows.single);
        memberProjects[member.projectId] = project;
        if (project.status == ProjectStatus.settled) {
          throw StateError('合并成员项目已结清，请先处理成员项目。');
        }

        final existingWriteOffCount = await _countByProjectId(
          txn,
          table: SqfliteProjectWriteOffRepository.table,
          projectId: member.projectId,
        );
        if (existingWriteOffCount > 0) {
          throw StateError('合并成员项目已存在核销记录，请先处理成员项目。');
        }

        receivedBefore += await _sumByProjectId(
          txn,
          table: SqfliteAccountPaymentRepository.table,
          projectId: member.projectId,
        );
        writeOffBefore += await _sumByProjectId(
          txn,
          table: SqfliteProjectWriteOffRepository.table,
          projectId: member.projectId,
        );
      }

      for (final allocation in request.allocations) {
        final member = memberById[allocation.projectId];
        final project = memberProjects[allocation.projectId];
        if (member == null || project == null) {
          throw StateError('合并成员项目数据不完整，请刷新后重试。');
        }
        final memberReceivedBefore = await _sumByProjectId(
          txn,
          table: SqfliteAccountPaymentRepository.table,
          projectId: allocation.projectId,
        );
        final memberWriteOffBefore = await _sumByProjectId(
          txn,
          table: SqfliteProjectWriteOffRepository.table,
          projectId: allocation.projectId,
        );
        final memberRemainingBefore = _normalizeRemaining(
          member.receivable - memberReceivedBefore - memberWriteOffBefore,
        );
        if (memberRemainingBefore <= projectSettlementEpsilon) {
          throw StateError('合并成员项目已结清，请先处理成员项目。');
        }
        if (allocation.writeOffAmount >
            memberRemainingBefore + projectSettlementEpsilon) {
          throw StateError(
            '结清金额超出当前待收（待收约 ${FormatUtils.money(memberRemainingBefore)}）',
          );
        }

        await txn.insert(
          SqfliteProjectWriteOffRepository.table,
          ProjectWriteOff(
            id: allocation.writeOffId,
            projectId: allocation.projectId,
            amount: allocation.writeOffAmount,
            reason: reason,
            note: request.note,
            writeOffDate: request.writeOffDate,
            createdAt: request.createdAtIso,
            updatedAt: request.createdAtIso,
          ).toMap(),
        );

        final memberWriteOffAfter =
            memberWriteOffBefore + allocation.writeOffAmount;
        final memberRemainingAfter = _normalizeRemaining(
          member.receivable - memberReceivedBefore - memberWriteOffAfter,
        );
        if (memberRemainingAfter <= projectSettlementEpsilon) {
          await SqfliteProjectRepository.upsertWithExecutor(
            txn,
            project.copyWith(
              status: ProjectStatus.settled,
              settledAt: request.createdAtIso,
              updatedAt: request.createdAtIso,
            ),
          );
        }

        allocatedWriteOff += allocation.writeOffAmount;
      }

      if ((allocatedWriteOff - request.writeOffAmount).abs() >
          projectSettlementEpsilon) {
        throw StateError('合并项目核销分摊失败');
      }

      final remainingBefore = _normalizeRemaining(
        request.receivable - receivedBefore - writeOffBefore,
      );
      final writeOffAfter = writeOffBefore + request.writeOffAmount;
      final remainingAfter = _normalizeRemaining(
        request.receivable - receivedBefore - writeOffAfter,
      );
      if (remainingAfter <= projectSettlementEpsilon) {
        for (final member in request.members) {
          final project = memberProjects[member.projectId];
          if (project == null || project.status == ProjectStatus.settled) {
            continue;
          }
          final memberReceived = await _sumByProjectId(
            txn,
            table: SqfliteAccountPaymentRepository.table,
            projectId: member.projectId,
          );
          final memberWriteOff = await _sumByProjectId(
            txn,
            table: SqfliteProjectWriteOffRepository.table,
            projectId: member.projectId,
          );
          final memberRemaining = _normalizeRemaining(
            member.receivable - memberReceived - memberWriteOff,
          );
          if (memberRemaining <= projectSettlementEpsilon) {
            await SqfliteProjectRepository.upsertWithExecutor(
              txn,
              project.copyWith(
                status: ProjectStatus.settled,
                settledAt: request.createdAtIso,
                updatedAt: request.createdAtIso,
              ),
            );
          }
        }
      }

      return ProjectSettlementResult(
        projectId: request.mergedProjectId,
        receivable: request.receivable,
        receivedBefore: receivedBefore,
        writeOffBefore: writeOffBefore,
        remainingBefore: remainingBefore,
        paymentAmount: 0,
        writeOffAmount: request.writeOffAmount,
        receivedAfter: receivedBefore,
        writeOffAfter: writeOffAfter,
        remainingAfter: remainingAfter,
        settled: remainingAfter <= projectSettlementEpsilon,
        writeOffId: request.allocations.length == 1
            ? request.allocations.single.writeOffId
            : null,
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
      final writeOffCount = await _countByProjectId(
        txn,
        table: SqfliteProjectWriteOffRepository.table,
        projectId: request.projectId,
      );
      if (writeOffCount > 1) {
        throw StateError('该项目核销记录异常，请先检查核销记录。');
      }

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

  @override
  Future<DeleteProjectWriteOffResult> deleteMergedWriteOffs(
    DeleteMergedProjectWriteOffsRequest request,
  ) async {
    return AppDatabase.inTransaction((txn) async {
      final memberByProjectId = {
        for (final member in request.members) member.projectId: member,
      };
      if (memberByProjectId.isEmpty || request.writeOffIds.isEmpty) {
        throw StateError('合并项目核销记录异常，请先检查核销记录。');
      }
      final allowedWriteOffIds = request.writeOffIds
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toSet();
      if (allowedWriteOffIds.isEmpty) {
        throw StateError('合并项目核销记录异常，请先检查核销记录。');
      }

      final placeholders = List.filled(
        allowedWriteOffIds.length,
        '?',
      ).join(',');
      final writeOffRows = await txn.query(
        SqfliteProjectWriteOffRepository.table,
        where: 'id IN ($placeholders)',
        whereArgs: allowedWriteOffIds.toList(growable: false),
      );
      if (writeOffRows.length != allowedWriteOffIds.length) {
        throw StateError('核销记录不存在或已被删除');
      }

      final mergeWriteOffPrefix = 'writeoff-merge-${request.mergeGroupId}-';
      final writeOffs = writeOffRows.map(ProjectWriteOff.fromMap).toList();
      for (final writeOff in writeOffs) {
        final projectId = writeOff.projectId.trim();
        if (!memberByProjectId.containsKey(projectId) ||
            !writeOff.id.startsWith(mergeWriteOffPrefix)) {
          throw StateError('合并项目核销记录复杂，请进入成员项目分别处理。');
        }
        final memberWriteOffCount = await _countByProjectId(
          txn,
          table: SqfliteProjectWriteOffRepository.table,
          projectId: projectId,
        );
        if (memberWriteOffCount != 1) {
          throw StateError('合并项目核销记录复杂，请进入成员项目分别处理。');
        }
      }

      var deletedAmount = 0.0;
      var received = 0.0;
      var writeOffBefore = 0.0;
      final affectedProjectIds = <String>{};

      for (final member in request.members) {
        final projectId = member.projectId.trim();
        final projectRows = await txn.query(
          SqfliteProjectRepository.table,
          where: 'id = ?',
          whereArgs: [projectId],
          limit: 1,
        );
        if (projectRows.isEmpty) {
          throw StateError('成员项目不存在，无法删除核销');
        }
        received += await _sumByProjectId(
          txn,
          table: SqfliteAccountPaymentRepository.table,
          projectId: projectId,
        );
        writeOffBefore += await _sumByProjectId(
          txn,
          table: SqfliteProjectWriteOffRepository.table,
          projectId: projectId,
        );
      }

      for (final writeOff in writeOffs) {
        final deleted = await txn.delete(
          SqfliteProjectWriteOffRepository.table,
          where: 'id = ? AND project_id = ?',
          whereArgs: [writeOff.id, writeOff.projectId],
        );
        if (deleted != 1) {
          throw StateError('核销记录删除失败，请刷新后重试');
        }
        deletedAmount += writeOff.amount;
        affectedProjectIds.add(writeOff.projectId.trim());
      }

      var writeOffAfter = 0.0;
      var restoredActive = false;
      for (final member in request.members) {
        final projectId = member.projectId.trim();
        final projectRows = await txn.query(
          SqfliteProjectRepository.table,
          where: 'id = ?',
          whereArgs: [projectId],
          limit: 1,
        );
        final project = Project.fromMap(projectRows.single);
        final memberWriteOffAfter = await _sumByProjectId(
          txn,
          table: SqfliteProjectWriteOffRepository.table,
          projectId: projectId,
        );
        writeOffAfter += memberWriteOffAfter;
        if (!affectedProjectIds.contains(projectId)) continue;
        final memberReceived = await _sumByProjectId(
          txn,
          table: SqfliteAccountPaymentRepository.table,
          projectId: projectId,
        );
        final remainingAfter = _normalizeRemaining(
          member.receivable - memberReceived - memberWriteOffAfter,
        );
        if (remainingAfter > projectSettlementEpsilon &&
            project.status == ProjectStatus.settled) {
          await SqfliteProjectRepository.upsertWithExecutor(
            txn,
            project.copyWith(
              status: ProjectStatus.active,
              settledAt: null,
              settledSnapshot: null,
              updatedAt: request.updatedAtIso,
            ),
          );
          restoredActive = true;
        }
      }

      final remainingAfter = _normalizeRemaining(
        request.receivable - received - writeOffAfter,
      );
      return DeleteProjectWriteOffResult(
        projectId: request.mergedProjectId,
        writeOffId: allowedWriteOffIds.join(','),
        deletedAmount: deletedAmount,
        receivable: request.receivable,
        received: received,
        writeOffBefore: writeOffBefore,
        writeOffAfter: writeOffAfter,
        remainingAfter: remainingAfter,
        restoredActive: restoredActive,
      );
    });
  }

  @override
  Future<RevokeProjectSettlementStatusResult> revokeSettlementStatus(
    RevokeProjectSettlementStatusRequest request,
  ) async {
    return AppDatabase.inTransaction((txn) async {
      final projectRows = await txn.query(
        SqfliteProjectRepository.table,
        where: 'id = ?',
        whereArgs: [request.projectId],
        limit: 1,
      );
      if (projectRows.isEmpty) {
        throw StateError('项目不存在，无法撤销结清状态');
      }
      final project = Project.fromMap(projectRows.single);
      final writeOffCount = await _countByProjectId(
        txn,
        table: SqfliteProjectWriteOffRepository.table,
        projectId: request.projectId,
      );
      if (writeOffCount > 0) {
        throw StateError('该项目存在核销记录，请先撤销核销后再处理。');
      }

      final shouldRestoreActive = project.status == ProjectStatus.settled;
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

      return RevokeProjectSettlementStatusResult(
        projectId: request.projectId,
        restoredActive: shouldRestoreActive,
      );
    });
  }

  @override
  Future<RevokeProjectSettlementStatusResult> revokeMergedSettlementStatus(
    RevokeMergedProjectSettlementStatusRequest request,
  ) async {
    return AppDatabase.inTransaction((txn) async {
      var restoredActive = false;
      for (final member in request.members) {
        final projectRows = await txn.query(
          SqfliteProjectRepository.table,
          where: 'id = ?',
          whereArgs: [member.projectId],
          limit: 1,
        );
        if (projectRows.isEmpty) {
          throw StateError('成员项目不存在，无法撤销结清状态');
        }
        final writeOffCount = await _countByProjectId(
          txn,
          table: SqfliteProjectWriteOffRepository.table,
          projectId: member.projectId,
        );
        if (writeOffCount > 0) {
          throw StateError('该项目存在核销记录，请先撤销核销后再处理。');
        }
        final project = Project.fromMap(projectRows.single);
        if (project.status == ProjectStatus.settled) {
          await SqfliteProjectRepository.upsertWithExecutor(
            txn,
            project.copyWith(
              status: ProjectStatus.active,
              settledAt: null,
              settledSnapshot: null,
              updatedAt: request.updatedAtIso,
            ),
          );
          restoredActive = true;
        }
      }

      return RevokeProjectSettlementStatusResult(
        projectId: request.mergedProjectId,
        restoredActive: restoredActive,
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

  Future<int> _countByProjectId(
    DatabaseExecutor executor, {
    required String table,
    required String projectId,
  }) async {
    final rows = await executor.rawQuery(
      'SELECT COUNT(*) AS count FROM $table WHERE project_id = ?',
      [projectId],
    );
    return (rows.single['count'] as num?)?.toInt() ?? 0;
  }

  static double _normalizeRemaining(double value) {
    return value.abs() <= projectSettlementEpsilon ? 0.0 : value;
  }
}
