import 'package:asset_ledger/core/measure/energy_type.dart';
import 'package:asset_ledger/core/measure/measure_unit.dart';
import 'package:asset_ledger/core/money/amount_policy.dart';
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

  group('TimingEntryTemplates phase B', () {
    test('defines crane SHIFT TON TRIP layouts without meter input', () {
      final template = TimingEntryTemplates.phaseBTemplateForEquipmentKey(
        'crane',
      );

      expect(template, isNotNull);
      expect(template!.equipmentLabel, '吊车');
      expect(template.unitLayouts.map((layout) => layout.unit), [
        MeasureUnit.shift,
        MeasureUnit.ton,
        MeasureUnit.trip,
      ]);
      expect(template.layoutFor(MeasureUnit.shift).usesMeter, isFalse);
      expect(template.layoutFor(MeasureUnit.shift).unitPriceLabel, '元/台班');
      expect(template.layoutFor(MeasureUnit.ton).usesMeter, isFalse);
      expect(template.layoutFor(MeasureUnit.ton).unitPriceLabel, '元/吨');
      expect(template.layoutFor(MeasureUnit.trip).usesMeter, isFalse);
      expect(template.layoutFor(MeasureUnit.trip).unitPriceLabel, '元/趟');
    });

    test('defines transport and pump TRIP CUBIC_METER HOUR layouts', () {
      final transport = TimingEntryTemplates.phaseBTemplateForEquipmentKey(
        'transport',
      );
      final pump = TimingEntryTemplates.phaseBTemplateForEquipmentKey(
        'concrete_pump',
      );

      for (final template in [transport, pump]) {
        expect(template, isNotNull);
        expect(template!.unitLayouts.map((layout) => layout.unit), [
          MeasureUnit.trip,
          MeasureUnit.cubicMeter,
          MeasureUnit.hour,
        ]);
        expect(template.layoutFor(MeasureUnit.trip).usesMeter, isFalse);
        expect(
          template.layoutFor(MeasureUnit.cubicMeter).unitPriceLabel,
          '元/方',
        );
        expect(template.layoutFor(MeasureUnit.cubicMeter).usesMeter, isFalse);
        expect(template.layoutFor(MeasureUnit.hour).usesMeter, isTrue);
        expect(template.layoutFor(MeasureUnit.hour).unitPriceLabel, '元/小时');
      }
    });

    test('defines drone MU ACRE HECTARE layouts and electric marker copy', () {
      final template = TimingEntryTemplates.phaseBTemplateForEquipmentKey(
        'plant_protection_drone',
      );

      expect(template, isNotNull);
      expect(template!.energyType, EnergyType.electric);
      expect(template.energyExclusionTitle, '包电');
      expect(template.unitLayouts.map((layout) => layout.unit), [
        MeasureUnit.mu,
        MeasureUnit.acre,
        MeasureUnit.hectare,
      ]);
      expect(template.layoutFor(MeasureUnit.mu).unitPriceLabel, '元/亩');
      expect(template.layoutFor(MeasureUnit.acre).unitPriceLabel, '元/英亩');
      expect(template.layoutFor(MeasureUnit.hectare).unitPriceLabel, '元/公顷');
      expect(template.unitLayouts.every((layout) => !layout.usesMeter), isTrue);
    });
  });

  group('TimingEntryQuantityDraft', () {
    test(
      'stores direct plant-protection input as aux_raw and quantity_scaled',
      () {
        final draft = TimingEntryQuantityDraft.direct(
          unit: MeasureUnit.mu,
          value: 12.5,
        );

        expect(draft.quantityScaled, 12500);
        expect(draft.statQuantityScaled, 12500);
        expect(draft.auxRaw, {
          'source': 'direct',
          'unit': 'MU',
          'value_scaled': 12500,
        });
        expect(draft.amountForUnitPrice(const UnitPrice(8000)).fen, 100000);
      },
    );

    test('sums parcel area input and keeps stats on quantity_scaled only', () {
      final draft = TimingEntryQuantityDraft.parcelAreaSum(
        unit: MeasureUnit.mu,
        parcelAreas: [5, 7.5],
      );
      final sameQuantity = TimingEntryQuantityDraft.sortieAreaProduct(
        unit: MeasureUnit.mu,
        sorties: 5,
        areaPerSortie: 2.5,
      );

      expect(draft.quantityScaled, 12500);
      expect(draft.auxRaw, {
        'source': 'parcel_sum',
        'unit': 'MU',
        'parcels_scaled': [5000, 7500],
      });
      expect(sameQuantity.quantityScaled, 12500);
      expect(draft.statQuantityScaled, sameQuantity.statQuantityScaled);
      expect(draft.amountForUnitPrice(const UnitPrice(8000)).fen, 100000);
    });

    test('calculates sortie area product and non-area amount examples', () {
      final droneDraft = TimingEntryQuantityDraft.sortieAreaProduct(
        unit: MeasureUnit.mu,
        sorties: 5,
        areaPerSortie: 2.5,
      );
      final tripDraft = TimingEntryQuantityDraft.direct(
        unit: MeasureUnit.trip,
        value: 3,
      );
      final shiftDraft = TimingEntryQuantityDraft.direct(
        unit: MeasureUnit.shift,
        value: 1.5,
      );

      expect(droneDraft.quantityScaled, 12500);
      expect(droneDraft.auxRaw, {
        'source': 'sortie_area_product',
        'unit': 'MU',
        'sorties': 5,
        'area_per_sortie_scaled': 2500,
      });
      expect(tripDraft.amountForUnitPrice(const UnitPrice(35000)).fen, 105000);
      expect(
        shiftDraft.amountForUnitPrice(const UnitPrice(120000)).fen,
        180000,
      );
    });

    test('rejects parcel and sortie helpers for non-area units', () {
      expect(
        () => TimingEntryQuantityDraft.parcelAreaSum(
          unit: MeasureUnit.trip,
          parcelAreas: [1],
        ),
        throwsArgumentError,
      );
      expect(
        () => TimingEntryQuantityDraft.sortieAreaProduct(
          unit: MeasureUnit.hour,
          sorties: 1,
          areaPerSortie: 1,
        ),
        throwsArgumentError,
      );
    });
  });
}
