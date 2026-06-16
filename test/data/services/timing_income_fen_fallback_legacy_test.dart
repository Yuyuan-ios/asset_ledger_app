import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:flutter_test/flutter_test.dart';

/// Track A / A4-7：model 读路径只接受 income_fen；legacy income 回填在
/// migration/restore 层完成。
void main() {
  Map<String, Object?> rentRow({required int id, Object? incomeFen = _absent}) {
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
    };
    if (!identical(incomeFen, _absent)) row['income_fen'] = incomeFen;
    return row;
  }

  test('fromMap row missing income_fen throws', () {
    expect(
      () => TimingRecord.fromMap(rentRow(id: 1)),
      throwsA(isA<StateError>()),
    );
  });

  test('fromMap row with explicit null income_fen throws', () {
    expect(
      () => TimingRecord.fromMap(rentRow(id: 1, incomeFen: null)),
      throwsA(isA<StateError>()),
    );
  });

  test('fromMap derives income getter from income_fen', () {
    final record = TimingRecord.fromMap(rentRow(id: 1, incomeFen: 1999));
    expect(record.incomeFen, 1999);
    expect(record.income, 19.99);
  });
}

const Object _absent = Object();
