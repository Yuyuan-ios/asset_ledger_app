import '../../../../core/measure/energy_type.dart';
import '../../../../core/measure/measure_unit.dart';
import '../../../../data/models/device.dart';

class TimingEntryUnitLayout {
  const TimingEntryUnitLayout({
    required this.unit,
    required this.modeLabel,
    required this.quantityLabel,
    required this.unitPriceLabel,
    required this.usesMeter,
  });

  final MeasureUnit unit;
  final String modeLabel;
  final String quantityLabel;
  final String unitPriceLabel;
  final bool usesMeter;
}

class TimingEntryTemplate {
  const TimingEntryTemplate({
    required this.equipmentKey,
    required this.equipmentLabel,
    required this.energyType,
    required this.unitLayouts,
  });

  final String equipmentKey;
  final String equipmentLabel;
  final EnergyType energyType;
  final List<TimingEntryUnitLayout> unitLayouts;

  bool get showsEnergyExclusion => energyType != EnergyType.none;

  String get energyExclusionTitle {
    switch (energyType) {
      case EnergyType.fuel:
        return '包油';
      case EnergyType.electric:
        return '包电';
      case EnergyType.none:
        return '';
    }
  }

  String get energyExclusionDescription {
    switch (energyType) {
      case EnergyType.fuel:
        return '开启后：本条工时不参与油耗效率统计。';
      case EnergyType.electric:
        return '开启后：本条记录不参与电耗效率统计。';
      case EnergyType.none:
        return '';
    }
  }

  TimingEntryUnitLayout layoutFor(MeasureUnit unit) {
    for (final layout in unitLayouts) {
      if (layout.unit == unit) return layout;
    }
    return TimingEntryTemplates.hourLayout;
  }
}

class TimingEntryTemplates {
  const TimingEntryTemplates._();

  static const hourLayout = TimingEntryUnitLayout(
    unit: MeasureUnit.hour,
    modeLabel: '工时',
    quantityLabel: '工时（小时）',
    unitPriceLabel: '元/小时',
    usesMeter: true,
  );

  static const rentLayout = TimingEntryUnitLayout(
    unit: MeasureUnit.rent,
    modeLabel: '租金(台班)',
    quantityLabel: '工时（小时，可空）',
    unitPriceLabel: '元/台班',
    usesMeter: true,
  );

  static const _phaseAUnits = <TimingEntryUnitLayout>[hourLayout, rentLayout];

  static const excavator = TimingEntryTemplate(
    equipmentKey: 'excavator',
    equipmentLabel: '挖掘机',
    energyType: EnergyType.fuel,
    unitLayouts: _phaseAUnits,
  );

  static const loader = TimingEntryTemplate(
    equipmentKey: 'loader',
    equipmentLabel: '装载机',
    energyType: EnergyType.fuel,
    unitLayouts: _phaseAUnits,
  );

  static const roller = TimingEntryTemplate(
    equipmentKey: 'roller',
    equipmentLabel: '压路机',
    energyType: EnergyType.fuel,
    unitLayouts: _phaseAUnits,
  );

  static const crane = TimingEntryTemplate(
    equipmentKey: 'crane',
    equipmentLabel: '吊车',
    energyType: EnergyType.fuel,
    unitLayouts: _phaseAUnits,
  );

  static const phaseA = <TimingEntryTemplate>[excavator, loader, roller, crane];

  static TimingEntryTemplate forDevice(Device device) {
    return forEquipmentKey(device.equipmentType.dbValue);
  }

  static TimingEntryTemplate forEquipmentKey(String key) {
    for (final template in phaseA) {
      if (template.equipmentKey == key) return template;
    }
    return excavator;
  }
}
