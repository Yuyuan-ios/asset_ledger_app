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

abstract class ProjectSettlementRepository {
  Future<ProjectSettlementResult> settle(ProjectSettlementRequest request);

  Future<DeleteProjectWriteOffResult> deleteWriteOff(
    DeleteProjectWriteOffRequest request,
  );

  Future<RevokeProjectSettlementStatusResult> revokeSettlementStatus(
    RevokeProjectSettlementStatusRequest request,
  );
}
