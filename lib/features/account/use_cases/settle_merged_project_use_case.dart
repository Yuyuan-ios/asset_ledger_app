import '../../../core/utils/format_utils.dart';
import '../../../data/models/project_write_off.dart';
import '../domain/entities/project_settlement_result.dart';
import '../domain/repositories/project_settlement_repository.dart';
import '../domain/services/project_finance_calculator.dart';
import '../model/account_view_model.dart';

class SettleMergedProjectUseCase {
  SettleMergedProjectUseCase({
    required ProjectSettlementRepository repository,
    DateTime Function()? now,
    String Function({
      required int mergeGroupId,
      required String projectId,
      required int index,
      required DateTime now,
    })?
    writeOffIdFactory,
  }) : _repository = repository,
       _now = now ?? DateTime.now,
       _writeOffIdFactory = writeOffIdFactory;

  final ProjectSettlementRepository _repository;
  final DateTime Function() _now;
  final String Function({
    required int mergeGroupId,
    required String projectId,
    required int index,
    required DateTime now,
  })?
  _writeOffIdFactory;

  Future<ProjectSettlementResult> execute({
    required AccountProjectVM mergedProject,
    required List<AccountProjectVM> memberProjects,
    required double paymentAmount,
    required double writeOffAmount,
    required ProjectWriteOffReason? writeOffReason,
    required int ymd,
    String? note,
  }) async {
    final groupId = _requireMergedGroupId(mergedProject);
    final normalizedPaymentAmount = _zeroIfTiny(paymentAmount);
    final normalizedWriteOffAmount = _zeroIfTiny(writeOffAmount);
    if (_fen(normalizedPaymentAmount) > 0) {
      throw StateError('合并项目结清暂不支持新增实收，请先保存收款后再结清。');
    }
    if (_fen(normalizedWriteOffAmount) <= 0) {
      throw StateError('结清金额必须大于 0');
    }
    if (writeOffReason == null) {
      throw StateError('请选择核销原因');
    }
    if (_fen(normalizedWriteOffAmount) > _fen(mergedProject.remaining)) {
      throw StateError(
        '结清金额超出当前待收（待收约 ${FormatUtils.money(mergedProject.remaining)}）',
      );
    }

    final matchedMembers = _matchedMembers(mergedProject, memberProjects);
    for (final member in matchedMembers) {
      if (_fen(member.writeOff) > 0) {
        throw StateError('合并成员项目已存在核销记录，请先处理成员项目。');
      }
    }

    final now = _now().toUtc();
    final allocations = _buildAllocations(
      mergeGroupId: groupId,
      members: matchedMembers,
      amount: normalizedWriteOffAmount,
      now: now,
    );

    return _repository.settleMerged(
      MergedProjectSettlementRequest(
        mergedProjectId: mergedProject.effectiveProjectId,
        mergeGroupId: groupId,
        receivable: mergedProject.receivable,
        writeOffAmount: normalizedWriteOffAmount,
        writeOffReasonDbValue: writeOffReason.dbValue,
        ymd: ymd,
        createdAtIso: now.toIso8601String(),
        writeOffDate: _writeOffDateFromYmd(ymd),
        note: _cleanNote(note),
        members: _memberRequests(matchedMembers),
        allocations: allocations,
      ),
    );
  }

  Future<DeleteProjectWriteOffResult> deleteWriteOffs({
    required AccountProjectVM mergedProject,
    required List<AccountProjectVM> memberProjects,
    required List<ProjectWriteOff> writeOffs,
  }) async {
    final groupId = _requireMergedGroupId(mergedProject);
    final matchedMembers = _matchedMembers(mergedProject, memberProjects);
    final writeOffIds = writeOffs
        .map((item) => item.id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (writeOffIds.isEmpty) {
      throw StateError('合并项目核销记录异常，请先检查核销记录。');
    }

    return _repository.deleteMergedWriteOffs(
      DeleteMergedProjectWriteOffsRequest(
        mergedProjectId: mergedProject.effectiveProjectId,
        mergeGroupId: groupId,
        members: _memberRequests(matchedMembers),
        writeOffIds: writeOffIds,
        receivable: mergedProject.receivable,
        updatedAtIso: _now().toUtc().toIso8601String(),
      ),
    );
  }

  Future<RevokeProjectSettlementStatusResult> revokeSettlementStatus({
    required AccountProjectVM mergedProject,
    required List<AccountProjectVM> memberProjects,
  }) async {
    _requireMergedGroupId(mergedProject);
    final matchedMembers = _matchedMembers(mergedProject, memberProjects);
    return _repository.revokeMergedSettlementStatus(
      RevokeMergedProjectSettlementStatusRequest(
        mergedProjectId: mergedProject.effectiveProjectId,
        members: _memberRequests(matchedMembers),
        updatedAtIso: _now().toUtc().toIso8601String(),
      ),
    );
  }

  int _requireMergedGroupId(AccountProjectVM project) {
    final groupId = project.mergeGroupId;
    if (project.kind != AccountProjectKind.merged || groupId == null) {
      throw StateError('合并组不存在');
    }
    final memberIds = project.memberProjectIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (memberIds.isEmpty) {
      throw StateError('合并项目没有可结清的成员项目');
    }
    return groupId;
  }

  List<AccountProjectVM> _matchedMembers(
    AccountProjectVM mergedProject,
    List<AccountProjectVM> memberProjects,
  ) {
    final memberIds = mergedProject.memberProjectIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    final matched = [
      for (final project in memberProjects)
        if (memberIds.contains(project.effectiveProjectId)) project,
    ];
    if (matched.length != memberIds.length) {
      throw StateError('合并成员项目数据不完整，请刷新后重试。');
    }
    return matched;
  }

  List<MergedProjectSettlementMemberRequest> _memberRequests(
    List<AccountProjectVM> members,
  ) {
    return [
      for (final member in members)
        MergedProjectSettlementMemberRequest(
          projectId: member.effectiveProjectId,
          projectKey: member.projectKey,
          receivable: member.receivable,
        ),
    ];
  }

  List<MergedProjectSettlementAllocationRequest> _buildAllocations({
    required int mergeGroupId,
    required List<AccountProjectVM> members,
    required double amount,
    required DateTime now,
  }) {
    final payableMembers =
        members.where((member) {
          return _fen(member.remaining) > 0;
        }).toList()..sort((a, b) {
          final byDate = a.minYmd.compareTo(b.minYmd);
          if (byDate != 0) return byDate;
          return a.projectKey.compareTo(b.projectKey);
        });

    final sumRemaining = payableMembers.fold<double>(
      0,
      (sum, member) => sum + member.remaining,
    );
    if (_fen(sumRemaining) <= 0) {
      throw StateError('合并项目已结清，不能重复结清');
    }
    if (_fen(amount) > _fen(sumRemaining)) {
      throw StateError('结清金额超出当前待收（待收约 ${FormatUtils.money(sumRemaining)}）');
    }

    var left = amount;
    final allocations = <MergedProjectSettlementAllocationRequest>[];
    for (var index = 0; index < payableMembers.length; index += 1) {
      final member = payableMembers[index];
      final isLast = index == payableMembers.length - 1;
      var take = isLast
          ? left
          : (left < member.remaining ? left : member.remaining);
      take = _zeroIfTiny(take);
      if (_fen(take) <= 0) continue;
      allocations.add(
        MergedProjectSettlementAllocationRequest(
          projectId: member.effectiveProjectId,
          projectKey: member.projectKey,
          receivable: member.receivable,
          writeOffAmount: take,
          writeOffId: _writeOffId(
            mergeGroupId: mergeGroupId,
            projectId: member.effectiveProjectId,
            index: allocations.length,
            now: now,
          ),
        ),
      );
      left = _zeroIfTiny(left - take);
    }

    if (_fen(left) > 0) {
      throw StateError('合并项目核销分摊失败');
    }
    return allocations;
  }

  String _writeOffId({
    required int mergeGroupId,
    required String projectId,
    required int index,
    required DateTime now,
  }) {
    final factory = _writeOffIdFactory;
    if (factory != null) {
      return factory(
        mergeGroupId: mergeGroupId,
        projectId: projectId,
        index: index,
        now: now,
      );
    }
    return 'writeoff-merge-$mergeGroupId-${now.microsecondsSinceEpoch}-$index';
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
