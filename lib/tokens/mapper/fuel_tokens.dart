class FuelTokens {
  // ===== 燃油页：页面容器（与计时页一致） =====
  static const double homeMaxContainerWidthTrigger = 420; // 宽屏触发阈值
  static const double homeFixedContentWidth = 393; // 宽屏固定内容宽度
  static const double homePageHorizontalPadding = 10; // 页面左右内边距
  static const double homeHeaderBottomGap = 4; // 标题区与内容区间距

  // ===== 燃油页：内容区间距 =====
  static const double homeContentPadding = 0; // 内容区四周内边距（与计时页首卡对齐）
  static const double homeSectionGap = 12; // 分区之间间距
  static const double homeListBottomGap = 24; // 列表底部留白

  // ===== 燃油页：反馈提示 =====
  static const double homeLoadingBottomGap = 10; // 加载条下方间距
  static const double homeErrorBottomGap = 10; // 错误文案下方间距

  // ===== 燃油页：统计卡片 =====
  static const double efficiencyCardHeight = 240; // 设备效率卡高度（对齐计时图表卡）
  static const double summaryCardRadius = 12; // 汇总卡片圆角（对齐计时卡片）
  static const double summaryCardBorderWidth = 1; // 汇总卡片边框粗细（对齐计时卡片）
  static const double summaryCardPadding = 12; // 汇总卡片内边距（对齐计时卡片）
  static const double summaryInnerGap = 12; // 大卡片内上下子容器间距
  static const double summaryInnerPadding = 12; // 子容器内边距
  static const double summaryTotalValueLeftGap = 8; // 年度总计标题与数值间距
  static const double summaryTotalLabelSize = 14; // 本年度总计左侧标题字号
  static const double summaryTotalValueSize = 12; // 本年度总计右侧数值字号
  static const double summaryCardTitleSize = 14; // 燃油卡片标题字号
  static const double summaryCardItemGap = 10; // 汇总卡片标题与内容间距
  static const double summaryCardRowBottomGap = 8; // 汇总卡片条目间距
  static const double summaryCardNameSize = 13; // 设备名称字号
  static const double summaryCardMetricSize = 12; // 指标字号
  static const double summaryLitersColumnWidth = 60; // 右侧 L/h 列固定宽度（右对齐）
  static const double summaryCostColumnWidth = 70; // 右侧 ¥/h 列固定宽度（右对齐）
  static const double summaryMetricColumnGap = 0; // 右侧两列之间的固定间距
  static const double efficiencySingleItemTitleGap = 30; // 单设备时：标题到内容行的垂直间距
  static const double efficiencyRowLeftInset = 16; // 效率内容行左侧内边距（SANY 起始位置）
  static const double efficiencyListBottomPadding = 4; // 设备效率区滚动列表底部留白

  // ===== 燃油页：最近记录 =====
  static const double recordsTrailingGap = 8; // 右侧数值与删除按钮间距
  static const double recordsValueSize = 12; // 列表右侧数值字号
  static const double recordsDeleteIconSize = 20; // 删除图标尺寸
  static const double recordsEmptyVerticalPadding = 20; // 空态上下内边距
}
