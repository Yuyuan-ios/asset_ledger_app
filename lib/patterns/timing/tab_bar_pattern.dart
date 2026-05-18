import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/foundation/typography.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/timing_tokens.dart';

/// Figma: Component_TabBar
/// - 固定底部
/// - 5 个 Tab（计时/燃油/账户/维保/设备）
/// - 选中：品牌色 + 文案高亮
/// - 未选中：灰色
class ComponentTabBar extends StatelessWidget {
  const ComponentTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const List<_TabSpec> _tabs = <_TabSpec>[
    _TabSpec(label: '计时', icon: Icons.timer_rounded),
    _TabSpec(label: '燃油', icon: Icons.local_gas_station_rounded),
    _TabSpec(label: '账户', icon: Icons.account_balance_wallet_rounded),
    _TabSpec(label: '维保', icon: Icons.build_rounded),
    _TabSpec(label: '设备', icon: Icons.settings_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: NavigationTokens.topShadowColor,
            blurRadius: 18,
            offset: Offset(0, -6),
          ),
          BoxShadow(
            color: NavigationTokens.ambientShadowColor,
            blurRadius: 28,
            offset: Offset(0, -10),
          ),
        ],
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: NavigationTokens.glassBlur,
            sigmaY: NavigationTokens.glassBlur,
          ),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  NavigationTokens.glassTopBackground,
                  NavigationTokens.glassBottomBackground,
                ],
              ),
              border: Border(
                top: BorderSide(
                  color: NavigationTokens.topBorderColor,
                  width: NavigationTokens.topBorderWidth,
                ),
              ),
            ),
            child: SizedBox(
              height: NavigationTokens.barHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  NavigationTokens.barHorizontalPadding,
                  NavigationTokens.contentTopPadding,
                  NavigationTokens.barHorizontalPadding,
                  NavigationTokens.contentBottomPadding,
                ),
                child: Row(
                  children: List.generate(
                    _tabs.length,
                    (index) => Expanded(
                      child: _TabButton(
                        spec: _tabs[index],
                        selected: index == currentIndex,
                        onTap: () => onTap(index),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final _TabSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? TimingTokens.headerAddButtonBackground
        : Colors.black.withValues(alpha: NavigationTokens.inactiveAlpha);
    final labelStyle = AppTypography.caption(
      context,
      fontSize: NavigationTokens.labelFontSize,
      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
      color: color,
      height: 1,
    );

    return Semantics(
      button: true,
      selected: selected,
      label: spec.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(NavigationTokens.itemRadius),
          splashColor: NavigationTokens.interactionOverlay,
          highlightColor: NavigationTokens.interactionOverlay,
          hoverColor: NavigationTokens.interactionOverlay,
          child: Center(
            child: Transform.translate(
              offset: const Offset(0, NavigationTokens.contentLiftY),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    spec.icon,
                    size: NavigationTokens.iconSize,
                    color: color,
                  ),
                  const SizedBox(height: NavigationTokens.labelTopGap),
                  Text(spec.label, style: labelStyle),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec({required this.label, required this.icon});

  final String label;
  final IconData icon;
}
