import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../tokens/mapper/core_tokens.dart';

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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: NavigationTokens.shadowOpacity,
            ),
            blurRadius: NavigationTokens.shadowBlur,
            offset: const Offset(0, NavigationTokens.shadowOffsetY),
          ),
        ],
      ),
      child: SizedBox(
        height: NavigationTokens.barHeight,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Transform.scale(
                    scale: NavigationTokens.contentScale,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: NavigationTokens.assetViewportWidth,
                      height: NavigationTokens.assetViewportHeight,
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.topLeft,
                          minWidth: NavigationTokens.assetWidth,
                          maxWidth: NavigationTokens.assetWidth,
                          minHeight: NavigationTokens.assetHeight,
                          maxHeight: NavigationTokens.assetHeight,
                          child: Transform.translate(
                            offset: Offset(
                              -NavigationTokens.assetOffsetX,
                              -(NavigationTokens.assetOffsetY +
                                  currentIndex *
                                      NavigationTokens.assetVariantStride),
                            ),
                            child: SizedBox(
                              width: NavigationTokens.assetWidth,
                              height: NavigationTokens.assetHeight,
                              child: SvgPicture.asset(
                                NavigationTokens.assetPath,
                                fit: BoxFit.fill,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  5,
                  (index) => Expanded(
                    child: _tapTarget(index: index, label: _labelFor(index)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tapTarget({required int index, required String label}) {
    return Semantics(
      button: true,
      selected: index == currentIndex,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(index),
          borderRadius: BorderRadius.circular(NavigationTokens.itemRadius),
          splashColor: NavigationTokens.interactionOverlay,
          highlightColor: NavigationTokens.interactionOverlay,
          hoverColor: NavigationTokens.interactionOverlay,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  String _labelFor(int index) {
    switch (index) {
      case 0:
        return '计时';
      case 1:
        return '燃油';
      case 2:
        return '账户';
      case 3:
        return '维保';
      case 4:
        return '设备';
      default:
        return '';
    }
  }
}
