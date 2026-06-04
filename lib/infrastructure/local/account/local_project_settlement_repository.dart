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
import '../../sync/sync_status.dart';
import 'account_payment_sync_enqueuer.dart';
import 'project_sync_enqueuer.dart';
import 'project_write_off_sync_enqueuer.dart';

class LocalProjectSettlementRepository implements ProjectSettlementRepository {
  const LocalProjectSettlementRepository({
    SqfliteProjectRepository projectRepository =
        const SqfliteProjectRepository(),
    SqfliteProjectWriteOffRepository projectWriteOffRepository =
        const SqfliteProjectWriteOffRepository(),
    AccountPaymentSyncEnqueuer accountPaymentSyncEnqueuer =
        const AccountPaymentSyncEnqueuer(),
    ProjectWriteOffSyncEnqueuer projectWriteOffSyncEnqueuer =
        const ProjectWriteOffSyncEnqueuer(),
    ProjectSyncEnqueuer projectSyncEnqueuer = const ProjectSyncEnqueuer(),
  }) : _projectRepository = projectRepository,
       _projectWriteOffRepository = projectWriteOffRepository,
       _accountPaymentSyncEnqueuer = accountPaymentSyncEnqueuer,
       _projectWriteOffSyncEnqueuer = projectWriteOffSyncEnqueuer,
       _projectSyncEnqueuer = projectSyncEnqueuer;

  final SqfliteProjectRepository _projectRepository;
  final SqfliteProjectWriteOffRepository _projectWriteOffRepository;
  final AccountPaymentSyncEnqueuer _accountPaymentSyncEnqueuer;
  final ProjectWriteOffSyncEnqueuer _projectWriteOffSyncEnqueuer;
  final ProjectSyncEnqueuer _projectSyncEnqueuer;

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
      // 权威单位：fen。所有"是否结清 / 是否超支 / 是否覆盖待收"判断都用整数 fen，
      // 不再走 REAL amount + projectSettlementEpsilon 的浮点路径。
      final receivableFen = _yuanToFen(request.receivable);
      final paymentFen = _yuanToFen(request.paymentAmount);
      final writeOffFen = _yuanToFen(request.writeOffAmount);
      final receivedFenBefore = await _sumFenByProjectId(
        txn,
        table: SqfliteAccountPaymentRepository.table,
        projectId: request.projectId,
      );
      final writeOffFenBefore = await _sumFenByProjectId(
        txn,
        table: SqfliteProjectWriteOffRepository.table,
        projectId: request.projectId,
      );
      final remainingFenBefore =
          receivableFen - receivedFenBefore - writeOffFenBefore;

      if (remainingFenBefore <= 0) {
        throw StateError('项目已结清，不能重复结清');
      }
      if (paymentFen > remainingFenBefore) {
        throw StateError(
          '本次实收超出当前待收（待收约 ${FormatUtils.money(_fenToYuan(remainingFenBefore))}）',
        );
      }
      final settlementFen = paymentFen + writeOffFen;
      if (settlementFen > remainingFenBefore) {
        throw StateError(
          '结清金额超出当前待收（待收约 ${FormatUtils.money(_fenToYuan(remainingFenBefore))}）',
        );
      }
      if (writeOffFen > 0) {
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
      if (paymentFen > 0) {
        final payment = AccountPayment(
          projectId: request.projectId,
          projectKey: request.projectKey,
          ymd: request.ymd,
          amount: request.paymentAmount,
          note: request.note,
          createdAt: request.createdAtIso,
        );
        paymentId = await txn.insert(
          SqfliteAccountPaymentRepository.table,
          payment.toMap(),
        );
        await _accountPaymentSyncEnqueuer.enqueue(
          txn,
          payment: payment.copyWith(id: paymentId),
          operation: 'create',
          status: SyncStatus.pendingUpload,
        );
      }

      if (writeOffFen > 0) {
        final reason = request.writeOffReasonDbValue;
        writeOffId = request.writeOffId;
        if (reason == null || reason.trim().isEmpty || writeOffId == null) {
          throw StateError('核销信息不完整');
        }
        final writeOff = ProjectWriteOff(
          id: writeOffId,
          projectId: request.projectId,
          amount: request.writeOffAmount,
          reason: reason,
          note: request.note,
          writeOffDate: request.writeOffDate,
          createdAt: request.createdAtIso,
          updatedAt: request.createdAtIso,
        );
        await _projectWriteOffRepository.insertWithExecutor(txn, writeOff);
        await _projectWriteOffSyncEnqueuer.enqueueCreate(txn, writeOff);
      }

      final receivedFenAfter = receivedFenBefore + paymentFen;
      final writeOffFenAfter = writeOffFenBefore + writeOffFen;
      final remainingFenAfter =
          receivableFen - receivedFenAfter - writeOffFenAfter;
      final settled = remainingFenAfter <= 0;
      if (settled && project.status != ProjectStatus.settled) {
        await SqfliteProjectRepository.upsertWithExecutor(
          txn,
          project.copyWith(
            status: ProjectStatus.settled,
            settledAt: request.createdAtIso,
            updatedAt: request.createdAtIso,
          ),
        );
        await _enqueueProjectUpdate(txn, request.projectId);
      }

      return ProjectSettlementResult(
        projectId: request.projectId,
        receivable: request.receivable,
        receivedBefore: _fenToYuan(receivedFenBefore),
        writeOffBefore: _fenToYuan(writeOffFenBefore),
        remainingBefore: _fenToYuan(remainingFenBefore),
        paymentAmount: request.paymentAmount,
        writeOffAmount: request.writeOffAmount,
        receivedAfter: _fenToYuan(receivedFenAfter),
        writeOffAfter: _fenToYuan(writeOffFenAfter),
        remainingAfter: _fenToYuan(remainingFenAfter),
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
      if (_yuanToFen(request.writeOffAmount) <= 0) {
        throw StateError('结清金额必须大于 0');
      }
      final reason = request.writeOffReasonDbValue;
      if (reason == null || reason.trim().isEmpty) {
        throw StateError('请选择核销原因');
      }

      // 权威单位：fen。整数 fen 比较无浮点误差，因此结清 / 待收覆盖等判断
      // 全部走 fen，不再依赖 projectSettlementEpsilon。
      final receivableFen = _yuanToFen(request.receivable);
      final writeOffFenTotal = _yuanToFen(request.writeOffAmount);
      var receivedFenBefore = 0;
      var writeOffFenBefore = 0;
      var allocatedWriteOffFen = 0;
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

        receivedFenBefore += await _sumFenByProjectId(
          txn,
          table: SqfliteAccountPaymentRepository.table,
          projectId: member.projectId,
        );
        writeOffFenBefore += await _sumFenByProjectId(
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
        final memberReceivedFenBefore = await _sumFenByProjectId(
          txn,
          table: SqfliteAccountPaymentRepository.table,
          projectId: allocation.projectId,
        );
        final memberWriteOffFenBefore = await _sumFenByProjectId(
          txn,
          table: SqfliteProjectWriteOffRepository.table,
          projectId: allocation.projectId,
        );
        final memberReceivableFen = _yuanToFen(member.receivable);
        final memberRemainingFenBefore =
            memberReceivableFen -
            memberReceivedFenBefore -
            memberWriteOffFenBefore;
        if (memberRemainingFenBefore <= 0) {
          throw StateError('合并成员项目已结清，请先处理成员项目。');
        }
        final allocationFen = _yuanToFen(allocation.writeOffAmount);
        if (allocationFen > memberRemainingFenBefore) {
          throw StateError(
            '结清金额超出当前待收（待收约 ${FormatUtils.money(_fenToYuan(memberRemainingFenBefore))}）',
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

        final memberWriteOffFenAfter = memberWriteOffFenBefore + allocationFen;
        final memberRemainingFenAfter =
            memberReceivableFen -
            memberReceivedFenBefore -
            memberWriteOffFenAfter;
        if (memberRemainingFenAfter <= 0) {
          await SqfliteProjectRepository.upsertWithExecutor(
            txn,
            project.copyWith(
              status: ProjectStatus.settled,
              settledAt: request.createdAtIso,
              updatedAt: request.createdAtIso,
            ),
          );
        }

        allocatedWriteOffFen += allocationFen;
      }

      if (allocatedWriteOffFen != writeOffFenTotal) {
        throw StateError('合并项目核销分摊失败');
      }

      final remainingFenBefore =
          receivableFen - receivedFenBefore - writeOffFenBefore;
      final writeOffFenAfter = writeOffFenBefore + writeOffFenTotal;
      final remainingFenAfter =
          receivableFen - receivedFenBefore - writeOffFenAfter;
      if (remainingFenAfter <= 0) {
        for (final member in request.members) {
          final project = memberProjects[member.projectId];
          if (project == null || project.status == ProjectStatus.settled) {
            continue;
          }
          final memberReceivedFen = await _sumFenByProjectId(
            txn,
            table: SqfliteAccountPaymentRepository.table,
            projectId: member.projectId,
          );
          final memberWriteOffFen = await _sumFenByProjectId(
            txn,
            table: SqfliteProjectWriteOffRepository.table,
            projectId: member.projectId,
          );
          final memberRemainingFen =
              _yuanToFen(member.receivable) -
              memberReceivedFen -
              memberWriteOffFen;
          if (memberRemainingFen <= 0) {
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
        receivedBefore: _fenToYuan(receivedFenBefore),
        writeOffBefore: _fenToYuan(writeOffFenBefore),
        remainingBefore: _fenToYuan(remainingFenBefore),
        paymentAmount: 0,
        writeOffAmount: request.writeOffAmount,
        receivedAfter: _fenToYuan(receivedFenBefore),
        writeOffAfter: _fenToYuan(writeOffFenAfter),
        remainingAfter: _fenToYuan(remainingFenAfter),
        settled: remainingFenAfter <= 0,
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
      final writeOff = await _projectWriteOffRepository.findByIdWithExecutor(
        txn,
        request.writeOffId,
      );
      if (writeOff == null || writeOff.projectId != request.projectId) {
        throw StateError('核销记录不存在或已被删除');
      }

      final receivableFen = _yuanToFen(request.receivable);
      final receivedFen = await _sumFenByProjectId(
        txn,
        table: SqfliteAccountPaymentRepository.table,
        projectId: request.projectId,
      );
      final writeOffFenBefore = await _sumFenByProjectId(
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
      await _projectWriteOffSyncEnqueuer.enqueueDelete(txn, writeOff);

      final writeOffFenAfter = await _sumFenByProjectId(
        txn,
        table: SqfliteProjectWriteOffRepository.table,
        projectId: request.projectId,
      );
      final remainingFenAfter = receivableFen - receivedFen - writeOffFenAfter;
      final shouldRestoreActive =
          remainingFenAfter > 0 && project.status == ProjectStatus.settled;
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
        await _enqueueProjectUpdate(txn, request.projectId);
      }

      return DeleteProjectWriteOffResult(
        projectId: request.projectId,
        writeOffId: request.writeOffId,
        deletedAmount: writeOff.amount,
        receivable: request.receivable,
        received: _fenToYuan(receivedFen),
        writeOffBefore: _fenToYuan(writeOffFenBefore),
        writeOffAfter: _fenToYuan(writeOffFenAfter),
        remainingAfter: _fenToYuan(remainingFenAfter),
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
      var receivedFen = 0;
      var writeOffFenBefore = 0;
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
        receivedFen += await _sumFenByProjectId(
          txn,
          table: SqfliteAccountPaymentRepository.table,
          projectId: projectId,
        );
        writeOffFenBefore += await _sumFenByProjectId(
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
        // deletedAmount 仅用于结果对象的展示字段（yuan），逐项使用模型的
        // amount（已通过 fromMap 优先 amount_fen → yuan 还原）累计。
        deletedAmount += writeOff.amount;
        affectedProjectIds.add(writeOff.projectId.trim());
      }

      var writeOffFenAfter = 0;
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
        final memberWriteOffFenAfter = await _sumFenByProjectId(
          txn,
          table: SqfliteProjectWriteOffRepository.table,
          projectId: projectId,
        );
        writeOffFenAfter += memberWriteOffFenAfter;
        if (!affectedProjectIds.contains(projectId)) continue;
        final memberReceivedFen = await _sumFenByProjectId(
          txn,
          table: SqfliteAccountPaymentRepository.table,
          projectId: projectId,
        );
        final memberRemainingFenAfter =
            _yuanToFen(member.receivable) -
            memberReceivedFen -
            memberWriteOffFenAfter;
        if (memberRemainingFenAfter > 0 &&
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

      final remainingFenAfter =
          _yuanToFen(request.receivable) - receivedFen - writeOffFenAfter;
      return DeleteProjectWriteOffResult(
        projectId: request.mergedProjectId,
        writeOffId: allowedWriteOffIds.join(','),
        deletedAmount: deletedAmount,
        receivable: request.receivable,
        received: _fenToYuan(receivedFen),
        writeOffBefore: _fenToYuan(writeOffFenBefore),
        writeOffAfter: _fenToYuan(writeOffFenAfter),
        remainingAfter: _fenToYuan(remainingFenAfter),
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
        await _enqueueProjectUpdate(txn, request.projectId);
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

  /// 权威 fen 汇总：所有结清 / 待收 / 已收 / 核销判断都基于 amount_fen，
  /// REAL amount 列仅用于 legacy / 展示兼容。整数 fen 比较无浮点误差，
  /// 因此不再需要 projectSettlementEpsilon 兜底。
  Future<int> _sumFenByProjectId(
    DatabaseExecutor executor, {
    required String table,
    required String projectId,
  }) async {
    final rows = await executor.rawQuery(
      'SELECT COALESCE(SUM(amount_fen), 0) AS total FROM $table '
      'WHERE project_id = ?',
      [projectId],
    );
    return (rows.single['total'] as num?)?.toInt() ?? 0;
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

  /// yuan → fen 转换：四舍五入到分。仅用于把 ProjectSettlement*Request 中
  /// 的 double 入参转成 fen 与 SUM(amount_fen) 同维度比较；不修改入库金额。
  static int _yuanToFen(double yuan) => (yuan * 100).round();

  /// fen → yuan 转换：用于结果对象（仍以 yuan double 暴露给上层）。
  static double _fenToYuan(int fen) => fen / 100.0;

  Future<void> _enqueueProjectUpdate(
    DatabaseExecutor executor,
    String projectId,
  ) async {
    final snapshot = await _projectRepository.findByIdWithExecutor(
      executor,
      projectId,
    );
    if (snapshot == null) {
      throw StateError('项目不存在，无法写入同步队列');
    }
    await _projectSyncEnqueuer.enqueueUpdate(executor, project: snapshot);
  }
}
