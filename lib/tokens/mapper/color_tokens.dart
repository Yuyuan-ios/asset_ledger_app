import 'package:flutter/material.dart';

/// 全局颜色（跨模块通用）
class AppColors {
  static const Color brand = Color(0xFFE67E22); // 品牌主色
  static const Color scaffoldBg = Color(0xFFF8F8F8); // 页面基础背景色
  static const Color divider = Color(0xFFE6DED8); // 全局分割线颜色

  static const Color cardFill = Color(0xFFF7F4F1); // 卡片填充色
  static const Color cardBorder = Color(0xFFB48A55); // 卡片边框色

  static const Color textPrimary = Color(0xFF2B2B2B); // 主文字色
}

/// Timing 主题色
class TimingColors {
  static const Color expense = Color(0xFF111111); // 支出柱状/负向数据色
  static const Color chartIncome = Color(0xFF459A63); // 图表收入柱深绿
  static const Color cardBorder = Color(0xFFF0F0F0); // 计时卡片边框
  static const Color divider = Color(0xFFD9D9D9); // 计时页分割线
  static const Color textSecondary = Color(0xFF999999); // 次级文字
  static const Color textTertiary = Color(0xFFB0B0B0); // 三级文字/弱提示
  static const Color avatar = Color(0xFFD0D0D0); // 默认头像底色
  static const Color arrow = Color(0xFF333333); // 导航箭头/强调图标色
}

/// Sheet 主题色
class SheetColors {
  static const Color background = Color(0xFFFFFFFF); // 弹窗背景
  static const Color fieldBackground = Color(0xFFF3F4F6); // 输入框填充
  static const Color fieldBorder = Color(0xFFD8DDE5); // 输入框边框
  static const Color handle = Color(0xFFCFC7BE); // 拖拽条
  static const Color hint = Color(0xFF7A7F87); // 提示文字
  static const Color muted = Color(0xFF8E8E8E); // 弱图标/弱文字
  static const Color textPrimary = Color(0xFF1C1C1E); // 弹窗主文字
  static const Color textDim = Color(0xFF888888); // 弹窗弱文字
  static const Color segmentBackground = Color(0xFFD4D9E0); // 分段背景
  static const Color segmentSelected = Color(0xFFE68E22); // 分段选中
  static const Color segmentBorder = Color(0xFFD9CBB5); // 分段边框
  static const Color meterBackground = Color(0xFF2B2B2B); // 码表数字容器背景
  static const Color meterText = Color(0xFFFFFFFF); // 码表数字/符号文字
  static const Color switchTrackOff = Color(0xFFD9D9D9); // 开关关闭背景
  static const Color switchThumb = Color(0xFFFFFFFF); // 开关滑块
  static const Color switchThumbFill = Color(0xFFFFFFFF); // 开关圆点填充
  static const Color switchThumbBorder = Color(0xFF8E8E8E); // 开关圆点描边
  static const Color action = AppColors.brand; // 主按钮色
  static const Color actionOn = Color(0xFFFFFFFF); // 主按钮文字
  static const Color digitHighlight = Color(0xFFB48A55); // 码表高亮
}
