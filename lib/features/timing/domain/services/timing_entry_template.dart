import '../../../../core/measure/quantity.dart';
import '../../../../core/measure/energy_type.dart';
import '../../../../core/measure/measure_unit.dart';
import '../../../../core/money/amount_policy.dart';
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
    modeLabel: '台班(租金)',
    quantityLabel: '工时（小时，可空）',
    unitPriceLabel: '元/台班',
    usesMeter: true,
  );

  static const shiftLayout = TimingEntryUnitLayout(
    unit: MeasureUnit.shift,
    modeLabel: '台班',
    quantityLabel: '台班数',
    unitPriceLabel: '元/台班',
    usesMeter: false,
  );

  static const tonLayout = TimingEntryUnitLayout(
    unit: MeasureUnit.ton,
    modeLabel: '吨',
    quantityLabel: '吨数',
    unitPriceLabel: '元/吨',
    usesMeter: false,
  );

  static const tripLayout = TimingEntryUnitLayout(
    unit: MeasureUnit.trip,
    modeLabel: '趟次',
    quantityLabel: '趟次',
    unitPriceLabel: '元/趟',
    usesMeter: false,
  );

  static const cubicMeterLayout = TimingEntryUnitLayout(
    unit: MeasureUnit.cubicMeter,
    modeLabel: '方量',
    quantityLabel: '方量（方）',
    unitPriceLabel: '元/方',
    usesMeter: false,
  );

  static const muLayout = TimingEntryUnitLayout(
    unit: MeasureUnit.mu,
    modeLabel: '亩',
    quantityLabel: '作业面积（亩）',
    unitPriceLabel: '元/亩',
    usesMeter: false,
  );

  static const acreLayout = TimingEntryUnitLayout(
    unit: MeasureUnit.acre,
    modeLabel: '英亩',
    quantityLabel: '作业面积（英亩）',
    unitPriceLabel: '元/英亩',
    usesMeter: false,
  );

  static const hectareLayout = TimingEntryUnitLayout(
    unit: MeasureUnit.hectare,
    modeLabel: '公顷',
    quantityLabel: '作业面积（公顷）',
    unitPriceLabel: '元/公顷',
    usesMeter: false,
  );

  static const _phaseAUnits = <TimingEntryUnitLayout>[hourLayout, rentLayout];

  static const _cranePhaseBUnits = <TimingEntryUnitLayout>[
    shiftLayout,
    tonLayout,
    tripLayout,
  ];

  static const _transportPhaseBUnits = <TimingEntryUnitLayout>[
    tripLayout,
    cubicMeterLayout,
    hourLayout,
  ];

  static const _dronePhaseBUnits = <TimingEntryUnitLayout>[
    muLayout,
    acreLayout,
    hectareLayout,
  ];

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

  static const craneMultiUnit = TimingEntryTemplate(
    equipmentKey: 'crane',
    equipmentLabel: '吊车',
    energyType: EnergyType.fuel,
    unitLayouts: _cranePhaseBUnits,
  );

  static const transport = TimingEntryTemplate(
    equipmentKey: 'transport',
    equipmentLabel: '运输车',
    energyType: EnergyType.fuel,
    unitLayouts: _transportPhaseBUnits,
  );

  static const concretePump = TimingEntryTemplate(
    equipmentKey: 'concrete_pump',
    equipmentLabel: '泵车',
    energyType: EnergyType.fuel,
    unitLayouts: _transportPhaseBUnits,
  );

  static const plantProtectionDrone = TimingEntryTemplate(
    equipmentKey: 'plant_protection_drone',
    equipmentLabel: '植保无人机',
    energyType: EnergyType.electric,
    unitLayouts: _dronePhaseBUnits,
  );

  static const phaseA = <TimingEntryTemplate>[excavator, loader, roller, crane];

  static const phaseB = <TimingEntryTemplate>[
    craneMultiUnit,
    transport,
    concretePump,
    plantProtectionDrone,
  ];

  static TimingEntryTemplate forDevice(Device device) {
    return forEquipmentKey(device.equipmentType.dbValue);
  }

  static TimingEntryTemplate forEquipmentKey(String key) {
    for (final template in phaseA) {
      if (template.equipmentKey == key) return template;
    }
    return excavator;
  }

  static TimingEntryTemplate? phaseBTemplateForEquipmentKey(String key) {
    for (final template in phaseB) {
      if (template.equipmentKey == key) return template;
    }
    return null;
  }
}

class TimingEntryQuantityDraft {
  TimingEntryQuantityDraft._({
    required this.unit,
    required this.quantityScaled,
    required Map<String, Object?> auxRaw,
  }) : auxRaw = Map.unmodifiable(auxRaw);

  factory TimingEntryQuantityDraft.direct({
    required MeasureUnit unit,
    required double value,
  }) {
    final quantity = Quantity.fromValue(value);
    return TimingEntryQuantityDraft._(
      unit: unit,
      quantityScaled: quantity.scaled,
      auxRaw: <String, Object?>{
        'source': 'direct',
        'unit': unit.dbValue,
        'value_scaled': quantity.scaled,
      },
    );
  }

  factory TimingEntryQuantityDraft.parcelAreaSum({
    required MeasureUnit unit,
    required List<double> parcelAreas,
  }) {
    _requireAreaUnit(unit);
    final parcelsScaled = [
      for (final area in parcelAreas) Quantity.fromValue(area).scaled,
    ];
    final quantityScaled = parcelsScaled.fold<int>(
      0,
      (total, scaled) => total + scaled,
    );
    return TimingEntryQuantityDraft._(
      unit: unit,
      quantityScaled: quantityScaled,
      auxRaw: <String, Object?>{
        'source': 'parcel_sum',
        'unit': unit.dbValue,
        'parcels_scaled': parcelsScaled,
      },
    );
  }

  factory TimingEntryQuantityDraft.sortieAreaProduct({
    required MeasureUnit unit,
    required int sorties,
    required double areaPerSortie,
  }) {
    _requireAreaUnit(unit);
    if (sorties < 0) {
      throw ArgumentError.value(sorties, 'sorties', 'must not be negative');
    }
    final areaPerSortieScaled = Quantity.fromValue(areaPerSortie).scaled;
    return TimingEntryQuantityDraft._(
      unit: unit,
      quantityScaled: sorties * areaPerSortieScaled,
      auxRaw: <String, Object?>{
        'source': 'sortie_area_product',
        'unit': unit.dbValue,
        'sorties': sorties,
        'area_per_sortie_scaled': areaPerSortieScaled,
      },
    );
  }

  final MeasureUnit unit;
  final int quantityScaled;
  final Map<String, Object?> auxRaw;

  int get statQuantityScaled => quantityScaled;

  Money amountForUnitPrice(UnitPrice unitPrice) {
    return AmountPolicy.calculateAmountForQuantity(
      quantity: Quantity(quantityScaled),
      unitPrice: unitPrice,
    );
  }

  static void _requireAreaUnit(MeasureUnit unit) {
    if (unit == MeasureUnit.mu ||
        unit == MeasureUnit.acre ||
        unit == MeasureUnit.hectare) {
      return;
    }
    throw ArgumentError.value(unit, 'unit', 'must be an area unit');
  }
}
