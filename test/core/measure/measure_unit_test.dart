import 'package:asset_ledger/core/measure/energy_type.dart';
import 'package:asset_ledger/core/measure/measure_unit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MeasureUnit', () {
    test('covers all billing units required by the outline (§10.3)', () {
      expect(MeasureUnit.values, hasLength(12));
      expect(
        MeasureUnit.values.map((u) => u.dbValue).toSet(),
        {
          'HOUR',
          'SHIFT',
          'DAY',
          'RENT',
          'MU',
          'ACRE',
          'HECTARE',
          'TON',
          'CUBIC_METER',
          'TRIP',
          'SORTIE',
          'TASK',
        },
      );
    });

    test('dbValue round-trips through defensive codec', () {
      for (final unit in MeasureUnit.values) {
        expect(MeasureUnitCodec.tryFromDbValue(unit.dbValue), unit);
      }
    });

    test('unknown or missing values resolve to null instead of throwing', () {
      expect(MeasureUnitCodec.tryFromDbValue('GALLON'), isNull);
      expect(MeasureUnitCodec.tryFromDbValue('hour'), isNull);
      expect(MeasureUnitCodec.tryFromDbValue(''), isNull);
      expect(MeasureUnitCodec.tryFromDbValue(null), isNull);
    });

    test('area units stay independent enums (方案 B, no auto conversion)', () {
      expect(
        {MeasureUnit.mu, MeasureUnit.acre, MeasureUnit.hectare},
        hasLength(3),
      );
    });
  });

  group('EnergyType', () {
    test('dbValue round-trips through defensive codec', () {
      for (final type in EnergyType.values) {
        expect(EnergyTypeCodec.tryFromDbValue(type.dbValue), type);
      }
    });

    test('unknown or missing values resolve to null instead of throwing', () {
      expect(EnergyTypeCodec.tryFromDbValue('HYBRID'), isNull);
      expect(EnergyTypeCodec.tryFromDbValue(null), isNull);
    });
  });
}
