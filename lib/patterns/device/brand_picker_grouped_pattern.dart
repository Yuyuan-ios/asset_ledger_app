import 'package:flutter/material.dart';
import '../../data/models/device.dart';
import '../../tokens/mapper/core_tokens.dart';

/// ================================================================
/// 品牌选择器：国家分组 + ListView + GridView + CircleAvatar
///
/// 设计原则（配合你五层架构）：
/// - 这里只做“展示 + 选择”，不做业务逻辑（不生成 name、不做 nextIndex）
/// - DevicePage 仍然只维护 selectedBrand 字符串（brand 的存储值）
/// - brand 的存储值仍保持你现有命名规则：
///   例如："SANY" / "LiuGong" / "Komatsu" / "John Deere" / "DEVELON"
///   这样 DeviceService 生成的 name 仍是 "SANY 1#" 这种（逻辑不变）
///
/// 头像加载：
/// - 直接用 assets/brands/*.png
/// - 你 device_page.dart 里的 _brandAvatar 也能继续用（fallback 首字母）
///
/// 说明：
/// - 这个组件可以作为“选择品牌”的弹窗内容/子页面内容：
///   showModalBottomSheet(...) -> child: BrandPickerGrouped(...)
/// ================================================================

/// =====================================================================
/// ============================== 二、枚举：国家分组 ==============================
/// =====================================================================

/// 品牌的国家分组（用于 UI 分段标题）
enum BrandCountry { cn, jp, us, kr }

/// 给 enum 加一个“显示用 label”
/// - 这样 UI 不需要写 switch/if，直接用 c.label
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

/// =====================================================================
/// ============================== 三、数据结构：BrandItem ==============================
/// =====================================================================

class BrandItem {
  /// value：写回 Device.brand 的值（用于命名/筛选/统计）
  /// - 必须稳定（不随 UI 文字变化）
  /// - 例：SANY / Komatsu / John Deere
  final String value;

  /// name：UI 显示名（可包含中文 + 英文）
  /// - 只影响展示，不影响存储
  final String name;

  /// country：用于分组显示（ListView 里分段）
  final BrandCountry country;

  /// asset：圆形头像资源路径
  /// - 约定都放在 assets/brands 下
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

/// =====================================================================
/// ============================== 四、品牌静态数据（常量表） ==============================
/// =====================================================================

/// 你最终确定的 20 个品牌（按国家分组）
/// 注意：
/// - value 保持 “命名友好” 的品牌码（例如 SANY）
/// - asset 使用你 assets/brands 下的文件名（建议统一命名规范，避免大小写坑）
/// - John Deere 对应 john_deere.png
///
/// 这里的列表只是一份“展示字典”，
/// - UI 负责：显示 / 选择 / 回调
/// - Store/Service 负责：存储 / 规则 / 自动命名
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
    equipmentTypes: {EquipmentType.excavator},
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

/// =====================================================================
/// ============================== 五、BrandCatalog：查询工具 ==============================
/// =====================================================================
///
/// 作用：
/// - 给页面提供“查询/分组”的便捷入口（仍然属于 UI 辅助，不属于业务规则）
///
/// 为什么要有它：
/// - 让 BrandPickerGrouped 不直接操作 kBrandItems 的细节
/// - 后续如果你要把品牌配置改为从本地 JSON 读取，这层也更容易替换
class BrandCatalog {
  /// -------------------------------------------------------------------
  /// 5.1 tryGet
  /// 根据 value（Device.brand 的存储值）找到 BrandItem
  ///
  /// 用途：
  /// - 设备已保存 brand 后，要显示“中文名 + 英文名”
  /// - 要显示头像 asset
  ///
  /// 为什么是 tryGet（返回可空）：
  /// - 允许旧数据/异常数据存在（brand 值不在字典里时，不让 UI 崩溃）
  /// -------------------------------------------------------------------
  static BrandItem? tryGet(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    final v = value.trim();
    for (final b in kBrandItems) {
      if (b.value == v) return b;
    }
    return null;
  }

  /// -------------------------------------------------------------------
  /// 5.2 groups
  /// 按国家分组，返回：{国家 => 品牌列表}
  ///
  /// 说明：
  /// - 这里每次调用都会构建一个新的 map（品牌数量很小，没必要做缓存）
  /// - 如果未来品牌很多，可以改为缓存/预计算
  /// -------------------------------------------------------------------
  static Map<BrandCountry, List<BrandItem>> groups({
    EquipmentType? equipmentType,
  }) {
    // 先保证每个国家都有一个 list，避免 later 取 map[c] 时出现 null
    final map = {for (final c in BrandCountry.values) c: <BrandItem>[]};

    // 按 country 分类塞进去
    for (final b in kBrandItems) {
      if (equipmentType != null && !b.equipmentTypes.contains(equipmentType)) {
        continue;
      }
      map[b.country]!.add(b);
    }
    return map;
  }
}

/// =====================================================================
/// ============================== 六、BrandPickerGrouped：主组件 ==============================
/// =====================================================================
///
/// 组件职责：
/// - 以 ListView 展示多个分组（国家）
/// - 每个分组内部用 Grid 展示品牌头像
/// - 选中态高亮 + 点击回调 onSelected
///
/// 注意：
/// - 这个组件不做“写入 store”动作，外部传 onSelected 决定怎么处理
/// - 这个组件也不做“业务规则”动作（如自动命名/nextIndex）
class BrandPickerGrouped extends StatelessWidget {
  /// 当前已选 brand 的 value（Device.brand）
  /// - 用于选中态对比
  final String? selectedBrandValue;

  /// 用户点选某个品牌时的回调
  /// - 由外部决定：setState / Navigator.pop / store 更新等
  final ValueChanged<BrandItem> onSelected;

  /// Grid 每行显示多少个头像
  /// - 不同屏幕可以调整：例如手机 4~5，平板 6~8
  final int crossAxisCount;

  /// 圆形头像半径
  /// - 对应 CircleAvatar.radius
  final double avatarRadius;

  /// Grid 的间距
  /// - 同时用于 crossAxisSpacing / mainAxisSpacing
  final double spacing;
  final EquipmentType? equipmentTypeFilter;

  const BrandPickerGrouped({
    super.key,
    required this.selectedBrandValue,
    required this.onSelected,
    this.crossAxisCount = DeviceTokens.brandPickerDefaultCrossAxisCount,
    this.avatarRadius = DeviceTokens.brandPickerDefaultAvatarRadius,
    this.spacing = DeviceTokens.brandPickerDefaultGridSpacing,
    this.equipmentTypeFilter,
  });

  @override
  Widget build(BuildContext context) {
    // 先按国家拿到分组数据（map）
    // - {cn: [...], jp: [...], ...}
    final groups = BrandCatalog.groups(equipmentType: equipmentTypeFilter);

    return ListView(
      // ListView 自己滚动，所以内部 GridView 必须禁用滚动（见 _BrandGrid）
      padding: const EdgeInsets.symmetric(
        horizontal: DeviceTokens.brandPickerListPadHorizontal,
        vertical: DeviceTokens.brandPickerListPadVertical,
      ),
      children: [
        // 按枚举顺序输出分组：国家标题 + grid
        for (final c in BrandCountry.values)
          if (groups[c]!.isNotEmpty) ...[
            _CountryHeader(title: c.label),
            const SizedBox(
              height: DeviceTokens.brandPickerCountryHeaderBottomGap,
            ),

            // 每个国家分组的网格
            // - items: 该国家下的品牌
            _BrandGrid(
              items: groups[c]!,
              selectedBrandValue: selectedBrandValue,
              onSelected: onSelected,
              crossAxisCount: crossAxisCount,
              avatarRadius: avatarRadius,
              spacing: spacing,
            ),

            // 分组之间的间距
            const SizedBox(
              height: DeviceTokens.brandPickerCountryGroupBottomGap,
            ),
          ],
      ],
    );
  }
}

/// =====================================================================
/// ============================== 七、分组标题：_CountryHeader ==============================
/// =====================================================================
///
/// 纯 UI：左侧一个色条 + 标题文字
class _CountryHeader extends StatelessWidget {
  final String title;
  const _CountryHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 左侧颜色条：用 primary 色，和你的主题一致
        Container(
          width: DeviceTokens.brandPickerCountryMarkerWidth,
          height: DeviceTokens.brandPickerCountryMarkerHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              DeviceTokens.brandPickerCountryMarkerRadius,
            ),
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: DeviceTokens.brandPickerCountryMarkerToTitleGap),

        // 分组标题：例如“中国 / 日本 / 美国 / 韩国”
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: DeviceTokens.brandPickerCountryTitleWeight,
          ),
        ),
      ],
    );
  }
}

/// =====================================================================
/// ============================== 八、网格：_BrandGrid ==============================
/// =====================================================================
///
/// 关键点：
/// - 这里使用 GridView.builder，但它被放在外层 ListView 里面
///   所以必须：
///   1) shrinkWrap: true 让 Grid 根据内容撑开高度
///   2) physics: NeverScrollableScrollPhysics() 禁用 Grid 自己滚动
///      否则会出现“滚动冲突/高度不确定/性能问题”等常见坑
class _BrandGrid extends StatelessWidget {
  final List<BrandItem> items;
  final String? selectedBrandValue;
  final ValueChanged<BrandItem> onSelected;

  final int crossAxisCount;
  final double avatarRadius;
  final double spacing;

  const _BrandGrid({
    required this.items,
    required this.selectedBrandValue,
    required this.onSelected,
    required this.crossAxisCount,
    required this.avatarRadius,
    required this.spacing,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      // 让 Grid 根据 item 数量撑开高度，交给外层 ListView 滚动
      shrinkWrap: true,

      // 禁用 Grid 自己滚动，避免与外层 ListView 冲突
      physics: const NeverScrollableScrollPhysics(),

      itemCount: items.length,

      // Grid 布局策略：固定列数
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount, // 每行头像数
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,

        // 宽高比（调这个可以让“头像+两行文字”更舒服）
        // - 0.7 是你当前经验值
        childAspectRatio: 0.7,
      ),

      itemBuilder: (context, index) {
        final item = items[index];

        // 当前 item 是否为选中态
        // - 用存储值 value 对比（更稳定）
        final selected = (item.value == (selectedBrandValue ?? '').trim());

        return InkWell(
          // InkWell 的水波纹也要跟卡片圆角一致
          borderRadius: BorderRadius.circular(
            DeviceTokens.brandPickerItemInkRadius,
          ),

          // 点击把 BrandItem 回传给外部
          // - 外部通常会：setState(() => selectedBrand = item.value)
          // - 或者 Navigator.pop(context, item.value)
          onTap: () => onSelected(item),

          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 外层 circle：用于画“选中态边框”
              Container(
                padding: const EdgeInsets.all(
                  DeviceTokens.brandPickerItemOuterPad,
                ),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  // 选中态：加粗 + primary
                  // 未选中：细边 + dividerColor
                  border: Border.all(
                    width: selected
                        ? DeviceTokens.brandPickerItemSelectedBorderWidth
                        : DeviceTokens.brandPickerItemUnselectedBorderWidth,
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).dividerColor,
                  ),
                ),

                // CircleAvatar：品牌头像
                // 注意：
                // - backgroundImage 用 AssetImage
                // - 若 asset 不存在会报错（所以 pubspec.yaml 必须声明 assets）
                child: CircleAvatar(
                  radius: avatarRadius,
                  backgroundColor: Colors.white,
                  backgroundImage: AssetImage(item.asset),
                ),
              ),

              // 品牌显示名：支持两行，超出用省略号
              const SizedBox(height: DeviceTokens.brandPickerItemLabelTopGap),
              SizedBox(
                height:
                    DeviceTokens.brandPickerItemLabelBoxHeight, // 固定文字区高度（两行）
                child: Center(
                  child: Text(
                    item.name,
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      height: DeviceTokens.brandPickerItemLabelLineHeight,
                      fontWeight: selected
                          ? DeviceTokens.brandPickerItemLabelSelectedWeight
                          : DeviceTokens.brandPickerItemLabelUnselectedWeight,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
