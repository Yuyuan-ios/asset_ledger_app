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
  static const double overviewCardShadowBlur = 4; // 总览卡片阴影模糊
  static const double overviewCardShadowOffsetX = 2; // 总览卡片阴影右移
  static const double overviewCardShadowOffsetY = 2; // 总览卡片阴影下移
  static const double overviewCardShadowOpacity = 0.3; // 总览卡片阴影透明度
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
  static const double overviewChartSize = 126; // 圆环图直径（视觉补偿后略大于饼图）
  static const double overviewChartStroke = 20; // 圆环图线宽（加粗）
  static const double overviewChartListGap = 0; // 圆环图与列表间距
  static const double overviewLeftColumnWidth = 160; // 左侧图表列固定宽度（上下对齐）
  static const double overviewChartColumnPadding =
      10; // 左侧图表列内边距（Figma Col_Charts）
  static const double overviewLegendLeftInset =
      0; // 右侧设备行起始与下方汇总左列对齐
  static const double overviewLegendRowGap = 8; // 设备行间距
  static const double overviewLegendNameSize = 14; // 设备名字号
  static const double overviewLegendValueSize = 14; // 金额字号

  static const double overviewRightPaddingTop = 5; // 右侧文案区上内边距
  static const double overviewRightPaddingRight = 0; // 右侧文案区右内边距
  static const double overviewRightPaddingBottom = 0; // 右侧文案区下内边距
  static const double overviewRightPaddingLeft = 10; // 右侧文案区左内边距
  static const double overviewSummaryTopPadding =
      14; // 总应收区域距容器顶部内边距（下调 2px，避免 iOS 文本度量导致溢出）

  // ===== 账户页：总览卡片底部饼图 =====
  static const double overviewPieSize = 116; // 饼图直径
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
  static const FontWeight projectTitleWeight = FontWeight.w700; // 标题字重
  static const double projectFilterFontSize = 15; // 筛选字号

  // ===== 账户页：项目卡片 =====
  static const double projectCardMinHeight = 104; // 项目卡片最小高度（继续轻微收缩底部留白）
  static const double projectCardRadius = 6; // 项目卡片圆角
  static const double projectCardBorderWidth = 1; // 项目卡片描边
  static const double projectCardBottomMargin = 8; // 项目卡片之间的垂直间距
  static const double projectCardPaddingHorizontal = 8; // 项目卡片左右内边距
  static const double projectCardPaddingTop = 10; // 项目卡片顶部内边距
  static const double projectCardTitleFontSize = 18; // 项目名字号
  static const double projectCardDateFontSize = 15; // 日期字号
  static const double projectCardTitleDateGap = 10; // 项目名与日期间距
  static const double projectCardSectionGap = 6; // 标题行到单价行间距
  static const double projectCardRateToStatusGap = 6; // 单价行到实收行间距
  static const double projectCardChipWidth = 102; // 单价标签宽度
  static const double projectCardChipRadius = 16; // 单价标签圆角
  static const double projectCardChipPaddingHorizontal = 4; // 单价标签水平内边距
  static const double projectCardChipPaddingVertical = 8; // 单价标签垂直内边距
  static const double projectCardChipFontSize = 15; // 单价标签字号
  static const double projectCardStatusFontSize = 14; // 实收/剩余字号
  static const double projectCardProgressTopGap = 0; // 文字区与进度条间距
  static const double projectCardProgressHeight = 8; // 进度条高度
  static const double projectCardProgressFillHeight = 6; // 进度条有效高度
  static const double projectCardProgressRadius = 2; // 进度条圆角
  static const double projectCardShadowBlur = 4; // 项目卡片阴影模糊
  static const double projectCardShadowOffsetX = 2; // 项目卡片阴影右移
  static const double projectCardShadowOffsetY = 2; // 项目卡片阴影下移
  static const double projectCardShadowOpacity = 0.3; // 项目卡片阴影透明度
  static const Color projectCardBorderColor = Color(0x4D000000); // 30% 黑色描边
  static const Color projectCardChipColor = Color(0x33999999); // 20% 灰底
  static const Color projectCardProgressTrack = Color(0xFFD9D9D9); // 进度条底色
  static const Color projectCardProgressFill = Color(0xFF32CD32); // 进度条高亮

  // ===== 账户页：项目详情弹窗 =====
  static const double projectDetailSheetHeaderInset = 2; // Header 左右补偿，使最终为 10
  static const double projectDetailSheetTitleSize = 24; // Sheet 标题字号
  static const FontWeight projectDetailSheetTitleWeight =
      FontWeight.w400; // Sheet 标题字重
  static const double projectDetailSheetTitleLineHeight = 1; // Sheet 标题行高
  static const double projectDetailSheetDividerToContentGap =
      12; // Header 到内容间距
  static const double projectDetailContentInset =
      2; // 内容容器左右内边距（Figma Content px=2）
  static const double projectDetailSectionHorizontalPadding = 14; // 项目名行左右内边距
  static const double projectDetailSectionTopPadding =
      0; // 项目名行上内边距（与通用弹窗内容起始间距对齐）
  static const double projectDetailTopSectionGap = 10; // 项目名到设备列表间距
  static const double projectDetailProjectNameSize = 18; // 项目名字号
  static const FontWeight projectDetailProjectNameWeight =
      FontWeight.w400; // 项目名字重
  static const double projectDetailActionSize = 14; // 操作按钮字号
  static const Color projectDetailActionColor = Color(0xFFE68E22); // Figma 橙色
  static const double projectDetailActionRightInset = 14; // 操作列右侧对齐边界
  static const double projectDetailBatchActionWidth = 72; // “批量修改”操作区宽度
  static const double projectDetailRowHeight = 40; // 单价行高度
  static const double projectDetailLabelLeft = 14; // “设备单价”x 坐标
  static const double projectDetailDeviceLeft = 94; // 设备名列 x 坐标
  static const double projectDetailHoursLeft = 217; // 小时列 x 坐标
  static const double projectDetailAmountLeft = 291; // 金额列 x 坐标（拉大与小时列间距）
  static const double projectDetailLabelWidth = 72; // 左侧标签列有效宽度
  static const double projectDetailDeviceWidth = 122; // 设备名列有效宽度
  static const double projectDetailHoursWidth = 58; // 小时列有效宽度
  static const double projectDetailAmountWidth = 48; // 金额列有效宽度
  static const double projectDetailActionWidth = 40; // 操作列有效宽度（保证“修改”单行显示）
  static const double projectDetailLabelSize = 16; // 左侧标签字号
  static const double projectDetailRowTextSize = 14; // 行文字号
  static const double projectDetailProgressTopGap = 14; // 列表到进度文字间距
  static const double projectDetailProgressTextSize = 14; // 进度文字字号
  static const double projectDetailProgressLeftInset = 8; // 进度文案左侧内边距
  static const double projectDetailProgressHeight = 6; // 进度条高度
  static const double projectDetailProgressRadius = 2; // 进度条圆角
  static const double projectDetailDividerTopGap = 12; // 进度条到分割线间距
  static const double projectDetailSectionTitleTopGap = 16; // 顶部分割线到下节标题
  static const double projectDetailSectionTitleSize = 15; // 下节标题字号
  static const FontWeight projectDetailSectionTitleWeight =
      FontWeight.w900; // 下节标题字重

  // ===== 账户页：筛选按钮 =====
  static const double projectFilterRightInset = 16; // 筛选按钮右侧内边距
}
