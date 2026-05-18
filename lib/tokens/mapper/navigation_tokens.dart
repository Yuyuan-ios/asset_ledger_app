import 'package:flutter/material.dart'; // 引入 Flutter 基础 Material 类型，供颜色常量使用

/// 全局底部导航栏 token（从业务页 token 中拆出，避免继续挂在 timing 下）
class NavigationTokens {
  // 底部导航栏相关设计 token 的集中定义类
  static const double barHeight = 90; // 底部导航栏主体高度
  static const double itemRadius = 12; // 单个 Tab 点击区域的圆角半径
  static const double barHorizontalPadding = 10; // 底部导航栏左右内边距
  static const double contentTopPadding = 8; // 图标文字内容距离导航栏顶部的内边距
  static const double contentBottomPadding = 10; // 图标文字内容距离导航栏底部的内边距
  static const double contentLiftY = -8; // 图标文字组整体在 Y 方向上的上移量
  static const double iconSize = 32; // 底部导航图标尺寸
  static const double labelTopGap = 4; // 图标与文字标签之间的垂直间距
  static const double labelFontSize = 12; // 底部导航文字标签字号
  static const double inactiveAlpha = 0.48; // 未选中 Tab 的透明度

  static const String assetPath =
      'assets/navigation/component_tab_bar.svg'; // 底部导航设计参考 SVG 资源路径
  static const double assetWidth = 430; // 设计参考 SVG 的原始宽度
  static const double assetHeight = 570; // 设计参考 SVG 的原始高度
  static const double assetViewportWidth = 390; // 设计参考中单个导航视口宽度
  static const double assetViewportHeight = 90; // 设计参考中单个导航视口高度
  static const double assetOffsetX = 20; // 设计参考资源在 X 方向的偏移
  static const double assetOffsetY = 20; // 设计参考资源在 Y 方向的偏移
  static const double assetVariantStride = 110; // 设计参考中不同状态变体的纵向间隔
  static const double contentScale = 0.92; // 底部导航内容相对设计参考的缩放比例

  static const double glassBlur = 22; // 贴底玻璃栏背景模糊强度
  static const double topBorderWidth = 0.6; // 贴底玻璃栏顶部高光线粗细

  static const Color glassTopBackground = Color(0xE8FFFFFF); // 顶部更亮的玻璃高光
  static const Color glassBottomBackground = Color(0xD0FFFFFF); // 底部半透明白色玻璃
  static const Color topBorderColor = Color(0x66FFFFFF); // 半透明顶部高光线
  static const Color topShadowColor = Color(0x1C503C28); // 顶部柔和阴影
  static const Color ambientShadowColor = Color(0x0D503C28); // 外部轻微环境阴影

  static const Color interactionOverlay =
      Colors.transparent; // Tab 点击/悬停/高亮时的覆盖层颜色
} // NavigationTokens 定义结束
