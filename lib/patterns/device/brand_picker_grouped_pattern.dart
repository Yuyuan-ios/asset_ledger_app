import 'package:flutter/material.dart';
import '../../features/device/model/brand_catalog.dart';
import '../../l10n/gen/app_localizations.dart';
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

  /// 可选的滚动头部，例如品牌搜索框。
  final Widget? header;

  const BrandPickerGrouped({
    super.key,
    required this.selectedBrandValue,
    required this.onSelected,
    required this.groups,
    this.header,
    this.crossAxisCount = DeviceTokens.brandPickerDefaultCrossAxisCount,
    this.avatarRadius = DeviceTokens.brandPickerDefaultAvatarRadius,
    this.spacing = DeviceTokens.brandPickerDefaultGridSpacing,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      // ListView 自己滚动，所以内部 GridView 必须禁用滚动（见 _BrandGrid）
      padding: const EdgeInsets.symmetric(
        horizontal: DeviceTokens.brandPickerListPadHorizontal,
        vertical: DeviceTokens.brandPickerListPadVertical,
      ),
      children: [
        ?header,

        // 按枚举顺序输出分组：国家标题 + grid
        for (final c in BrandCountry.values)
          if (groups[c]!.isNotEmpty) ...[
            _CountryHeader(title: _countryLabel(l10n, c)),
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

  String _countryLabel(AppLocalizations l10n, BrandCountry country) {
    switch (country) {
      case BrandCountry.cn:
        return l10n.deviceBrandCountryChina;
      case BrandCountry.jp:
        return l10n.deviceBrandCountryJapan;
      case BrandCountry.us:
        return l10n.deviceBrandCountryUs;
      case BrandCountry.kr:
        return l10n.deviceBrandCountryKorea;
    }
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

                // 品牌头像：
                // - 有 logo 资源（工程机械）：保持原有 CircleAvatar + AssetImage 样式不变
                // - 无 logo 资源（无人机 / 机器人）：回退「文字圆形头像」，不引第三方图片
                child: _BrandFace(item: item, radius: avatarRadius),
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

/// =====================================================================
/// ============================== 九、品牌头像：_BrandFace ==============================
/// =====================================================================
///
/// - asset 非空：沿用原有 CircleAvatar + AssetImage（工程机械样式不变）
/// - asset 为空：文字圆形头像（无人机 / 机器人等暂无 logo 的品牌）
///   取 value 的英文首字母（或词首字母组合），保持白底圆形的简洁观感
class _BrandFace extends StatelessWidget {
  final BrandItem item;
  final double radius;

  const _BrandFace({required this.item, required this.radius});

  String get _initials {
    final raw = item.value.trim();
    if (raw.isEmpty) return '?';
    final words = raw.split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return (words[0].characters.first + words[1].characters.first)
          .toUpperCase();
    }
    final take = raw.length >= 2 ? raw.substring(0, 2) : raw;
    return take.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (item.asset.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white,
        backgroundImage: AssetImage(item.asset),
      );
    }

    final primary = Theme.of(context).colorScheme.primary;
    return CircleAvatar(
      radius: radius,
      backgroundColor: primary.withValues(alpha: 0.10),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: radius * 0.28),
          child: Text(
            _initials,
            maxLines: 1,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
