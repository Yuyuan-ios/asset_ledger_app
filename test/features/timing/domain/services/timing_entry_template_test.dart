import 'package:asset_ledger/core/measure/energy_type.dart';
import 'package:asset_ledger/core/measure/measure_unit.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/features/timing/domain/services/timing_entry_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TimingEntryTemplates phase A', () {
    test(
      'defines the current four equipment templates without changing schema',
      () {
        expect(
          TimingEntryTemplates.phaseA.map((template) => template.equipmentKey),
          ['excavator', 'loader', 'roller', 'crane'],
        );

        for (final template in TimingEntryTemplates.phaseA) {
          expect(template.energyType, EnergyType.fuel);
          expect(template.layoutFor(MeasureUnit.hour).usesMeter, isTrue);
          expect(template.layoutFor(MeasureUnit.hour).modeLabel, '工时');
          expect(template.layoutFor(MeasureUnit.hour).unitPriceLabel, '元/小时');
          expect(template.layoutFor(MeasureUnit.rent).modeLabel, '租金(台班)');
          expect(template.layoutFor(MeasureUnit.rent).unitPriceLabel, '元/台班');
        }
      },
    );

    test('resolves existing device model types to phase A templates', () {
      const excavator = Device(
        id: 1,
        name: 'SANY 1#',
        brand: 'SANY',
        defaultUnitPrice: 100,
        baseMeterHours: 0,
        equipmentType: EquipmentType.excavator,
      );
      const loader = Device(
        id: 2,
        name: 'LiuGong 1#',
        brand: 'LiuGong',
        defaultUnitPrice: 100,
        baseMeterHours: 0,
        equipmentType: EquipmentType.loader,
      );

      expect(TimingEntryTemplates.forDevice(excavator).equipmentLabel, '挖掘机');
      expect(TimingEntryTemplates.forDevice(loader).equipmentLabel, '装载机');
    });

    test('energy NONE templates hide the exclusion marker copy', () {
      const template = TimingEntryTemplate(
        equipmentKey: 'inspection_robot',
        equipmentLabel: '巡检机器人',
        energyType: EnergyType.none,
        unitLayouts: [TimingEntryTemplates.hourLayout],
      );

      expect(template.showsEnergyExclusion, isFalse);
      expect(template.energyExclusionTitle, isEmpty);
      expect(template.energyExclusionDescription, isEmpty);
    });
  });
}
