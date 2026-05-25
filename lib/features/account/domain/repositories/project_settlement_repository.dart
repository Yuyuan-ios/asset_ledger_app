import '../entities/project_settlement_result.dart';

class ProjectSettlementRequest {
  const ProjectSettlementRequest({
    required this.projectId,
    required this.projectKey,
    required this.receivable,
    required this.paymentAmount,
    required this.writeOffAmount,
    required this.writeOffReasonDbValue,
    required this.ymd,
    required this.createdAtIso,
    required this.writeOffDate,
    this.note,
    this.writeOffId,
  });

  final String projectId;
  final String projectKey;
  final double receivable;
  final double paymentAmount;
  final double writeOffAmount;
  final String? writeOffReasonDbValue;
  final int ymd;
  final String createdAtIso;
  final String writeOffDate;
  final String? note;
  final String? writeOffId;
}

class DeleteProjectWriteOffRequest {
  const DeleteProjectWriteOffRequest({
    required this.projectId,
    required this.writeOffId,
    required this.receivable,
    required this.updatedAtIso,
  });

  final String projectId;
  final String writeOffId;
  final double receivable;
  final String updatedAtIso;
}

class RevokeProjectSettlementStatusRequest {
  const RevokeProjectSettlementStatusRequest({
    required this.projectId,
    required this.updatedAtIso,
  });

  final String projectId;
  final String updatedAtIso;
}

class MergedProjectSettlementMemberRequest {
  const MergedProjectSettlementMemberRequest({
    required this.projectId,
    required this.projectKey,
    required this.receivable,
  });

  final String projectId;
  final String projectKey;
  final double receivable;
}

class MergedProjectSettlementAllocationRequest {
  const MergedProjectSettlementAllocationRequest({
    required this.projectId,
    required this.projectKey,
    required this.receivable,
    required this.writeOffAmount,
    required this.writeOffId,
  });

  final String projectId;
  final String projectKey;
  final double receivable;
  final double writeOffAmount;
  final String writeOffId;
}

class MergedProjectSettlementRequest {
  const MergedProjectSettlementRequest({
    required this.mergedProjectId,
    required this.mergeGroupId,
    required this.receivable,
    required this.writeOffAmount,
    required this.writeOffReasonDbValue,
    required this.ymd,
    required this.createdAtIso,
    required this.writeOffDate,
    required this.members,
    required this.allocations,
    this.note,
  });

  final String mergedProjectId;
  final int mergeGroupId;
  final double receivable;
  final double writeOffAmount;
  final String? writeOffReasonDbValue;
  final int ymd;
  final String createdAtIso;
  final String writeOffDate;
  final String? note;
  final List<MergedProjectSettlementMemberRequest> members;
  final List<MergedProjectSettlementAllocationRequest> allocations;
}

class DeleteMergedProjectWriteOffsRequest {
  const DeleteMergedProjectWriteOffsRequest({
    required this.mergedProjectId,
    required this.mergeGroupId,
    required this.members,
    required this.writeOffIds,
    required this.receivable,
    required this.updatedAtIso,
  });

  final String mergedProjectId;
  final int mergeGroupId;
  final List<MergedProjectSettlementMemberRequest> members;
  final List<String> writeOffIds;
  final double receivable;
  final String updatedAtIso;
}

class RevokeMergedProjectSettlementStatusRequest {
  const RevokeMergedProjectSettlementStatusRequest({
    required this.mergedProjectId,
    required this.members,
    required this.updatedAtIso,
  });

  final String mergedProjectId;
  final List<MergedProjectSettlementMemberRequest> members;
  final String updatedAtIso;
}

abstract class ProjectSettlementRepository {
  Future<ProjectSettlementResult> settle(ProjectSettlementRequest request);

  Future<ProjectSettlementResult> settleMerged(
    MergedProjectSettlementRequest request,
  );

  Future<DeleteProjectWriteOffResult> deleteWriteOff(
    DeleteProjectWriteOffRequest request,
  );

  Future<DeleteProjectWriteOffResult> deleteMergedWriteOffs(
    DeleteMergedProjectWriteOffsRequest request,
  );

  Future<RevokeProjectSettlementStatusResult> revokeSettlementStatus(
    RevokeProjectSettlementStatusRequest request,
  );

  Future<RevokeProjectSettlementStatusResult> revokeMergedSettlementStatus(
    RevokeMergedProjectSettlementStatusRequest request,
  );
}
