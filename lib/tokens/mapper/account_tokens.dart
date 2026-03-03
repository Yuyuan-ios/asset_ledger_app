import 'package:flutter/material.dart';

import 'color_tokens.dart';

class AccountTokens {
  // ===== 账户页：页面容器与整体间距（对齐计时页）=====
  static const double homeMaxContainerWidthTrigger = 420; // 宽屏触发阈值
  static const double homeFixedContentWidth = 393; // 宽屏固定内容宽度
  static const double homePageHorizontalPadding = 10; // 页面左右内边距
  static const double homeTopGap = 0; // 顶部安全区到首卡片的间距
  static const double homeBottomGap = 84; // 底部导航上方留白

  // ===== 账户页：总览卡片 =====
  static const double overviewCardHeight = 300; // 总览卡片高度
  static const double overviewCardRadius = 12; // 总览卡片圆角
  static const double overviewCardBorderWidth = 1; // 总览卡片边框宽度
  static const double overviewCardShadowBlur = 1; // 总览卡片阴影模糊
  static const double overviewCardShadowOffsetX = 1; // 总览卡片阴影右移
  static const double overviewCardShadowOffsetY = 1; // 总览卡片阴影下移
  static const double overviewCardShadowOpacity = 0.25; // 总览卡片阴影透明度
  static const double overviewCardPaddingLeft = 12; // 总览卡片左内边距
  static const double overviewCardPaddingTop = 0; // 总览卡片上内边距
  static const double overviewCardPaddingRight = 12; // 总览卡片右内边距
  static const double overviewCardPaddingBottom = 8; // 总览卡片下内边距
  static const double overviewTitleFontSize = 18; // 总览标题字号
  static const FontWeight overviewTitleWeight = FontWeight.w700; // 总览标题字重
  static const double overviewTitleLetterSpacing = 0; // 总览标题字间距
  static const double overviewDividerThickness = 1; // 总览标题分割线厚度
  static const Color overviewCardBorderColor = Color(0x4D000000); // 30% 黑色描边

  // ===== 账户页：总览卡片中部（圆环图 + 设备列表）=====
  static const double overviewMiddleTopGap = 0; // 标题到中部图表间距
  static const double overviewChartSize = 120; // 圆环图直径（对齐饼图）
  static const double overviewChartStroke = 20; // 圆环图线宽（加粗）
  static const double overviewChartListGap = 0; // 圆环图与列表间距
  static const double overviewLeftColumnWidth = 160; // 左侧图表列固定宽度（上下对齐）
  static const double overviewChartColumnPadding =
      10; // 左侧图表列内边距（Figma Col_Charts）
  static const double overviewLegendDotSize = 8; // 设备色块圆点
  static const double overviewLegendDotGap = 6; // 色块与标题间距
  static const double overviewLegendRowGap = 8; // 设备行间距
  static const double overviewLegendNameSize = 14; // 设备名字号
  static const double overviewLegendValueSize = 14; // 金额字号

  static const double overviewRightPaddingTop = 5; // 右侧文案区上内边距
  static const double overviewRightPaddingRight = 0; // 右侧文案区右内边距
  static const double overviewRightPaddingBottom = 0; // 右侧文案区下内边距
  static const double overviewRightPaddingLeft = 10; // 右侧文案区左内边距
  static const double overviewSummaryTopPadding = 16; // 总应收区域距容器顶部内边距

  // ===== 账户页：总览卡片底部饼图 =====
  static const double overviewPieSize = 120; // 饼图直径
  static const double overviewPieTopGap = 16; // 中部到饼图上方间距
  static const Color overviewPieReceived =
      TimingColors.chartIncome; // 已实收占比（对齐进度条绿）
  static const Color overviewPieRemaining = Color(0xFFF06161); // 剩余占比（Figma 红色）
  static const double overviewPieBorderWidth = 1; // 饼图描边
  static const Color overviewPieBorderColor = Color(0x1A000000); // 饼图描边色（10% 黑）
  static const double overviewPieDividerWidth = 3; // 饼图分割线宽度
  static const double overviewPieLabelSize = 14; // 饼图百分比字号
  static const FontWeight overviewPieLabelWeight = FontWeight.w400; // 饼图百分比字重
  static const double overviewPieLabelRadiusRatio = 0.6; // 百分比文字半径比例
  static const double overviewPieLabelMinRatio = 0.15; // 小于该比例不显示文字

  // ===== 账户页：设备用色（冷色系色板，避免误用红/绿）=====
  static const Color overviewDeviceColorSky = Color(0xFF5AA9F8); // 天空蓝
  static const Color overviewDeviceColorIndigo = Color(0xFF4C6EF5); // 靛蓝
  static const Color overviewDeviceColorAmber = Color(0xFFFFC046); // 琥珀黄
  static const Color overviewDeviceColorViolet = Color(0xFFB25CFF); // 紫罗兰
  static const Color overviewDeviceColorSlate = Color(0xFF9AA0A6); // 石板灰
  static const List<Color> overviewChartPalette = <Color>[
    overviewDeviceColorSky,
    overviewDeviceColorIndigo,
    overviewDeviceColorAmber,
    overviewDeviceColorViolet,
    overviewDeviceColorSlate,
  ];

  // ===== 账户页：项目列表标题区（对齐计时页“最近记录”）=====
  static const double projectTitleTopGap = 8; // 总览卡片与标题区间距
  static const double projectListTopGap = 8; // 标题区与项目列表间距
  static const double projectTitleFontSize = 18; // 标题字号
  static const double projectTitleLineHeight = 1; // 标题行高
  static const FontWeight projectTitleWeight = FontWeight.w400; // 标题字重
  static const double projectFilterFontSize = 15; // 筛选字号

  // ===== 账户页：项目卡片 =====
  static const double projectCardMinHeight = 123; // 项目卡片高度
  static const double projectCardRadius = 6; // 项目卡片圆角
  static const double projectCardBorderWidth = 1; // 项目卡片描边
  static const double projectCardBottomMargin = 8; // 项目卡片之间的垂直间距
  static const double projectCardPaddingHorizontal = 8; // 项目卡片左右内边距
  static const double projectCardPaddingVertical = 10; // 项目卡片上下内边距
  static const double projectCardTitleFontSize = 18; // 项目名字号
  static const double projectCardDateFontSize = 15; // 日期字号
  static const double projectCardTitleDateGap = 10; // 项目名与日期间距
  static const double projectCardSectionGap = 8; // 标题行到单价行间距
  static const double projectCardRateToStatusGap = 12; // 单价行到实收行间距
  static const double projectCardChipWidth = 102; // 单价标签宽度
  static const double projectCardChipRadius = 16; // 单价标签圆角
  static const double projectCardChipPaddingHorizontal = 4; // 单价标签水平内边距
  static const double projectCardChipPaddingVertical = 8; // 单价标签垂直内边距
  static const double projectCardChipFontSize = 15; // 单价标签字号
  static const double projectCardStatusFontSize = 14; // 实收/剩余字号
  static const double projectCardProgressTopGap = 1; // 文字区与进度条间距
  static const double projectCardProgressHeight = 8; // 进度条高度
  static const double projectCardProgressFillHeight = 6; // 进度条有效高度
  static const double projectCardProgressRadius = 2; // 进度条圆角
  static const Color projectCardBorderColor = Color(0x4D000000); // 30% 黑色描边
  static const Color projectCardChipColor = Color(0x33999999); // 20% 灰底
  static const Color projectCardProgressTrack = Color(0xFFD9D9D9); // 进度条底色
  static const Color projectCardProgressFill = Color(0xFF32CD32); // 进度条高亮

  // ===== 账户页：项目详情弹窗 =====
  static const double projectDetailRateTitleLeftInset = 24; // 设备单价左侧内边距
  static const double projectDetailRateLabelGap = 24; // 设备单价与设备列间距
  static const double projectDetailDeviceNameLeftInset = 0; // 设备名称额外左侧内边距

  // ===== 账户页：筛选按钮 =====
  static const double projectFilterRightInset = 16; // 筛选按钮右侧内边距
}
