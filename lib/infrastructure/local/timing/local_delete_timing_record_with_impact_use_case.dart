import 'package:sqflite/sqflite.dart';

import '../../../core/operations/operation_access_control.dart';
import '../../../data/db/database.dart';
import '../../../data/models/project.dart';
import '../../../data/models/timing_record.dart';
import '../../../data/repositories/account_payment_repository.dart';
import '../../../data/repositories/account_project_merge_repository.dart';
import '../../../data/repositories/device_repository.dart';
import '../../../data/repositories/external_work_record_repository.dart';
import '../../../data/repositories/fuel_repository.dart';
import '../../../data/repositories/maintenance_repository.dart';
import '../../../data/repositories/project_repository.dart';
import '../../../data/repositories/project_write_off_repository.dart';
import '../../../data/repositories/timing_repository.dart';
import '../../../features/timing/use_cases/delete_timing_record_with_impact_use_case.dart';
import '../../sync/sync_actor.dart';
import '../../sync/sync_repositories.dart';
import '../../sync/sync_transaction_group.dart';
import '../account/project_sync_enqueuer.dart';
import '../account/project_write_off_sync_enqueuer.dart';
import '../fuel/fuel_log_sync_enqueuer.dart';
import '../fuel/local_fuel_log_write_use_case.dart';
import '../maintenance/local_maintenance_record_write_use_case.dart';
import '../maintenance/maintenance_record_sync_enqueuer.dart';
import 'external_work_sync_enqueuer.dart';
import 'timing_record_sync_enqueuer.dart';

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
    required SqfliteDeviceRepository deviceRepository,
    required SqfliteExternalWorkRecordRepository externalWorkRecordRepository,
    required SqfliteFuelRepository fuelRepository,
    required SqfliteMaintenanceRepository maintenanceRepository,
    required SqfliteProjectWriteOffRepository writeOffRepository,
    required SqfliteProjectRepository projectRepository,
    SyncOutboxRepository? syncOutboxRepository,
    EntitySyncMetaRepository? entitySyncMetaRepository,
    ProjectWriteOffSyncEnqueuer? projectWriteOffSyncEnqueuer,
    ProjectSyncEnqueuer? projectSyncEnqueuer,
    ExternalWorkSyncEnqueuer? externalWorkSyncEnqueuer,
    TimingRecordSyncEnqueuer? timingRecordSyncEnqueuer,
    FuelLogSyncEnqueuer? fuelLogSyncEnqueuer,
    MaintenanceRecordSyncEnqueuer? maintenanceRecordSyncEnqueuer,
    SyncActorProvider? actorProvider,
    DateTime Function()? now,
  }) : _timingRepository = timingRepository,
       _paymentRepository = paymentRepository,
       _mergeRepository = mergeRepository,
       _deviceRepository = deviceRepository,
       _externalWorkRecordRepository = externalWorkRecordRepository,
       _writeOffRepository = writeOffRepository,
       _projectRepository = projectRepository,
       _projectWriteOffSyncEnqueuer =
           projectWriteOffSyncEnqueuer ??
           ProjectWriteOffSyncEnqueuer(
             syncOutboxRepository: syncOutboxRepository,
             entitySyncMetaRepository: entitySyncMetaRepository,
           ),
       _projectSyncEnqueuer =
           projectSyncEnqueuer ??
           ProjectSyncEnqueuer(
             syncOutboxRepository: syncOutboxRepository,
             entitySyncMetaRepository: entitySyncMetaRepository,
           ),
       _externalWorkSyncEnqueuer =
           externalWorkSyncEnqueuer ??
           ExternalWorkSyncEnqueuer(
             syncOutboxRepository: syncOutboxRepository,
             entitySyncMetaRepository: entitySyncMetaRepository,
           ),
       _timingRecordSyncEnqueuer =
           timingRecordSyncEnqueuer ??
           TimingRecordSyncEnqueuer(
             syncOutboxRepository: syncOutboxRepository,
             entitySyncMetaRepository: entitySyncMetaRepository,
           ),
       _fuelLogWriteUseCase = LocalFuelLogWriteUseCase(
         fuelRepository: fuelRepository,
         syncOutboxRepository: syncOutboxRepository,
         entitySyncMetaRepository: entitySyncMetaRepository,
         syncEnqueuer: fuelLogSyncEnqueuer,
         actorProvider: actorProvider,
       ),
       _maintenanceRecordWriteUseCase = LocalMaintenanceRecordWriteUseCase(
         maintenanceRepository: maintenanceRepository,
         syncOutboxRepository: syncOutboxRepository,
         entitySyncMetaRepository: entitySyncMetaRepository,
         syncEnqueuer: maintenanceRecordSyncEnqueuer,
         actorProvider: actorProvider,
       ),
       _actorProvider = actorProvider,
       _now = now ?? DateTime.now;

  final SqfliteTimingRepository _timingRepository;
  final SqfliteAccountPaymentRepository _paymentRepository;
  final SqfliteAccountProjectMergeRepository _mergeRepository;
  final SqfliteDeviceRepository _deviceRepository;
  final SqfliteExternalWorkRecordRepository _externalWorkRecordRepository;
  final SqfliteProjectWriteOffRepository _writeOffRepository;
  final SqfliteProjectRepository _projectRepository;
  final ProjectWriteOffSyncEnqueuer _projectWriteOffSyncEnqueuer;
  final ProjectSyncEnqueuer _projectSyncEnqueuer;
  final ExternalWorkSyncEnqueuer _externalWorkSyncEnqueuer;
  final TimingRecordSyncEnqueuer _timingRecordSyncEnqueuer;
  final LocalFuelLogWriteUseCase _fuelLogWriteUseCase;
  final LocalMaintenanceRecordWriteUseCase _maintenanceRecordWriteUseCase;
  final SyncActorProvider? _actorProvider;
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
      willDissolveMergeGroup = (activeMembers - 1) < _minActiveMergeMembers;
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
      // R5.22-A：删除计时是一个跨聚合的同事务 cluster（ProjectWriteOff delete +
      // Project status update + ExternalWork unlink update + TimingRecord
      // delete, inactive-device fuel/maintenance deletes）。所有 outbox 共享一个
      // group id，local_sequence 按发生顺序递增。
      final group = SyncTransactionGroup.create();
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

      final paymentCount = await _paymentRepository
          .countByProjectIdWithExecutor(txn, projectId);
      // 最后一条 + 有收款：阻止删除，整笔事务不产生任何写入。
      if (isLast && paymentCount > 0) {
        throw const TimingDeleteBlockedByPaymentsException();
      }

      // 2) 删除计时记录本身。
      await _timingRepository.deleteByIdWithExecutor(txn, recordId);
      final actor = _actorProvider?.call();
      final inactiveDeviceCleanup =
          await _cleanupInactiveDeviceRegistrationDependents(
            txn,
            deviceId: record.deviceId,
            group: group,
            actor: actor,
          );

      // 3) 撤销结清：删除核销 + 已结清恢复为进行中（收款不动）。
      final writeOffSnapshots = await _writeOffRepository
          .listByProjectIdWithExecutor(txn, projectId);
      var deletedWriteOffs = 0;
      for (final writeOff in writeOffSnapshots) {
        final deleted = await _writeOffRepository.deleteByIdWithExecutor(
          txn,
          writeOff.id,
        );
        if (deleted > 0) {
          deletedWriteOffs += deleted;
          await _projectWriteOffSyncEnqueuer.enqueueDelete(
            txn,
            writeOff,
            transactionGroupId: group.id,
            localSequence: group.nextSequence(),
            actor: actor,
          );
        }
      }
      final restoredActive = await _projectRepository.restoreActiveWithExecutor(
        txn,
        projectId: projectId,
        updatedAt: timestamp,
      );
      if (restoredActive) {
        await _enqueueProjectUpdate(
          txn,
          projectId: projectId,
          group: group,
          actor: actor,
        );
      }
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

          // 移除当前成员后，重新评估同组剩余成员：
          // - 无任何痕迹的历史孤儿成员，在本事务内一并停用；
          // - 以「有效成员」数量（而非 raw active 数量）决定是否解散整组。
          final remaining = await _mergeRepository
              .listActiveMembersByGroupIdWithExecutor(txn, member.groupId);
          var effectiveMembers = 0;
          for (final remainingMember in remaining) {
            final remainingProjectId = remainingMember.effectiveProjectId;
            if (await _hasEffectiveTrace(txn, remainingProjectId)) {
              effectiveMembers += 1;
            } else {
              await _mergeRepository.deactivateMemberByProjectIdWithExecutor(
                txn,
                remainingProjectId,
              );
            }
          }
          if (effectiveMembers < _minActiveMergeMembers) {
            await _mergeRepository.dissolveGroupWithExecutor(
              txn,
              groupId: member.groupId,
              dissolvedAt: timestamp,
            );
            mergeGroupDissolved = true;
          }
        }

        final externalWorkSnapshots = await _externalWorkRecordRepository
            .listByLinkedProjectIdWithExecutor(txn, projectId);
        final unlinked = await _externalWorkRecordRepository
            .unlinkByProjectIdWithExecutor(
              txn,
              projectId: projectId,
              updatedAt: timestamp,
            );
        if (unlinked > 0) {
          for (final snapshot in externalWorkSnapshots) {
            final updated = await _externalWorkRecordRepository
                .findByIdWithExecutor(txn, snapshot.id);
            if (updated == null) {
              throw StateError(
                'ExternalWork sync enqueue requires final unlink snapshot',
              );
            }
            await _externalWorkSyncEnqueuer.enqueueUpdate(
              txn,
              record: updated,
              transactionGroupId: group.id,
              localSequence: group.nextSequence(),
              actor: actor,
            );
          }
        }
        externalWorkUnlinked = unlinked > 0;
      }

      // 5) 删除成功 + 影响处理完成后，在同一事务内入队 delete outbox。
      //    任一写入失败 → 整个删除事务回滚（记录不删、联动清理不生效）。
      await _enqueueSyncForDeletedRecord(
        txn,
        deletedRecord: record,
        group: group,
        actor: actor,
      );

      return TimingRecordDeleteOutcome(
        settlementRevoked: settlementRevoked,
        mergeMemberRemoved: mergeMemberRemoved,
        mergeGroupDissolved: mergeGroupDissolved,
        externalWorkUnlinked: externalWorkUnlinked,
        clearedInactiveDeviceFuelRecords: inactiveDeviceCleanup.fuelRecordCount,
        clearedInactiveDeviceMaintenanceRecords:
            inactiveDeviceCleanup.maintenanceRecordCount,
      );
    });
  }

  Future<_InactiveDeviceCleanupResult>
  _cleanupInactiveDeviceRegistrationDependents(
    DatabaseExecutor txn, {
    required int deviceId,
    SyncTransactionGroup? group,
    ActorContext? actor,
  }) async {
    final remainingTimingCount = await _timingRepository
        .countByDeviceIdWithExecutor(txn, deviceId);
    if (remainingTimingCount > 0) {
      return _InactiveDeviceCleanupResult.none;
    }

    final device = await _deviceRepository.findByIdWithExecutor(txn, deviceId);
    if (device == null || device.isActive) {
      return _InactiveDeviceCleanupResult.none;
    }

    final deletedFuel = await _fuelLogWriteUseCase.deleteByDeviceIdWithExecutor(
      txn,
      deviceId,
      group: group,
      actor: actor,
    );
    final deletedMaintenance = await _maintenanceRecordWriteUseCase
        .deleteByDeviceIdWithExecutor(
          txn,
          deviceId,
          group: group,
          actor: actor,
        );
    return _InactiveDeviceCleanupResult(
      fuelRecordCount: deletedFuel,
      maintenanceRecordCount: deletedMaintenance,
    );
  }

  Future<void> _enqueueProjectUpdate(
    DatabaseExecutor txn, {
    required String projectId,
    SyncTransactionGroup? group,
    ActorContext? actor,
  }) async {
    final project = await _projectRepository.findByIdWithExecutor(
      txn,
      projectId,
    );
    if (project == null) {
      throw StateError('Project sync enqueue requires project snapshot');
    }
    await _projectSyncEnqueuer.enqueueUpdate(
      txn,
      project: project,
      transactionGroupId: group?.id,
      localSequence: group?.nextSequence(),
      actor: actor,
    );
  }

  /// 删除成功后在同一事务内入队 sync_outbox + entity_sync_meta。
  ///
  /// 与 [LocalSaveTimingRecordWithImpactUseCase] 的 create/update 入队同构：
  /// - sync_outbox：operation = delete，status = pending，payload 携带被删除记录的
  ///   完整快照（含 id / project_id / device_id / start_date 等未来同步删除所需字段）。
  /// - entity_sync_meta：sync_status = pendingDelete，payload_hash 与 outbox 同源。
  ///
  /// id 缺失直接抛错（不写半条）；写失败由外层事务整体回滚。
  Future<void> _enqueueSyncForDeletedRecord(
    DatabaseExecutor txn, {
    required TimingRecord deletedRecord,
    SyncTransactionGroup? group,
    ActorContext? actor,
  }) async {
    final id = deletedRecord.id;
    if (id == null) {
      throw StateError('sync_outbox 入队需要被删除 timing_record 的 id');
    }
    await _timingRecordSyncEnqueuer.enqueueDelete(
      txn,
      record: deletedRecord,
      transactionGroupId: group?.id,
      localSequence: group?.nextSequence(),
      actor: actor,
    );
  }

  /// 「有效成员」判定：项目仍有任一痕迹（计时 / 收款 / 核销 / 已结清 / 外协关联）
  /// 即视为有效，应保留在合并组内；否则视为无痕迹孤儿成员。
  Future<bool> _hasEffectiveTrace(
    DatabaseExecutor executor,
    String projectId,
  ) async {
    if (await _timingRepository.countByProjectIdWithExecutor(
          executor,
          projectId,
        ) >
        0) {
      return true;
    }
    if (await _paymentRepository.countByProjectIdWithExecutor(
          executor,
          projectId,
        ) >
        0) {
      return true;
    }
    if (await _writeOffRepository.countByProjectIdWithExecutor(
          executor,
          projectId,
        ) >
        0) {
      return true;
    }
    if (await _projectRepository.isSettledWithExecutor(executor, projectId)) {
      return true;
    }
    if (await _externalWorkRecordRepository
            .countLinkedBatchesByProjectIdWithExecutor(executor, projectId) >
        0) {
      return true;
    }
    return false;
  }
}

class _InactiveDeviceCleanupResult {
  const _InactiveDeviceCleanupResult({
    required this.fuelRecordCount,
    required this.maintenanceRecordCount,
  });

  static const none = _InactiveDeviceCleanupResult(
    fuelRecordCount: 0,
    maintenanceRecordCount: 0,
  );

  final int fuelRecordCount;
  final int maintenanceRecordCount;
}
