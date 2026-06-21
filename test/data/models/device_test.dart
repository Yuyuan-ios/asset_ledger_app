import 'package:asset_ledger/data/models/device.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Device', () {
    test('copyWith overrides selected fields and keeps the rest', () {
      final device = Device(
        id: 1,
        name: 'SANY 1#',
        brand: 'SANY',
        model: 'SY75',
        defaultUnitPrice: 120,
        baseMeterHours: 88,
        isActive: true,
        customAvatarPath: '/tmp/avatar.png',
        lifecycleInitialCostFen: 1200000,
        lifecycleEstimatedResidualFen: 180000,
      );

      final updated = device.copyWith(
        name: 'SANY 2#',
        defaultUnitPrice: 150,
        isActive: false,
        lifecycleInitialCostFen: null,
      );

      expect(updated.id, 1);
      expect(updated.name, 'SANY 2#');
      expect(updated.brand, 'SANY');
      expect(updated.model, 'SY75');
      expect(updated.defaultUnitPrice, 150);
      expect(updated.baseMeterHours, 88);
      expect(updated.isActive, isFalse);
      expect(updated.customAvatarPath, '/tmp/avatar.png');
      expect(updated.lifecycleInitialCostFen, isNull);
      expect(updated.lifecycleEstimatedResidualFen, 180000);
    });

    test('toMap and fromMap use database field names and defaults', () {
      final device = Device(
        id: 2,
        name: 'CAT 1#',
        brand: 'CAT',
        defaultUnitPrice: 99.5,
        baseMeterHours: 10,
        lifecycleInitialCostFen: 888000,
        lifecycleEstimatedResidualFen: 120000,
      );

      expect(device.toMap(), {
        'id': 2,
        'name': 'CAT 1#',
        'brand': 'CAT',
        'model': null,
        'default_unit_price_fen': 9950,
        'breaking_unit_price_fen': null,
        'base_meter_hours': 10.0,
        'is_active': 1,
        'custom_avatar_path': null,
        'equipment_type': 'excavator',
        'lifecycle_initial_cost_fen': 888000,
        'lifecycle_estimated_residual_fen': 120000,
      });

      final rebuilt = Device.fromMap({
        'id': 3,
        'name': 'HITACHI 1#',
        'brand': 'HITACHI',
        'default_unit_price_fen': 18000,
        'base_meter_hours': 22,
        'is_active': 0,
      });

      expect(rebuilt.id, 3);
      expect(rebuilt.name, 'HITACHI 1#');
      expect(rebuilt.brand, 'HITACHI');
      expect(rebuilt.model, isNull);
      expect(rebuilt.defaultUnitPrice, 180);
      expect(rebuilt.defaultUnitPriceFen, 18000);
      expect(rebuilt.baseMeterHours, 22);
      expect(rebuilt.isActive, isFalse);
      expect(rebuilt.customAvatarPath, isNull);
      expect(rebuilt.equipmentType, EquipmentType.excavator);
      expect(rebuilt.lifecycleInitialCostFen, isNull);
      expect(rebuilt.lifecycleEstimatedResidualFen, isNull);
    });

    test('fromMap reads lifecycle payback amount columns', () {
      final rebuilt = Device.fromMap({
        'id': 4,
        'name': 'SANY 4#',
        'brand': 'SANY',
        'default_unit_price_fen': 20000,
        'base_meter_hours': 0,
        'lifecycle_initial_cost_fen': 1500000,
        'lifecycle_estimated_residual_fen': 230000,
      });

      expect(rebuilt.lifecycleInitialCostFen, 1500000);
      expect(rebuilt.lifecycleEstimatedResidualFen, 230000);
    });

    test('fromMap requires fen authority', () {
      expect(
        () => Device.fromMap({
          'id': 3,
          'name': 'HITACHI 1#',
          'brand': 'HITACHI',
          'default_unit_price': 180,
          'base_meter_hours': 22,
          'is_active': 0,
        }),
        throwsA(isA<StateError>()),
      );
    });
  });
}
