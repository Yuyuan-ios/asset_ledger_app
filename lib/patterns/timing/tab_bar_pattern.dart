import 'package:flutter/material.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/timing_tokens.dart';

/// Figma: Component_TabBar
/// - 固定底部
/// - 5 个 Tab（计时/燃油/账户/维保/设备）
/// - 选中：品牌色 + 文案高亮
/// - 未选中：灰色
class ComponentTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const ComponentTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.sheetBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: TimingTokens.tabBarShadowBlur,
            offset: const Offset(0, TimingTokens.tabBarShadowOffsetY),
          ),
        ],
        border: const Border(
          top: BorderSide(
            color: AppColors.timingCardBorder,
            width: TimingTokens.tabBarBorderThickness,
          ),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        TimingTokens.tabBarHorizontalPadding,
        TimingTokens.tabBarTopPadding,
        TimingTokens.tabBarHorizontalPadding,
        bottomInset,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _item(index: 0, icon: Icons.timer, label: '计时'),
          _item(index: 1, icon: Icons.local_gas_station, label: '燃油'),
          _item(index: 2, icon: Icons.account_balance_wallet, label: '账户'),
          _item(index: 3, icon: Icons.build, label: '维保'),
          _item(index: 4, icon: Icons.settings, label: '设备'),
        ],
      ),
    );
  }

  Widget _item({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final selected = index == currentIndex;
    final color = selected
        ? AppColors.sheetAction
        : AppColors.timingTextSecondary;

    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(TimingTokens.tabItemRadius),
        child: Padding(
          padding: const EdgeInsets.only(top: TimingTokens.tabItemTopPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: index == 3
                    ? TimingTokens.tabIconBuildSize
                    : TimingTokens.tabIconDefaultSize,
                color: color,
              ),
              const SizedBox(height: TimingTokens.tabLabelTopGap),
              Text(
                label,
                style: TextStyle(
                  fontSize: TimingTokens.tabLabelFontSize,
                  height: TimingTokens.tabLabelLineHeight,
                  color: color,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
