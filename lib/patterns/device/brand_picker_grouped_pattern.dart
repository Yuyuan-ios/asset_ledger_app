import 'package:flutter/material.dart';
import '../../features/device/model/brand_catalog.dart';
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

  /// 按国家分好组的品牌数据（由页面层准备）
  final Map<BrandCountry, List<BrandItem>> groups;

  const BrandPickerGrouped({
    super.key,
    required this.selectedBrandValue,
    required this.onSelected,
    required this.groups,
    this.crossAxisCount = DeviceTokens.brandPickerDefaultCrossAxisCount,
    this.avatarRadius = DeviceTokens.brandPickerDefaultAvatarRadius,
    this.spacing = DeviceTokens.brandPickerDefaultGridSpacing,
  });

  @override
  Widget build(BuildContext context) {
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

        // 给品牌名两行文本留足空间，避免出现底部 overflow
        childAspectRatio: DeviceTokens.brandPickerItemAspectRatio,
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
