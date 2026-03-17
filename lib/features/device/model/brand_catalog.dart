import '../../../data/models/device.dart';

/// 品牌的国家分组（用于 UI 分段标题）
enum BrandCountry { cn, jp, us, kr }

/// 给 enum 加一个“显示用 label”
extension BrandCountryX on BrandCountry {
  String get label {
    switch (this) {
      case BrandCountry.cn:
        return '中国';
      case BrandCountry.jp:
        return '日本';
      case BrandCountry.us:
        return '美国';
      case BrandCountry.kr:
        return '韩国';
    }
  }
}

class BrandItem {
  /// value：写回 Device.brand 的值（用于命名/筛选/统计）
  final String value;

  /// name：UI 显示名（可包含中文 + 英文）
  final String name;

  /// country：用于分组显示（ListView 里分段）
  final BrandCountry country;

  /// asset：圆形头像资源路径
  final String asset;

  /// 设备类别：挖掘机 / 装载机
  final Set<EquipmentType> equipmentTypes;

  const BrandItem({
    required this.value,
    required this.name,
    required this.country,
    required this.asset,
    this.equipmentTypes = const {EquipmentType.excavator},
  });
}

/// 品牌静态数据（按国家分组）
const List<BrandItem> kBrandItems = [
  // 🇨🇳 中国
  BrandItem(
    value: 'SANY',
    name: '三一 SANY',
    country: BrandCountry.cn,
    asset: 'assets/brands/sany.png',
    equipmentTypes: {EquipmentType.excavator, EquipmentType.loader},
  ),
  BrandItem(
    value: 'XCMG',
    name: '徐工 XCMG',
    country: BrandCountry.cn,
    asset: 'assets/brands/xcmg.png',
    equipmentTypes: {EquipmentType.excavator, EquipmentType.loader},
  ),
  BrandItem(
    value: 'LiuGong',
    name: '柳工 LiuGong',
    country: BrandCountry.cn,
    asset: 'assets/brands/liugong.png',
    equipmentTypes: {EquipmentType.excavator, EquipmentType.loader},
  ),
  BrandItem(
    value: 'Zoomlion',
    name: '中联 Zoomlion',
    country: BrandCountry.cn,
    asset: 'assets/brands/zoomlion.png',
    equipmentTypes: {EquipmentType.excavator, EquipmentType.loader},
  ),
  BrandItem(
    value: 'Sunward',
    name: '山河智能 Sunward',
    country: BrandCountry.cn,
    asset: 'assets/brands/sunward.png',
    equipmentTypes: {EquipmentType.excavator},
  ),
  BrandItem(
    value: 'SDLG',
    name: '临工 SDLG',
    country: BrandCountry.cn,
    asset: 'assets/brands/sdlg.png',
    equipmentTypes: {EquipmentType.loader},
  ),
  BrandItem(
    value: 'Shantui',
    name: '山推 Shantui',
    country: BrandCountry.cn,
    asset: 'assets/brands/shantui.png',
    equipmentTypes: {EquipmentType.excavator, EquipmentType.loader},
  ),

  // 🇯🇵 日本
  BrandItem(
    value: 'Komatsu',
    name: 'Komatsu 小松',
    country: BrandCountry.jp,
    asset: 'assets/brands/komatsu.png',
    equipmentTypes: {EquipmentType.excavator},
  ),
  BrandItem(
    value: 'Hitachi',
    name: 'Hitachi 日立建机',
    country: BrandCountry.jp,
    asset: 'assets/brands/hitachi.png',
    equipmentTypes: {EquipmentType.excavator},
  ),
  BrandItem(
    value: 'Kobelco',
    name: 'Kobelco 神钢',
    country: BrandCountry.jp,
    asset: 'assets/brands/kobelco.png',
    equipmentTypes: {EquipmentType.excavator},
  ),
  BrandItem(
    value: 'Kubota',
    name: 'Kubota 久保田',
    country: BrandCountry.jp,
    asset: 'assets/brands/kubota.png',
    equipmentTypes: {EquipmentType.excavator},
  ),
  BrandItem(
    value: 'Yanmar',
    name: 'Yanmar 洋马',
    country: BrandCountry.jp,
    asset: 'assets/brands/yanmar.png',
    equipmentTypes: {EquipmentType.excavator},
  ),
  BrandItem(
    value: 'Sumitomo',
    name: 'Sumitomo 住友建机',
    country: BrandCountry.jp,
    asset: 'assets/brands/sumitomo.png',
    equipmentTypes: {EquipmentType.excavator},
  ),
  BrandItem(
    value: 'Takeuchi',
    name: 'Takeuchi 竹内',
    country: BrandCountry.jp,
    asset: 'assets/brands/takeuchi.png',
    equipmentTypes: {EquipmentType.excavator},
  ),

  // 🇺🇸 美国
  BrandItem(
    value: 'CAT',
    name: 'Caterpillar 卡特 CAT',
    country: BrandCountry.us,
    asset: 'assets/brands/cat.png',
    equipmentTypes: {EquipmentType.excavator},
  ),
  BrandItem(
    value: 'John Deere',
    name: 'John Deere 迪尔',
    country: BrandCountry.us,
    asset: 'assets/brands/john_deere.png',
    equipmentTypes: {EquipmentType.excavator, EquipmentType.loader},
  ),
  BrandItem(
    value: 'CASE',
    name: 'CASE 凯斯',
    country: BrandCountry.us,
    asset: 'assets/brands/case.png',
    equipmentTypes: {EquipmentType.excavator},
  ),
  BrandItem(
    value: 'Bobcat',
    name: 'Bobcat 山猫',
    country: BrandCountry.us,
    asset: 'assets/brands/bobcat.png',
    equipmentTypes: {EquipmentType.excavator},
  ),

  // 🇰🇷 韩国
  BrandItem(
    value: 'HYUNDAI',
    name: 'HYUNDAI 现代工程机械',
    country: BrandCountry.kr,
    asset: 'assets/brands/hyundai.png',
    equipmentTypes: {EquipmentType.excavator},
  ),
  BrandItem(
    value: 'DEVELON',
    name: 'DEVELON（原斗山 Doosan）',
    country: BrandCountry.kr,
    asset: 'assets/brands/develon.png',
    equipmentTypes: {EquipmentType.excavator},
  ),
];

/// 品牌查询与分组工具（UI 辅助）
class BrandCatalog {
  static BrandItem? tryGet(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    final v = value.trim();
    for (final b in kBrandItems) {
      if (b.value == v) return b;
    }
    return null;
  }

  static Map<BrandCountry, List<BrandItem>> groups({
    EquipmentType? equipmentType,
  }) {
    final map = {for (final c in BrandCountry.values) c: <BrandItem>[]};
    for (final b in kBrandItems) {
      if (equipmentType != null && !b.equipmentTypes.contains(equipmentType)) {
        continue;
      }
      map[b.country]!.add(b);
    }
    return map;
  }
}
