import 'package:asset_ledger/data/models/device.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Device', () {
    test('copyWith overrides selected fields and keeps the rest', () {
      const device = Device(
        id: 1,
        name: 'SANY 1#',
        brand: 'SANY',
        model: 'SY75',
        defaultUnitPrice: 120,
        baseMeterHours: 88,
        isActive: true,
        customAvatarPath: '/tmp/avatar.png',
      );

      final updated = device.copyWith(
        name: 'SANY 2#',
        defaultUnitPrice: 150,
        isActive: false,
      );

      expect(updated.id, 1);
      expect(updated.name, 'SANY 2#');
      expect(updated.brand, 'SANY');
      expect(updated.model, 'SY75');
      expect(updated.defaultUnitPrice, 150);
      expect(updated.baseMeterHours, 88);
      expect(updated.isActive, isFalse);
      expect(updated.customAvatarPath, '/tmp/avatar.png');
    });

    test('toMap and fromMap use database field names and defaults', () {
      const device = Device(
        id: 2,
        name: 'CAT 1#',
        brand: 'CAT',
        defaultUnitPrice: 99.5,
        baseMeterHours: 10,
      );

      expect(device.toMap(), {
        'id': 2,
        'name': 'CAT 1#',
        'brand': 'CAT',
        'model': null,
        'default_unit_price': 99.5,
        'base_meter_hours': 10.0,
        'is_active': 1,
        'custom_avatar_path': null,
      });

      final rebuilt = Device.fromMap({
        'id': 3,
        'name': 'HITACHI 1#',
        'brand': 'HITACHI',
        'default_unit_price': 180,
        'base_meter_hours': 22,
        'is_active': 0,
      });

      expect(rebuilt.id, 3);
      expect(rebuilt.name, 'HITACHI 1#');
      expect(rebuilt.brand, 'HITACHI');
      expect(rebuilt.model, isNull);
      expect(rebuilt.defaultUnitPrice, 180);
      expect(rebuilt.baseMeterHours, 22);
      expect(rebuilt.isActive, isFalse);
      expect(rebuilt.customAvatarPath, isNull);
    });
  });
}
