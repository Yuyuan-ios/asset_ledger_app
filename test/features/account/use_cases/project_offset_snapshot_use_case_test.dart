import 'package:asset_ledger/data/models/project_write_off.dart';
import 'package:asset_ledger/features/account/domain/entities/project_settlement_result.dart';
import 'package:asset_ledger/features/account/use_cases/project_offset_snapshot_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('confirms offset as a write-off snapshot, not a payment', () async {
    final gateway = _FakeOffsetGateway();
    final useCase = ProjectOffsetSnapshotUseCase(gateway: gateway);

    final result = await useCase.confirm(
      projectId: ' project:1 ',
      projectKey: ' 甲方||一号工地 ',
      ownedReceivable: 1000,
      externalWorkAmount: 300,
      ymd: 20260612,
      note: '外协抵扣确认',
    );

    expect(result.snapshot.ownedReceivableFen, 100000);
    expect(result.snapshot.externalWorkFen, 30000);
    expect(result.snapshot.netReceivableFen, 70000);
    expect(result.snapshot.offsetFen, 30000);
    expect(result.settlement.writeOffAmount, 300);
    expect(result.settlement.paymentAmount, 0);
    expect(gateway.events, ['confirm:30000']);
    expect(gateway.lastConfirmProjectId, 'project:1');
    expect(gateway.lastConfirmProjectKey, '甲方||一号工地');
    expect(gateway.lastConfirmYmd, 20260612);
    expect(gateway.lastConfirmNote, contains('外协抵扣确认'));
    expect(gateway.lastConfirmNote, contains('owned_receivable_fen=100000'));
    expect(gateway.lastConfirmNote, contains('external_work_fen=30000'));
    expect(gateway.lastConfirmNote, contains('net_receivable_fen=70000'));
  });

  test(
    'confirmed snapshot is not rewritten when source amounts change',
    () async {
      final gateway = _FakeOffsetGateway();
      final useCase = ProjectOffsetSnapshotUseCase(gateway: gateway);
      var ownedReceivable = 1000.0;
      var externalWorkAmount = 300.0;

      final result = await useCase.confirm(
        projectId: 'project:1',
        projectKey: '甲方||一号工地',
        ownedReceivable: ownedReceivable,
        externalWorkAmount: externalWorkAmount,
        ymd: 20260612,
      );

      ownedReceivable = 1500;
      externalWorkAmount = 900;

      expect(result.snapshot.ownedReceivableFen, 100000);
      expect(result.snapshot.externalWorkFen, 30000);
      expect(result.snapshot.netReceivableFen, 70000);
      expect(gateway.lastConfirmAmountFen, 30000);
    },
  );

  test('voids previous offset snapshot before rebuilding', () async {
    final gateway = _FakeOffsetGateway();
    final useCase = ProjectOffsetSnapshotUseCase(gateway: gateway);

    final result = await useCase.confirm(
      projectId: 'project:1',
      projectKey: '甲方||一号工地',
      ownedReceivable: 1200,
      externalWorkAmount: 500,
      ymd: 20260612,
      previousOffset: _offsetWriteOff(id: 'offset-old', amount: 300),
    );

    expect(result.deletedPreviousOffset?.writeOffId, 'offset-old');
    expect(result.snapshot.offsetFen, 50000);
    expect(gateway.events, ['delete:offset-old', 'confirm:50000']);
  });

  test('rejects rebuilding from a non-offset write-off', () async {
    final gateway = _FakeOffsetGateway();
    final useCase = ProjectOffsetSnapshotUseCase(gateway: gateway);

    expect(
      () => useCase.confirm(
        projectId: 'project:1',
        projectKey: '甲方||一号工地',
        ownedReceivable: 1200,
        externalWorkAmount: 500,
        ymd: 20260612,
        previousOffset: _offsetWriteOff(
          id: 'settlement-old',
          amount: 300,
          reason: ProjectWriteOffReason.settlement,
        ),
      ),
      throwsStateError,
    );
    expect(gateway.events, isEmpty);
  });

  test('net formula can go negative while persisted offset is capped', () {
    final snapshot = ProjectOffsetSnapshot.fromAmounts(
      ownedReceivable: 300,
      externalWorkAmount: 500,
    );

    expect(snapshot.netReceivableFen, -20000);
    expect(snapshot.offsetFen, 30000);
  });
}

ProjectWriteOff _offsetWriteOff({
  required String id,
  required double amount,
  ProjectWriteOffReason reason = ProjectWriteOffReason.offset,
}) {
  return ProjectWriteOff(
    id: id,
    projectId: 'project:1',
    amount: amount,
    reason: reason.dbValue,
    writeOffDate: '2026-06-12',
    createdAt: '2026-06-12T00:00:00.000Z',
    updatedAt: '2026-06-12T00:00:00.000Z',
  );
}

class _FakeOffsetGateway implements ProjectOffsetSnapshotGateway {
  final events = <String>[];
  String? lastConfirmProjectId;
  String? lastConfirmProjectKey;
  int? lastConfirmYmd;
  String? lastConfirmNote;
  int? lastConfirmAmountFen;

  @override
  Future<ProjectSettlementResult> confirmOffset({
    required String projectId,
    required String projectKey,
    required double receivable,
    required double writeOffAmount,
    required int ymd,
    required String? note,
  }) async {
    final amountFen = (writeOffAmount * 100).round();
    events.add('confirm:$amountFen');
    lastConfirmProjectId = projectId;
    lastConfirmProjectKey = projectKey;
    lastConfirmYmd = ymd;
    lastConfirmNote = note;
    lastConfirmAmountFen = amountFen;
    return ProjectSettlementResult(
      projectId: projectId,
      receivable: receivable,
      receivedBefore: 0,
      writeOffBefore: 0,
      remainingBefore: receivable,
      paymentAmount: 0,
      writeOffAmount: writeOffAmount,
      receivedAfter: 0,
      writeOffAfter: writeOffAmount,
      remainingAfter: receivable - writeOffAmount,
      settled: receivable - writeOffAmount <= 0,
      writeOffId: 'offset-new',
    );
  }

  @override
  Future<DeleteProjectWriteOffResult> deleteWriteOff({
    required String projectId,
    required String writeOffId,
    required double receivable,
  }) async {
    events.add('delete:$writeOffId');
    return DeleteProjectWriteOffResult(
      projectId: projectId,
      writeOffId: writeOffId,
      deletedAmount: 300,
      receivable: receivable,
      received: 0,
      writeOffBefore: 300,
      writeOffAfter: 0,
      remainingAfter: receivable,
      restoredActive: true,
    );
  }
}
