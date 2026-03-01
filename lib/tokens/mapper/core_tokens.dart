import 'package:flutter/material.dart';

class AppColors {
  // ===== 全局品牌与基础背景 =====
  static const Color brand = Color(0xFFE67E22); // 品牌主色（全局橙）
  static const Color scaffoldBg = Color(0xFFF8F8F8); // 页面基础背景色
  static const Color divider = Color(0xFFE6DED8); // 全局分割线颜色

  // ===== 全局卡片与输入框基础色 =====
  static const Color cardFill = Color(0xFFF7F4F1); // 卡片填充色
  static const Color cardBorder = Color(0xFFB48A55); // 卡片边框色

  // ===== 全局文字主色 =====
  static const Color textPrimary = Color(0xFF2B2B2B); // 主文字色

  // ===== 图表与计时主页扩展色 =====
  static const Color income = Color(0xFF2ECC71); // 收入柱状/正向数据色
  static const Color expense = Color(0xFF111111); // 支出柱状/负向数据色
  static const Color timingChartIncome = Color(0xFF82C99E); // 计时图表收入柱浅绿
  static const Color timingCardBorder = Color(0xFFF0F0F0); // 计时卡片边框
  static const Color timingDivider = Color(0xFFD9D9D9); // 计时页分割线
  static const Color timingTextSecondary = Color(0xFF999999); // 次级文字
  static const Color timingTextTertiary = Color(0xFFB0B0B0); // 三级文字/弱提示
  static const Color timingAvatar = Color(0xFFD0D0D0); // 默认头像底色
  static const Color timingArrow = Color(0xFF333333); // 导航箭头/强调图标色

  // ===== 计时弹窗（Sheet）语义色 =====
  static const Color sheetBackground = Color(0xFFFFFFFF); // 弹窗背景
  static const Color sheetFieldBackground = Color(0xFFF3F4F6); // 弹窗输入框填充
  static const Color sheetFieldBorder = Color(0xFFD8DDE5); // 弹窗输入框边框
  static const Color sheetHandle = Color(0xFFCFC7BE); // 弹窗顶部拖拽条
  static const Color sheetHint = Color(0xFF7A7F87); // 提示文字色
  static const Color sheetMuted = Color(0xFF8E8E8E); // 弱图标/弱文字色
  static const Color sheetTextPrimary = Color(0xFF1C1C1E); // 弹窗主文字色
  static const Color sheetTitle = Color(0xFF1C1C1E); // 弹窗标题色
  static const Color sheetTextDim = Color(0xFF888888); // 弹窗弱文字色
  static const Color sheetSegmentBackground = Color(0xFFD4D9E0); // 分段控件背景
  static const Color sheetSegmentSelected = Color(0xFFE68E22); // 分段控件选中背景
  static const Color sheetSegmentBorder = Color(0xFFD9CBB5); // 分段控件边框
  static const Color sheetSwitchCardBorder = Color(0xFFCFC7BE); // 开关容器描边
  static const Color sheetSwitchThumb = Color(0xFF8E7D6E); // 开关滑块色
  static const Color sheetSwitchTrack = Color(0xFFD9D9D9); // 开关轨道色
  static const Color sheetAction = brand; // 弹窗主按钮色（复用品牌色）
  static const Color sheetActionOn = Color(0xFFFFFFFF); // 主按钮文字色
  static const Color sheetDigitHighlight = Color(0xFFB48A55); // 码表高亮色
}

class AppRadius {
  // ===== 全局圆角尺寸 =====
  static const double card = 12; // 全局卡片圆角
}

class AppSpacing {
  // ===== 全局间距尺寸 =====
  static const double pagePadding = 16; // 页面左右标准内边距
  static const double sectionGap = 12; // 模块间标准纵向间距
}

class AppDurations {
  // ===== 全局动效/反馈时长 =====
  static const Duration snackBar = Duration(seconds: 2); // Snackbar 展示时长
}

class DialogTokens {
  // ===== 通用对话框样式 =====
  static const double radius = 16; // 通用对话框圆角
  static const double insetHorizontal = 24; // 对话框水平外边距
  static const double insetVertical = 24; // 对话框垂直外边距
}
