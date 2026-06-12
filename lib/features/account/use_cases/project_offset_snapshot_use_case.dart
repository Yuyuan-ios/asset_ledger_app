import '../../../data/models/project_write_off.dart';
import '../domain/services/project_finance_calculator.dart';
import 'project_settlement_use_case.dart';

abstract class ProjectOffsetSnapshotGateway {
  Future<ProjectSettlementResult> confirmOffset({
    required String projectId,
    required String projectKey,
    required double receivable,
    required double writeOffAmount,
    required int ymd,
    required String? note,
  });

  Future<DeleteProjectWriteOffResult> deleteWriteOff({
    required String projectId,
    required String writeOffId,
    required double receivable,
  });
}

class ProjectSettlementOffsetSnapshotGateway
    implements ProjectOffsetSnapshotGateway {
  const ProjectSettlementOffsetSnapshotGateway(this._settlementUseCase);

  final ProjectSettlementUseCase _settlementUseCase;

  @override
  Future<ProjectSettlementResult> confirmOffset({
    required String projectId,
    required String projectKey,
    required double receivable,
    required double writeOffAmount,
    required int ymd,
    required String? note,
  }) {
    return _settlementUseCase.execute(
      projectId: projectId,
      projectKey: projectKey,
      receivable: receivable,
      paymentAmount: 0,
      writeOffAmount: writeOffAmount,
      writeOffReason: ProjectWriteOffReason.offset,
      ymd: ymd,
      note: note,
    );
  }

  @override
  Future<DeleteProjectWriteOffResult> deleteWriteOff({
    required String projectId,
    required String writeOffId,
    required double receivable,
  }) {
    return _settlementUseCase.deleteWriteOff(
      projectId: projectId,
      writeOffId: writeOffId,
      receivable: receivable,
    );
  }
}

class ProjectOffsetSnapshotUseCase {
  const ProjectOffsetSnapshotUseCase({
    required ProjectOffsetSnapshotGateway gateway,
  }) : _gateway = gateway;

  final ProjectOffsetSnapshotGateway _gateway;

  Future<ProjectOffsetSnapshotResult> confirm({
    required String projectId,
    required String projectKey,
    required double ownedReceivable,
    required double externalWorkAmount,
    required int ymd,
    String? note,
    ProjectWriteOff? previousOffset,
  }) async {
    final normalizedProjectId = projectId.trim();
    final normalizedProjectKey = projectKey.trim();
    if (normalizedProjectId.isEmpty) {
      throw StateError('项目缺少稳定 ID');
    }
    if (normalizedProjectKey.isEmpty) {
      throw StateError('项目缺少兼容 key');
    }

    final snapshot = ProjectOffsetSnapshot.fromAmounts(
      ownedReceivable: ownedReceivable,
      externalWorkAmount: externalWorkAmount,
    );

    DeleteProjectWriteOffResult? deletedPreviousOffset;
    final previous = previousOffset;
    if (previous != null) {
      if (previous.reason != ProjectWriteOffReason.offset.dbValue) {
        throw StateError('只能作废旧抵扣快照后重建');
      }
      deletedPreviousOffset = await _gateway.deleteWriteOff(
        projectId: normalizedProjectId,
        writeOffId: previous.id,
        receivable: snapshot.ownedReceivable,
      );
    }

    final settlement = await _gateway.confirmOffset(
      projectId: normalizedProjectId,
      projectKey: normalizedProjectKey,
      receivable: snapshot.ownedReceivable,
      writeOffAmount: snapshot.offsetAmount,
      ymd: ymd,
      note: _snapshotNote(snapshot: snapshot, note: note),
    );

    return ProjectOffsetSnapshotResult(
      snapshot: snapshot,
      settlement: settlement,
      deletedPreviousOffset: deletedPreviousOffset,
    );
  }

  static String _snapshotNote({
    required ProjectOffsetSnapshot snapshot,
    required String? note,
  }) {
    final cleanNote = note?.trim();
    final snapshotLine =
        'offset_snapshot_v1 owned_receivable_fen=${snapshot.ownedReceivableFen} '
        'external_work_fen=${snapshot.externalWorkFen} '
        'net_receivable_fen=${snapshot.netReceivableFen}';
    if (cleanNote == null || cleanNote.isEmpty) return snapshotLine;
    return '$cleanNote\n$snapshotLine';
  }
}

class ProjectOffsetSnapshot {
  const ProjectOffsetSnapshot({
    required this.ownedReceivableFen,
    required this.externalWorkFen,
    required this.netReceivableFen,
    required this.offsetFen,
  });

  factory ProjectOffsetSnapshot.fromAmounts({
    required double ownedReceivable,
    required double externalWorkAmount,
  }) {
    final ownedReceivableFen = _fen(ownedReceivable);
    final externalWorkFen = _fen(externalWorkAmount);
    if (ownedReceivableFen <= 0) {
      throw StateError('我方应收必须大于 0');
    }
    if (externalWorkFen <= 0) {
      throw StateError('外协金额必须大于 0');
    }
    final offsetFen = externalWorkFen > ownedReceivableFen
        ? ownedReceivableFen
        : externalWorkFen;
    return ProjectOffsetSnapshot(
      ownedReceivableFen: ownedReceivableFen,
      externalWorkFen: externalWorkFen,
      netReceivableFen: ownedReceivableFen - externalWorkFen,
      offsetFen: offsetFen,
    );
  }

  final int ownedReceivableFen;
  final int externalWorkFen;
  final int netReceivableFen;
  final int offsetFen;

  double get ownedReceivable => _yuan(ownedReceivableFen);
  double get externalWorkAmount => _yuan(externalWorkFen);
  double get netReceivable => _yuan(netReceivableFen);
  double get offsetAmount => _yuan(offsetFen);
}

class ProjectOffsetSnapshotResult {
  const ProjectOffsetSnapshotResult({
    required this.snapshot,
    required this.settlement,
    this.deletedPreviousOffset,
  });

  final ProjectOffsetSnapshot snapshot;
  final ProjectSettlementResult settlement;
  final DeleteProjectWriteOffResult? deletedPreviousOffset;
}

int _fen(double yuan) => ProjectFinanceCalculator.yuanToFen(yuan);

double _yuan(int fen) => ProjectFinanceCalculator.fenToYuan(fen);
