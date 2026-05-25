import '../../../data/models/timing_record.dart';

/// 删除计时记录前的影响分析结果。
///
/// 由 UI 用于决定：是否阻止删除、需要哪种二次确认文案。删除真正执行时，
/// 协调器会在事务内重新核算权威状态并据此联动清理，本结构仅服务于交互层。
class TimingRecordDeleteImpact {
  const TimingRecordDeleteImpact({
    required this.record,
    required this.projectId,
    required this.projectKey,
    required this.isLastTimingRecordOfProject,
    required this.hasPayments,
    required this.hasWriteOff,
    required this.isSettled,
    required this.mergeGroupId,
    required this.willRemoveMergeMember,
    required this.willDissolveMergeGroup,
    required this.linkedExternalBatchCount,
    required this.willUnlinkExternalWork,
  });

  /// 待删除的计时记录。
  final TimingRecord record;

  /// 该记录所属项目的稳定 ID。
  final String projectId;

  /// 该记录所属项目的兼容 key。
  final String projectKey;

  /// 删除后该项目是否不再有其它本地计时记录。
  final bool isLastTimingRecordOfProject;

  /// 该项目是否存在收款记录。
  final bool hasPayments;

  /// 该项目是否存在核销记录。
  final bool hasWriteOff;

  /// 该项目当前是否为「已结清」状态。
  final bool isSettled;

  /// 该项目当前所属的活跃合并组 ID（不在合并组中为 null）。
  final int? mergeGroupId;

  /// 删除后是否会从合并组中移除该项目成员。
  final bool willRemoveMergeMember;

  /// 删除后合并组剩余有效成员是否不足 2 个而需要停用整组。
  final bool willDissolveMergeGroup;

  /// 关联到该项目的外协包数量（按导入批次去重）。
  final int linkedExternalBatchCount;

  /// 删除后是否会解除外协关联。
  final bool willUnlinkExternalWork;

  /// 有收款记录且删的是项目最后一条计时：必须阻止删除。
  bool get isBlockedByPayments =>
      isLastTimingRecordOfProject && hasPayments;

  /// 删除需要撤销结清（删除核销 + 恢复进行中）。
  bool get requiresSettlementRevoke => isSettled || hasWriteOff;

  /// 删的是最后一条且会触发合并/外协联动清理。
  bool get hasLastRecordCascade =>
      isLastTimingRecordOfProject &&
      (willRemoveMergeMember || willUnlinkExternalWork);
}

/// 删除计时记录联动清理的执行结果，供 UI 给出贴合的成功反馈。
class TimingRecordDeleteOutcome {
  const TimingRecordDeleteOutcome({
    this.settlementRevoked = false,
    this.mergeMemberRemoved = false,
    this.mergeGroupDissolved = false,
    this.externalWorkUnlinked = false,
  });

  final bool settlementRevoked;
  final bool mergeMemberRemoved;
  final bool mergeGroupDissolved;
  final bool externalWorkUnlinked;

  bool get hasCascade =>
      settlementRevoked ||
      mergeMemberRemoved ||
      mergeGroupDissolved ||
      externalWorkUnlinked;
}

/// 该项目已有收款记录、又删的是最后一条计时时抛出，用于阻止删除并提示先处理收款。
class TimingDeleteBlockedByPaymentsException implements Exception {
  const TimingDeleteBlockedByPaymentsException([
    this.message = '该项目已有收款记录。请先处理收款记录后再删除该项目的最后一条计时。',
  ]);

  final String message;

  @override
  String toString() => 'TimingDeleteBlockedByPaymentsException: $message';
}

/// 删除计时记录前的影响分析 + 联动删除协调器（契约）。
///
/// 实现位于 infrastructure 层（需要数据库事务），UI/Feature 仅依赖此抽象。
abstract class DeleteTimingRecordWithImpactUseCase {
  /// 分析删除某条计时记录会带来的影响。不写库。
  Future<TimingRecordDeleteImpact> analyzeImpact(int recordId);

  /// 在单个事务内删除该记录并执行联动清理。
  ///
  /// 若该记录是项目最后一条计时且项目存在收款，抛出
  /// [TimingDeleteBlockedByPaymentsException]，整体不写库。
  Future<TimingRecordDeleteOutcome> executeDeleteWithImpact(int recordId);
}
