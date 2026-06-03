import 'package:sqflite/sqflite.dart';

import '../../../data/db/database.dart';
import '../../../data/models/device.dart';
import '../../../data/models/project_device_rate.dart';
import '../../../data/models/timing_calculation_history.dart';
import '../../../data/models/timing_record.dart';
import '../../../data/repositories/account_project_merge_repository.dart';
import '../../../data/repositories/device_repository.dart';
import '../../../data/repositories/project_rate_repository.dart';
import '../../../data/repositories/timing_calculation_history_repository.dart';
import '../../../data/repositories/timing_repository.dart';
import '../../../data/services/account_service.dart';
import '../../../data/services/project_resolver.dart';
import '../../../features/account/domain/services/project_finance_calculator.dart';
import '../../../features/timing/use_cases/save_timing_record_with_impact_use_case.dart';
import '../../sync/entity_sync_meta.dart';
import '../../sync/sync_repositories.dart';
import '../../sync/sync_status.dart';
import '../account/project_settlement_impact_service.dart';

/// [SaveTimingRecordWithImpactUseCase] 的本地实现。
///
/// 关键不变量（business_rules_v1.md §6 / §7）：
/// - 保存计时 + 解除合并 + 撤销结清 在 **同一个 sqflite 事务** 内完成；
///   任一步失败整体回滚，不会留下"已保存但未解除合并"的中间态。
/// - 影响判断走整数 fen（[ProjectSettlementImpactService]）；不读 amount REAL；
///   不依赖 projectSettlementEpsilon。
/// - 撤销结清 **不删除** payments / write_offs / timing_records；只把
///   projects.status 从 settled 还原为 active。
///
/// 与现存 [LocalDeleteTimingRecordWithImpactUseCase] 的关系：
/// 删除计时 / 修改计时 的产品策略并不一致（删除计时会无条件清核销，
/// 修改计时仅在 fen 显示不再覆盖时撤销结清）。本 use case 只服务修改计时
/// 场景；删除计时路径保持原状，等后续阶段产品决策再统一。
class LocalSaveTimingRecordWithImpactUseCase
    implements SaveTimingRecordWithImpactUseCase {
  LocalSaveTimingRecordWithImpactUseCase({
    required SqfliteTimingRepository timingRepository,
    required SqfliteTimingCalculationHistoryRepository
    timingCalculationHistoryRepository,
    required SqfliteAccountProjectMergeRepository mergeRepository,
    required DeviceRepository deviceRepository,
    required ProjectRateRepository projectRateRepository,
    required ProjectResolver projectResolver,
    required ProjectSettlementImpactService impactService,
    SyncOutboxRepository? syncOutboxRepository,
    EntitySyncMetaRepository? entitySyncMetaRepository,
    DateTime Function()? now,
  }) : _timingRepository = timingRepository,
       _timingCalculationHistoryRepository = timingCalculationHistoryRepository,
       _mergeRepository = mergeRepository,
       _deviceRepository = deviceRepository,
       _projectRateRepository = projectRateRepository,
       _projectResolver = projectResolver,
       _impactService = impactService,
       _syncOutboxRepository =
           syncOutboxRepository ?? const LocalSyncOutboxRepository(),
       _entitySyncMetaRepository =
           entitySyncMetaRepository ?? const LocalEntitySyncMetaRepository(),
       _now = now ?? DateTime.now;

  final SqfliteTimingRepository _timingRepository;
  final SqfliteTimingCalculationHistoryRepository
  _timingCalculationHistoryRepository;
  final SqfliteAccountProjectMergeRepository _mergeRepository;
  final DeviceRepository _deviceRepository;
  final ProjectRateRepository _projectRateRepository;
  final ProjectResolver _projectResolver;
  final ProjectSettlementImpactService _impactService;
  final SyncOutboxRepository _syncOutboxRepository;
  final EntitySyncMetaRepository _entitySyncMetaRepository;
  final DateTime Function() _now;

  static const String _timingRecordEntityType = 'timing_record';
  static const String _ownerAppSource = 'owner_app';

  @override
  Future<SaveTimingRecordPreparation> prepareForSave({
    required TimingRecord? editing,
    required TimingRecord record,
  }) async {
    final devices = await _deviceRepository.listAll();
    final rates = await _projectRateRepository.listAll();
    final timestamp = _now().toUtc().toIso8601String();

    return SaveTimingRecordPreparation(
      recordToSave: _prepareRecordForPreview(editing: editing, record: record),
      devices: devices,
      rates: rates,
      timestampIso: timestamp,
    );
  }

  @override
  Future<SaveTimingRecordWithImpactResult> execute({
    required TimingRecord? editing,
    required TimingRecord record,
    List<TimingCalculationHistory> calculationHistories = const [],
  }) async {
    // 事务外只做只读准备；最终 project_id 解析 / 可能创建 project
    // 必须进入下面同一个 transaction。
    final preparation = await prepareForSave(editing: editing, record: record);

    // 事务内：解析 / 创建 project → 重读旧记录 → 保存 → 解除合并（两侧）→ 重算 fen 应收 →
    //    evaluate → applyRevocations。任一步失败整体回滚。
    return AppDatabase.inTransaction((txn) {
      return executeWithExecutor(
        txn,
        editing: editing,
        preparation: preparation,
        calculationHistories: calculationHistories,
      );
    });
  }

  @override
  Future<SaveTimingRecordWithImpactResult> executeWithExecutor(
    DatabaseExecutor txn, {
    required TimingRecord? editing,
    required SaveTimingRecordPreparation preparation,
    List<TimingCalculationHistory> calculationHistories = const [],
  }) async {
    final recordToSave = await _resolveProjectIdForSaveWithExecutor(
      txn,
      editing: editing,
      record: preparation.recordToSave,
    );
    final newProjectId = recordToSave.effectiveProjectId.trim();
    final devices = preparation.devices;
    final rates = preparation.rates;
    final timestamp = preparation.timestampIso;

    // 事务内按 id 重读旧记录，作为 oldProjectId 的**唯一权威**来源。
    // UI 传入的 editing 可能已 stale（其它入口删除 / 恢复 / 修改）；
    // 必须以 DB 为准。
    String oldProjectId = '';
    if (editing != null) {
      final editingId = editing.id;
      if (editingId == null) {
        throw const TimingRecordSaveStaleException('编辑模式下计时记录必须带 id');
      }
      final fresh = await _timingRepository.findByIdWithExecutor(
        txn,
        editingId,
      );
      if (fresh == null) {
        throw const TimingRecordSaveStaleException('这条计时记录已不存在，请刷新后再试');
      }
      oldProjectId = fresh.effectiveProjectId.trim();
    }

    // 保存计时记录本身（事务内）。
    // update 返回行数 != 1 → 抛 [TimingRecordSaveStaleException] 触发回滚。
    final savedRecord = await _saveRecordWithExecutor(
      txn,
      recordToSave: recordToSave,
      calculationHistories: calculationHistories,
    );

    // 基于事务内权威 oldProjectId 判断是否发生项目变化。
    final projectChanged =
        editing != null &&
        oldProjectId.isNotEmpty &&
        newProjectId.isNotEmpty &&
        oldProjectId != newProjectId;

    // 收集受影响项目集合：至少 {oldProjectId, newProjectId}。
    final affectedProjectIds = <String>{
      if (oldProjectId.isNotEmpty) oldProjectId,
      if (newProjectId.isNotEmpty) newProjectId,
    };

    // project_id 变化 → 解除 **old / new 两侧** active 合并组。
    // - 两侧分别属于不同 group：两组都 dissolve。
    // - 两侧属于同一 group：只 dissolve 一次（用 dissolvedGroupIds 去重）。
    // - 解除时把组内全部活跃成员加入 affectedProjectIds，让后续 evaluate
    //   覆盖整组（避免只看 old/new 两个项目而漏算同组其它成员的 settled）。
    var mergeDissolved = false;
    if (projectChanged) {
      final dissolvedGroupIds = <int>{};
      Future<void> dissolveGroupForProject(String projectId) async {
        if (projectId.isEmpty) return;
        final member = await _mergeRepository
            .findActiveMemberByProjectIdWithExecutor(txn, projectId);
        if (member == null) return;
        // 同组重复触发 → 跳过；避免对同一 group 调两次 dissolve。
        if (!dissolvedGroupIds.add(member.groupId)) return;
        final groupMembers = await _mergeRepository
            .listActiveMembersByGroupIdWithExecutor(txn, member.groupId);
        for (final m in groupMembers) {
          final pid = m.projectId.trim();
          if (pid.isNotEmpty) affectedProjectIds.add(pid);
        }
        await _mergeRepository.dissolveGroupWithExecutor(
          txn,
          groupId: member.groupId,
          dissolvedAt: timestamp,
        );
        mergeDissolved = true;
      }

      await dissolveGroupForProject(oldProjectId);
      await dissolveGroupForProject(newProjectId);
    }

    // 基于保存后的 DB 状态，为每个受影响项目计算 receivableFen。
    // - 走 AccountService.calcMoney 既有口径（hours × effRate + rent income）。
    // - 不复用 UI 缓存 / AccountPageViewData。
    // - 仅最终一次性 yuanToFen，避免逐行 REAL 累加误差。
    final receivableFenByProjectId = <String, int>{};
    for (final projectId in affectedProjectIds) {
      final fen = await _computeReceivableFenForProject(
        txn,
        projectId: projectId,
        devices: devices,
        rates: rates,
      );
      receivableFenByProjectId[projectId] = fen;
    }

    // 走 Step 2 的权威 fen 影响判断 + 仅撤销 status 的 applyRevocations。
    // applyRevocations 只 settled → active，不删任何业务记录。
    final decision = await _impactService.evaluate(
      executor: txn,
      receivableFenByProjectId: receivableFenByProjectId,
      reason: ProjectSettlementImpactReason.editTiming,
    );
    final revocation = await _impactService.applyRevocations(
      executor: txn,
      decision: decision,
      updatedAtIso: timestamp,
    );

    final settlementRevoked = revocation.revokedProjectIds.isNotEmpty;

    await _enqueueSyncForSavedRecord(
      txn,
      savedRecord: savedRecord,
      isEditing: editing != null,
    );

    return SaveTimingRecordWithImpactResult(
      savedRecord: savedRecord,
      projectChanged: projectChanged,
      mergeDissolved: mergeDissolved,
      settlementRevoked: settlementRevoked,
      affectedProjectIds: affectedProjectIds.toList(growable: false),
      revokedProjectIds: revocation.revokedProjectIds,
      userMessage: _buildUserMessage(
        mergeDissolved: mergeDissolved,
        settlementRevoked: settlementRevoked,
      ),
    );
  }

  Future<void> _enqueueSyncForSavedRecord(
    DatabaseExecutor txn, {
    required TimingRecord savedRecord,
    required bool isEditing,
  }) async {
    final id = savedRecord.id;
    if (id == null) {
      throw StateError('sync_outbox 入队需要最终落库后的 timing_record id');
    }
    final operation = isEditing ? 'update' : 'create';
    final entityId = id.toString();
    final entry = await _syncOutboxRepository.enqueueWithExecutor(
      txn,
      entityType: _timingRecordEntityType,
      entityId: entityId,
      operation: operation,
      payload: {
        'entity_type': _timingRecordEntityType,
        'entity_id': entityId,
        'operation': operation,
        'record': savedRecord.toMap(),
      },
    );
    await _entitySyncMetaRepository.upsertWithExecutor(
      txn,
      EntitySyncMeta(
        entityType: _timingRecordEntityType,
        localId: entityId,
        syncStatus: isEditing
            ? SyncStatus.pendingUpdate
            : SyncStatus.pendingUpload,
        version: 0,
        source: _ownerAppSource,
        payloadHash: entry.payloadHash,
      ),
    );
  }

  /// 与既有 SaveTimingRecordUseCase 的 project_id 解析口径一致：
  /// - editing != null 且 legacy key 变化 → resolveOrCreate。
  /// - 否则若 record 已带 projectId → 直接使用。
  /// - 否则回退到 editing.projectId / resolveOrCreate。
  TimingRecord _prepareRecordForPreview({
    required TimingRecord? editing,
    required TimingRecord record,
  }) {
    if (record.projectId.trim().isNotEmpty) return record;
    if (editing == null ||
        editing.legacyProjectKey != record.legacyProjectKey) {
      return record;
    }
    final editedProjectId = editing.effectiveProjectId.trim();
    if (editedProjectId.isEmpty) return record;
    return record.copyWith(projectId: editedProjectId);
  }

  Future<TimingRecord> _resolveProjectIdForSaveWithExecutor(
    DatabaseExecutor txn, {
    required TimingRecord? editing,
    required TimingRecord record,
  }) async {
    if (editing != null &&
        editing.legacyProjectKey != record.legacyProjectKey) {
      final result = await _projectResolver.resolveOrCreateWithExecutor(
        txn,
        contact: record.contact,
        site: record.site,
      );
      return record.copyWith(projectId: result.projectId);
    }
    if (record.projectId.trim().isNotEmpty) return record;
    final editedProjectId = editing?.effectiveProjectId;
    if (editedProjectId != null && editedProjectId.trim().isNotEmpty) {
      return record.copyWith(projectId: editedProjectId);
    }
    final result = await _projectResolver.resolveOrCreateWithExecutor(
      txn,
      contact: record.contact,
      site: record.site,
    );
    return record.copyWith(projectId: result.projectId);
  }

  Future<TimingRecord> _saveRecordWithExecutor(
    DatabaseExecutor txn, {
    required TimingRecord recordToSave,
    required List<TimingCalculationHistory> calculationHistories,
  }) async {
    final id = recordToSave.id;
    if (id == null) {
      final insertedId = await _timingRepository.insertWithExecutor(
        txn,
        recordToSave,
      );
      await _timingCalculationHistoryRepository.insertManyWithExecutor(
        txn,
        insertedId,
        calculationHistories,
      );
      return recordToSave.copyWith(id: insertedId);
    }
    // 已存在记录：updateWithExecutor 必须刚好影响 1 行。
    //  - 0 行：DB 中没有该 id（并发删除 / 错误 id），按 stale 处理并回滚事务。
    //  - >1 行：约束异常或表结构异常；不允许静默通过。
    final affected = await _timingRepository.updateWithExecutor(
      txn,
      recordToSave,
    );
    if (affected == 0) {
      throw const TimingRecordSaveStaleException('这条计时记录已不存在或被并发修改，请刷新后再试');
    }
    if (affected > 1) {
      throw StateError(
        'updateWithExecutor 影响 $affected 行（期望 1）：'
        'timing_records 主键约束或并发异常',
      );
    }
    await _timingCalculationHistoryRepository.insertManyWithExecutor(
      txn,
      id,
      calculationHistories,
    );
    return recordToSave;
  }

  Future<int> _computeReceivableFenForProject(
    DatabaseExecutor txn, {
    required String projectId,
    required List<Device> devices,
    required List<ProjectDeviceRate> rates,
  }) async {
    final records = await _timingRepository.listByProjectIdWithExecutor(
      txn,
      projectId,
    );
    if (records.isEmpty) return 0;

    // 走 AccountService.calcMoney 的既有应收口径（hours × effRate + rent income）。
    // payments / writeOffs 在影响判断里由 ProjectSettlementImpactService 用
    // 权威 SUM(amount_fen) 重新取，因此这里只关心 receivable，可以传空。
    final aggs = AccountService.buildProjects(timingRecords: records);
    var receivableYuan = 0.0;
    for (final agg in aggs.values) {
      if (agg.projectId != projectId) continue;
      final money = AccountService.calcMoney(
        agg: agg,
        devices: devices,
        rates: rates,
        payments: const [],
        writeOffs: const [],
      );
      receivableYuan += money.receivable;
    }
    return ProjectFinanceCalculator.yuanToFen(receivableYuan);
  }

  String? _buildUserMessage({
    required bool mergeDissolved,
    required bool settlementRevoked,
  }) {
    if (!mergeDissolved && !settlementRevoked) return null;
    final parts = <String>[];
    if (mergeDissolved) parts.add('已自动解除相关合并项目');
    if (settlementRevoked) parts.add('已自动撤销结清状态');
    return '已保存，${parts.join('，')}。';
  }
}
