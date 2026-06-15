import 'package:asset_ledger/data/models/fuel_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FuelLog', () {
    test('copyWith overrides selected fields and keeps existing values', () {
      const log = FuelLog(
        id: 1,
        deviceId: 2,
        date: 20260301,
        supplier: '张三',
        liters: 10,
        cost: 80,
      );

      final updated = log.copyWith(
        date: 20260302,
        liters: 12.5,
      );

      expect(updated.id, 1);
      expect(updated.deviceId, 2);
      expect(updated.date, 20260302);
      expect(updated.supplier, '张三');
      expect(updated.liters, 12.5);
      expect(updated.cost, 80);
    });

    test('toMap and fromMap preserve numeric values and fallback supplier', () {
      const log = FuelLog(
        id: 2,
        deviceId: 5,
        date: 20260303,
        supplier: '老何',
        liters: 20.5,
        cost: 166,
      );

      expect(log.toMap(), {
        'id': 2,
        'device_id': 5,
        'date': 20260303,
        'supplier': '老何',
        'liters': 20.5,
        'cost': 166.0,
        // A1：fen 影子列随 cost 双写。
        'cost_fen': 16600,
      });

      final rebuilt = FuelLog.fromMap({
        'id': 3,
        'device_id': 6,
        'date': 20260304,
        'liters': 8,
        'cost': 64,
      });

      expect(rebuilt.id, 3);
      expect(rebuilt.deviceId, 6);
      expect(rebuilt.date, 20260304);
      expect(rebuilt.supplier, '');
      expect(rebuilt.liters, 8);
      expect(rebuilt.cost, 64);
      // 旧库行无 cost_fen → null；不阻断读取，REAL 仍权威。
      expect(rebuilt.costFen, isNull);
      expect(rebuilt.toString(), contains('dev: 6'));
    });

    test('toMap derives cost_fen from cost; fromMap reads it back', () {
      const log = FuelLog(
        id: 9,
        deviceId: 1,
        date: 20260601,
        supplier: '王五',
        liters: 30,
        cost: 19.99, // 浮点敏感：round(19.99*100) == 1999
      );

      expect(log.toMap()['cost_fen'], 1999);
      expect(FuelLog.fromMap(log.toMap()).costFen, 1999);
    });
  });
}
