import 'package:sqflite/sqflite.dart';

import '../../../data/repositories/account_payment_repository.dart';
import '../../../data/repositories/project_repository.dart';
import '../../../data/repositories/project_write_off_repository.dart';

/// 触发结清影响评估的业务场景。仅作为 snapshot 的上下文标签，
/// 供调用方拼提示文案 / 审计用，不参与判断逻辑。
enum ProjectSettlementImpactReason {
  /// 删除计时记录（DeleteTimingRecordWithImpactUseCase 路径）。
  deleteTiming,

  /// 修改计时记录（Step 3 SaveTimingRecordWithImpactUseCase 路径）。
  editTiming,

  /// 解除合并组 / 移除成员。
  dissolveMerge,

  /// 其它（默认）。
  other,
}

/// 单个项目的权威结清影响快照。
///
/// 所有金额单位均为 **fen 整数**。判断方法（[coversReceivable] /
/// [shouldRevokeSettlement] 等）只做整数比较，杜绝 yuan double + epsilon 的
/// 浮点近似。
class ProjectSettlementImpactSnapshot {
  const ProjectSettlementImpactSnapshot({
    required this.projectId,
    required this.receivableFen,
    required this.receivedFen,
    required this.writeOffFen,
    required this.wasSettled,
    required this.reason,
  });

  /// 受影响项目 id。
  final String projectId;

  /// 评估时使用的"权威应收"（fen）。
  /// 由调用方按业务上下文给出（删除/修改计时后重算的应收、解除合并后该项目独立的应收等）。
  final int receivableFen;

  /// 当前已收（fen，SUM(amount_fen)）。
  final int receivedFen;

  /// 当前核销总额（fen，SUM(amount_fen)）。
  final int writeOffFen;

  /// 评估前项目在 DB 中的结清状态。
  final bool wasSettled;

  /// 触发场景上下文标签。
  final ProjectSettlementImpactReason reason;

  /// 剩余应收（fen）。可为负（表示已收超过应收），不做钳制以便调用方诊断异常。
  int get remainingFen => receivableFen - receivedFen - writeOffFen;

  /// 是否已收 + 核销 >= 应收。整数比较，差 1 fen 都判未覆盖。
  bool get coversReceivable => receivedFen + writeOffFen >= receivableFen;

  /// 是否为 0 元空项目（业务规则 §5：0 元空项目不能结清）。
  bool get isZeroAmount =>
      receivableFen <= 0 && receivedFen == 0 && writeOffFen == 0;

  /// 是否应当撤销结清。
  ///
  /// 规则：
  /// - 未结清项目（[wasSettled] = false）**永不**返回 true（没什么可撤销的）。
  /// - 已结清但当前是 0 元空项目 → 应撤销（§5 兜底，纠正错误结清）。
  /// - 已结清但 [remainingFen] > 0（不再被覆盖）→ 应撤销。
  /// - 其它情况（已结清且仍被覆盖）→ 不撤销。
  bool get shouldRevokeSettlement {
    if (!wasSettled) return false;
    if (isZeroAmount) return true;
    return remainingFen > 0;
  }
}

/// 一批受影响项目的评估结果。
class ProjectSettlementImpactDecision {
  const ProjectSettlementImpactDecision({required this.snapshots});

  final List<ProjectSettlementImpactSnapshot> snapshots;

  /// 需要撤销结清的项目快照。
  Iterable<ProjectSettlementImpactSnapshot> get revocationsNeeded =>
      snapshots.where((s) => s.shouldRevokeSettlement);

  bool get anyRevocationNeeded => revocationsNeeded.isNotEmpty;
}

/// 撤销结清的最小执行结果（不删除任何业务记录）。
class ProjectSettlementRevocationResult {
  const ProjectSettlementRevocationResult({required this.revokedProjectIds});

  /// 真正被撤销的项目 id 列表（即从 settled → active 的项目）。
  /// 已经是 active / 不存在的项目不会出现在此列表中。
  final List<String> revokedProjectIds;
}

/// 项目结清影响的权威评估服务。
///
/// 设计原则（business_rules_v1.md §3 / §5 / §7）：
/// 1. 全程整数 fen 算术。不读 amount REAL，不依赖 projectSettlementEpsilon。
/// 2. **不删除**收款 / 核销 / 计时 / 外协等任何业务记录。
/// 3. 撤销结清只调用 [SqfliteProjectRepository.restoreActiveWithExecutor]，
///    即把 status 从 settled 还原为 active。
/// 4. [evaluate] 是只读操作，可在事务外或事务内安全调用。
/// 5. [applyRevocations] 必须由调用方决定时机；通常与"保存计时/解除合并"
///    放在同一个事务里，任一步失败整体回滚。
///
/// 使用场景：
/// - 阶段 B Step 3 的 SaveTimingRecordWithImpactUseCase（修改计时影响项目）。
/// - 解除合并组 / 移除合并成员后重算每个成员的结清状态。
/// - 删除计时记录路径（DeleteTimingRecordWithImpactUseCase）的策略不同：
///   它选择 *无条件* 删除该项目所有核销 + 还原 active；不复用本服务。
///   理由见 cleanup_9_5_plan.md Step 3 接入点说明。
class ProjectSettlementImpactService {
  ProjectSettlementImpactService({SqfliteProjectRepository? projectRepository})
    : _projectRepository = projectRepository ?? SqfliteProjectRepository();

  final SqfliteProjectRepository _projectRepository;

  /// 在 [executor] 上对一批项目做权威结清评估。
  ///
  /// [receivableFenByProjectId]：调用方给出的权威应收（fen），key 是项目 id。
  /// 本服务自己**不**决定 receivable —— 该值依赖业务上下文（剩余计时 ×
  /// rate、外协包合并口径等），由调用方负责。
  ///
  /// 返回的 [ProjectSettlementImpactDecision] 是只读决策对象，可直接展示给
  /// 用户预览，或作为 [applyRevocations] 的输入。
  Future<ProjectSettlementImpactDecision> evaluate({
    required DatabaseExecutor executor,
    required Map<String, int> receivableFenByProjectId,
    ProjectSettlementImpactReason reason = ProjectSettlementImpactReason.other,
  }) async {
    final snapshots = <ProjectSettlementImpactSnapshot>[];
    for (final entry in receivableFenByProjectId.entries) {
      final projectId = entry.key.trim();
      if (projectId.isEmpty) continue;
      final receivableFen = entry.value;
      final receivedFen = await _sumFenByProjectId(
        executor,
        table: SqfliteAccountPaymentRepository.table,
        projectId: projectId,
      );
      final writeOffFen = await _sumFenByProjectId(
        executor,
        table: SqfliteProjectWriteOffRepository.table,
        projectId: projectId,
      );
      final wasSettled = await _projectRepository.isSettledWithExecutor(
        executor,
        projectId,
      );
      snapshots.add(
        ProjectSettlementImpactSnapshot(
          projectId: projectId,
          receivableFen: receivableFen,
          receivedFen: receivedFen,
          writeOffFen: writeOffFen,
          wasSettled: wasSettled,
          reason: reason,
        ),
      );
    }
    return ProjectSettlementImpactDecision(snapshots: snapshots);
  }

  /// 根据 [decision] 的 [ProjectSettlementImpactSnapshot.shouldRevokeSettlement]
  /// 执行撤销结清动作。
  ///
  /// **唯一副作用**：对每个需要撤销的项目调用
  /// [SqfliteProjectRepository.restoreActiveWithExecutor]——把 status 从
  /// settled 还原为 active，清空 settled_at / settled_snapshot。
  ///
  /// 不删除 / 不修改任何 payment、write_off、timing_record、external_work 行。
  Future<ProjectSettlementRevocationResult> applyRevocations({
    required DatabaseExecutor executor,
    required ProjectSettlementImpactDecision decision,
    required String updatedAtIso,
  }) async {
    final revoked = <String>[];
    for (final snapshot in decision.revocationsNeeded) {
      final didRestore = await _projectRepository.restoreActiveWithExecutor(
        executor,
        projectId: snapshot.projectId,
        updatedAt: updatedAtIso,
      );
      if (didRestore) revoked.add(snapshot.projectId);
    }
    return ProjectSettlementRevocationResult(revokedProjectIds: revoked);
  }

  /// 权威 fen 汇总。表名参数化，便于复用同一查询同时聚合
  /// account_payments / project_write_offs。
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
}
