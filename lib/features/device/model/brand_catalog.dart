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

  /// asset：圆形头像资源路径；为空时由 UI 回退为「文字圆形头像」
  /// （无人机 / 机器人等暂无 logo 资源的品牌走此路径，不强行引入第三方图片）
  final String asset;

  /// 该品牌归属的设备类型 id 集合（对应 [DeviceTypeDef.id]）。
  ///
  /// 刻意用字符串 id 而非 EquipmentType 枚举：这样无人机 / 机器人等
  /// 不落库到 EquipmentType 的类型，也能在品牌库里被分桶。
  final Set<String> deviceTypeIds;

  const BrandItem({
    required this.value,
    required this.name,
    required this.country,
    this.asset = '',
    this.deviceTypeIds = const {'excavator'},
  });
}

/// 品牌静态数据（按国家分组）
const List<BrandItem> kBrandItems = [
  // ============================ 工程机械 ============================
  // 🇨🇳 中国
  BrandItem(
    value: 'SANY',
    name: '三一 SANY',
    country: BrandCountry.cn,
    asset: 'assets/brands/sany.png',
    deviceTypeIds: {'excavator', 'loader'},
  ),
  BrandItem(
    value: 'XCMG',
    name: '徐工 XCMG',
    country: BrandCountry.cn,
    asset: 'assets/brands/xcmg.png',
    deviceTypeIds: {'excavator', 'loader'},
  ),
  BrandItem(
    value: 'LiuGong',
    name: '柳工 LiuGong',
    country: BrandCountry.cn,
    asset: 'assets/brands/liugong.png',
    deviceTypeIds: {'excavator', 'loader'},
  ),
  BrandItem(
    value: 'Zoomlion',
    name: '中联 Zoomlion',
    country: BrandCountry.cn,
    asset: 'assets/brands/zoomlion.png',
    deviceTypeIds: {'excavator', 'loader'},
  ),
  BrandItem(
    value: 'Sunward',
    name: '山河智能 Sunward',
    country: BrandCountry.cn,
    asset: 'assets/brands/sunward.png',
    deviceTypeIds: {'excavator'},
  ),
  BrandItem(
    value: 'SDLG',
    name: '临工 SDLG',
    country: BrandCountry.cn,
    asset: 'assets/brands/sdlg.png',
    deviceTypeIds: {'loader'},
  ),
  BrandItem(
    value: 'Shantui',
    name: '山推 Shantui',
    country: BrandCountry.cn,
    asset: 'assets/brands/shantui.png',
    deviceTypeIds: {'excavator', 'loader'},
  ),

  // 🇯🇵 日本
  BrandItem(
    value: 'Komatsu',
    name: 'Komatsu 小松',
    country: BrandCountry.jp,
    asset: 'assets/brands/komatsu.png',
    deviceTypeIds: {'excavator'},
  ),
  BrandItem(
    value: 'Hitachi',
    name: 'Hitachi 日立建机',
    country: BrandCountry.jp,
    asset: 'assets/brands/hitachi.png',
    deviceTypeIds: {'excavator'},
  ),
  BrandItem(
    value: 'Kobelco',
    name: 'Kobelco 神钢',
    country: BrandCountry.jp,
    asset: 'assets/brands/kobelco.png',
    deviceTypeIds: {'excavator'},
  ),
  BrandItem(
    value: 'Kubota',
    name: 'Kubota 久保田',
    country: BrandCountry.jp,
    asset: 'assets/brands/kubota.png',
    deviceTypeIds: {'excavator'},
  ),
  BrandItem(
    value: 'Yanmar',
    name: 'Yanmar 洋马',
    country: BrandCountry.jp,
    asset: 'assets/brands/yanmar.png',
    deviceTypeIds: {'excavator'},
  ),
  BrandItem(
    value: 'Sumitomo',
    name: 'Sumitomo 住友建机',
    country: BrandCountry.jp,
    asset: 'assets/brands/sumitomo.png',
    deviceTypeIds: {'excavator'},
  ),
  BrandItem(
    value: 'Takeuchi',
    name: 'Takeuchi 竹内',
    country: BrandCountry.jp,
    asset: 'assets/brands/takeuchi.png',
    deviceTypeIds: {'excavator'},
  ),

  // 🇺🇸 美国
  BrandItem(
    value: 'CAT',
    name: 'Caterpillar 卡特 CAT',
    country: BrandCountry.us,
    asset: 'assets/brands/cat.png',
    deviceTypeIds: {'excavator'},
  ),
  BrandItem(
    value: 'John Deere',
    name: 'John Deere 迪尔',
    country: BrandCountry.us,
    asset: 'assets/brands/john_deere.png',
    deviceTypeIds: {'excavator', 'loader'},
  ),
  BrandItem(
    value: 'CASE',
    name: 'CASE 凯斯',
    country: BrandCountry.us,
    asset: 'assets/brands/case.png',
    deviceTypeIds: {'excavator'},
  ),
  BrandItem(
    value: 'Bobcat',
    name: 'Bobcat 山猫',
    country: BrandCountry.us,
    asset: 'assets/brands/bobcat.png',
    deviceTypeIds: {'excavator'},
  ),

  // 🇰🇷 韩国
  BrandItem(
    value: 'HYUNDAI',
    name: 'HYUNDAI 现代工程机械',
    country: BrandCountry.kr,
    asset: 'assets/brands/hyundai.png',
    deviceTypeIds: {'excavator'},
  ),
  BrandItem(
    value: 'DEVELON',
    name: 'DEVELON（原斗山 Doosan）',
    country: BrandCountry.kr,
    asset: 'assets/brands/develon.png',
    deviceTypeIds: {'excavator'},
  ),

  // ====================== 无人机（暂无 logo，UI 回退文字头像） ======================
  // 🇨🇳 中国
  BrandItem(
    value: 'DJI',
    name: '大疆 DJI',
    country: BrandCountry.cn,
    deviceTypeIds: {'drone'},
  ),
  BrandItem(
    value: 'XAG',
    name: '极飞 XAG',
    country: BrandCountry.cn,
    deviceTypeIds: {'drone'},
  ),
  // 🇺🇸 美国
  BrandItem(
    value: 'Skydio',
    name: 'Skydio',
    country: BrandCountry.us,
    deviceTypeIds: {'drone'},
  ),

  // ================== 机器人（按国家分组，刻意不按机器人子类分组） ==================
  // 🇨🇳 中国
  BrandItem(
    value: 'Unitree',
    name: '宇树 Unitree',
    country: BrandCountry.cn,
    deviceTypeIds: {'robot'},
  ),
  BrandItem(
    value: 'UBTECH',
    name: '优必选 UBTECH',
    country: BrandCountry.cn,
    deviceTypeIds: {'robot'},
  ),
  BrandItem(
    value: 'AgiBot',
    name: '智元 AgiBot',
    country: BrandCountry.cn,
    deviceTypeIds: {'robot'},
  ),
  BrandItem(
    value: 'XPeng',
    name: '小鹏 XPeng',
    country: BrandCountry.cn,
    deviceTypeIds: {'robot'},
  ),
  BrandItem(
    value: 'Li Auto',
    name: '理想 Li Auto',
    country: BrandCountry.cn,
    deviceTypeIds: {'robot'},
  ),
  // 🇺🇸 美国
  BrandItem(
    value: 'Tesla',
    name: '特斯拉 Tesla',
    country: BrandCountry.us,
    deviceTypeIds: {'robot'},
  ),
  BrandItem(
    value: 'Boston Dynamics',
    name: '波士顿动力 Boston Dynamics',
    country: BrandCountry.us,
    deviceTypeIds: {'robot'},
  ),
  BrandItem(
    value: 'Figure AI',
    name: 'Figure AI',
    country: BrandCountry.us,
    deviceTypeIds: {'robot'},
  ),
  BrandItem(
    value: 'Agility Robotics',
    name: 'Agility Robotics',
    country: BrandCountry.us,
    deviceTypeIds: {'robot'},
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

  /// 按设备类型 id 取品牌，并可选地按关键字过滤（匹配中文名/英文名/value）。
  static Map<BrandCountry, List<BrandItem>> groupsByTypeId(
    String deviceTypeId, {
    String query = '',
  }) {
    final q = query.trim().toLowerCase();
    final map = {for (final c in BrandCountry.values) c: <BrandItem>[]};
    for (final b in kBrandItems) {
      if (!b.deviceTypeIds.contains(deviceTypeId)) continue;
      if (q.isNotEmpty &&
          !b.name.toLowerCase().contains(q) &&
          !b.value.toLowerCase().contains(q)) {
        continue;
      }
      map[b.country]!.add(b);
    }
    return map;
  }
}
