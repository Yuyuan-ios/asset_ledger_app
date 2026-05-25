import '../../../data/db/database.dart';
import '../../../data/models/project.dart';
import '../../../data/repositories/account_payment_repository.dart';
import '../../../data/repositories/account_project_merge_repository.dart';
import '../../../data/repositories/external_work_record_repository.dart';
import '../../../data/repositories/project_repository.dart';
import '../../../data/repositories/project_write_off_repository.dart';
import '../../../data/repositories/timing_repository.dart';
import '../../../features/timing/use_cases/delete_timing_record_with_impact_use_case.dart';

/// 删除计时记录影响分析 + 联动清理的本地实现。
///
/// 联动删除全部在一个 [AppDatabase.inTransaction] 内完成，任一步失败整体回滚，
/// 避免「记录删了但合并/外协/结清未同步」的中间态。
class LocalDeleteTimingRecordWithImpactUseCase
    implements DeleteTimingRecordWithImpactUseCase {
  LocalDeleteTimingRecordWithImpactUseCase({
    required SqfliteTimingRepository timingRepository,
    required SqfliteAccountPaymentRepository paymentRepository,
    required SqfliteAccountProjectMergeRepository mergeRepository,
    required SqfliteExternalWorkRecordRepository externalWorkRecordRepository,
    required SqfliteProjectWriteOffRepository writeOffRepository,
    required SqfliteProjectRepository projectRepository,
    DateTime Function()? now,
  }) : _timingRepository = timingRepository,
       _paymentRepository = paymentRepository,
       _mergeRepository = mergeRepository,
       _externalWorkRecordRepository = externalWorkRecordRepository,
       _writeOffRepository = writeOffRepository,
       _projectRepository = projectRepository,
       _now = now ?? DateTime.now;

  final SqfliteTimingRepository _timingRepository;
  final SqfliteAccountPaymentRepository _paymentRepository;
  final SqfliteAccountProjectMergeRepository _mergeRepository;
  final SqfliteExternalWorkRecordRepository _externalWorkRecordRepository;
  final SqfliteProjectWriteOffRepository _writeOffRepository;
  final SqfliteProjectRepository _projectRepository;
  final DateTime Function() _now;

  static const int _minActiveMergeMembers = 2;

  @override
  Future<TimingRecordDeleteImpact> analyzeImpact(int recordId) async {
    final record = await _timingRepository.findById(recordId);
    if (record == null) {
      throw StateError('计时记录不存在或已被删除');
    }
    final projectId = record.effectiveProjectId;

    final otherCount = await _timingRepository.countByProjectIdExcluding(
      projectId: projectId,
      excludeRecordId: recordId,
    );
    final isLast = otherCount == 0;

    final hasPayments =
        await _paymentRepository.countByProjectId(projectId) > 0;
    final hasWriteOff =
        await _writeOffRepository.countByProjectId(projectId) > 0;
    final project = await _projectRepository.findById(projectId);
    final isSettled = project?.status == ProjectStatus.settled;

    final member = await _mergeRepository.findActiveMemberByProjectId(
      projectId,
    );
    final mergeGroupId = member?.groupId;
    final willRemoveMergeMember = isLast && member != null;
    var willDissolveMergeGroup = false;
    if (willRemoveMergeMember && mergeGroupId != null) {
      final activeMembers = await _mergeRepository.countActiveMembersByGroupId(
        mergeGroupId,
      );
      willDissolveMergeGroup =
          (activeMembers - 1) < _minActiveMergeMembers;
    }

    final linkedBatchCount = await _externalWorkRecordRepository
        .countLinkedBatchesByProjectId(projectId);
    final willUnlinkExternalWork = isLast && linkedBatchCount > 0;

    return TimingRecordDeleteImpact(
      record: record,
      projectId: projectId,
      projectKey: record.legacyProjectKey,
      isLastTimingRecordOfProject: isLast,
      hasPayments: hasPayments,
      hasWriteOff: hasWriteOff,
      isSettled: isSettled,
      mergeGroupId: mergeGroupId,
      willRemoveMergeMember: willRemoveMergeMember,
      willDissolveMergeGroup: willDissolveMergeGroup,
      linkedExternalBatchCount: linkedBatchCount,
      willUnlinkExternalWork: willUnlinkExternalWork,
    );
  }

  @override
  Future<TimingRecordDeleteOutcome> executeDeleteWithImpact(
    int recordId,
  ) async {
    final timestamp = _now().toUtc().toIso8601String();
    return AppDatabase.inTransaction((txn) async {
      // 1) 事务内重新读取记录与权威状态，避免基于过期分析结果误删。
      final record = await _timingRepository.findByIdWithExecutor(
        txn,
        recordId,
      );
      if (record == null) {
        throw StateError('计时记录不存在或已被删除');
      }
      final projectId = record.effectiveProjectId;

      final otherCount = await _timingRepository
          .countByProjectIdExcludingWithExecutor(
            txn,
            projectId: projectId,
            excludeRecordId: recordId,
          );
      final isLast = otherCount == 0;

      final paymentCount = await _paymentRepository.countByProjectIdWithExecutor(
        txn,
        projectId,
      );
      // 最后一条 + 有收款：阻止删除，整笔事务不产生任何写入。
      if (isLast && paymentCount > 0) {
        throw const TimingDeleteBlockedByPaymentsException();
      }

      // 2) 删除计时记录本身。
      await _timingRepository.deleteByIdWithExecutor(txn, recordId);

      // 3) 撤销结清：删除核销 + 已结清恢复为进行中（收款不动）。
      final deletedWriteOffs = await _writeOffRepository
          .deleteByProjectIdWithExecutor(txn, projectId);
      final restoredActive = await _projectRepository.restoreActiveWithExecutor(
        txn,
        projectId: projectId,
        updatedAt: timestamp,
      );
      final settlementRevoked = deletedWriteOffs > 0 || restoredActive;

      var mergeMemberRemoved = false;
      var mergeGroupDissolved = false;
      var externalWorkUnlinked = false;

      // 4) 仅当删除后项目不再有本地计时记录时，才联动解除合并/外协。
      if (isLast) {
        final member = await _mergeRepository
            .findActiveMemberByProjectIdWithExecutor(txn, projectId);
        if (member != null) {
          final removed = await _mergeRepository
              .deactivateMemberByProjectIdWithExecutor(txn, projectId);
          mergeMemberRemoved = removed > 0;
          final remaining = await _mergeRepository
              .countActiveMembersByGroupIdWithExecutor(txn, member.groupId);
          if (remaining < _minActiveMergeMembers) {
            await _mergeRepository.dissolveGroupWithExecutor(
              txn,
              groupId: member.groupId,
              dissolvedAt: timestamp,
            );
            mergeGroupDissolved = true;
          }
        }

        final unlinked = await _externalWorkRecordRepository
            .unlinkByProjectIdWithExecutor(
              txn,
              projectId: projectId,
              updatedAt: timestamp,
            );
        externalWorkUnlinked = unlinked > 0;
      }

      return TimingRecordDeleteOutcome(
        settlementRevoked: settlementRevoked,
        mergeMemberRemoved: mergeMemberRemoved,
        mergeGroupDissolved: mergeGroupDissolved,
        externalWorkUnlinked: externalWorkUnlinked,
      );
    });
  }
}
