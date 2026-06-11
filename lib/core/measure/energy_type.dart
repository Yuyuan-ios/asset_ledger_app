/// 能耗类型（《机账通商业与实现纲要》§10.4）。
///
/// 决定录入页「包油/包电」标记 label 与「油电」导航下的能耗统计口径。
/// 枚举值是数据,永不翻译。
enum EnergyType {
  /// 燃油机械:录入页显示「包油」,统计油耗效率。
  fuel,

  /// 电动设备(无人机等):录入页显示「包电」,统计电量/架次续航。
  electric,

  /// 无能耗口径:不显示标记、不参与能耗统计。
  none,
}

extension EnergyTypeX on EnergyType {
  String get dbValue {
    switch (this) {
      case EnergyType.fuel:
        return 'FUEL';
      case EnergyType.electric:
        return 'ELECTRIC';
      case EnergyType.none:
        return 'NONE';
    }
  }
}

class EnergyTypeCodec {
  const EnergyTypeCodec._();

  /// 防御式解析:未知值返回 null,由调用方决定拒绝或回退。
  static EnergyType? tryFromDbValue(String? value) {
    switch (value) {
      case 'FUEL':
        return EnergyType.fuel;
      case 'ELECTRIC':
        return EnergyType.electric;
      case 'NONE':
        return EnergyType.none;
      default:
        return null;
    }
  }
}
