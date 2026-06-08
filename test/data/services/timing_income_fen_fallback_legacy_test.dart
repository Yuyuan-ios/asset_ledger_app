import 'package:asset_ledger/data/models/project_id.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/services/account_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// R5.26-B4：legacy 行 income_fen 缺失 / NULL 时读路径回退 income REAL，不抛错。
void main() {
  final projectId = ProjectId.legacyFromParts(
    contact: 'Alice',
    site: 'Yard A',
  );

  Map<String, Object?> rentRow({
    required int id,
    required double income,
    Object? incomeFen = _absent,
  }) {
    final row = <String, Object?>{
      'id': id,
      'device_id': 1,
      'start_date': 20260300 + id,
      'contact': 'Alice',
      'site': 'Yard A',
      'type': 'rent',
      'start_meter': 0,
      'end_meter': 0,
      'hours': 0,
      'income': income,
    };
    if (!identical(incomeFen, _absent)) row['income_fen'] = incomeFen;
    return row;
  }

  test('fromMap row missing income_fen derives incomeFen without error', () {
    final record = TimingRecord.fromMap(rentRow(id: 1, income: 88.8));
    expect(record.income, 88.8);
    expect(record.incomeFen, 8880);
  });

  test('fromMap row with explicit null income_fen falls back to income', () {
    final record = TimingRecord.fromMap(
      rentRow(id: 1, income: 19.99, incomeFen: null),
    );
    expect(record.incomeFen, 1999);
  });

  test('rent aggregation over legacy rows falls back to round(income*100)', () {
    final records = [
      TimingRecord.fromMap(rentRow(id: 1, income: 0.1)), // no income_fen
      TimingRecord.fromMap(rentRow(id: 2, income: 100.0, incomeFen: null)),
    ];
    final agg = AccountService.buildProjects(timingRecords: records)[projectId]!;
    expect(agg.rentIncomeFen, 10 + 10000);
  });
}

const Object _absent = Object();
