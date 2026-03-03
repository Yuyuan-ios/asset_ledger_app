import 'package:flutter/material.dart';

/// 全局底部导航栏 token（从业务页 token 中拆出，避免继续挂在 timing 下）
class NavigationTokens {
  static const double barHeight = 90;
  static const double itemRadius = 8;

  static const String assetPath = 'assets/navigation/component_tab_bar.svg';
  static const double assetWidth = 430;
  static const double assetHeight = 570;
  static const double assetViewportWidth = 390;
  static const double assetViewportHeight = 90;
  static const double assetOffsetX = 20;
  static const double assetOffsetY = 20;
  static const double assetVariantStride = 110;
  static const double contentScale = 0.92;

  static const double shadowBlur = 8;
  static const double shadowOffsetY = -2;
  static const double shadowOpacity = 0.25;

  static const Color interactionOverlay = Colors.transparent;
}
