class FuelTokens {
  // ===== 油电页：页面容器（与计时页一致） =====
  static const double homeMaxContainerWidthTrigger = 420; // 宽屏触发阈值
  static const double homeFixedContentWidth = 393; // 宽屏固定内容宽度
  static const double homePageHorizontalPadding = 10; // 页面左右内边距
  static const double homeHeaderBottomGap = 4; // 标题区与内容区间距

  // ===== 油电页：内容区间距 =====
  static const double homeContentPadding = 0; // 内容区四周内边距（与计时页首卡对齐）
  static const double homeSectionGap = 12; // 分区之间间距
  static const double homeListBottomGap = 24; // 列表底部留白
  static const double recordsTitleTopGap = 8; // 最近记录标题与列表间距
  static const double pinnedFilterHeight = 48; // 吸顶筛选输入框固定高度
  static const double pinnedRecordsHeaderHeight = 87; // 筛选 + 最近记录组合吸顶栏高度

  // ===== 油电页：反馈提示 =====
  static const double homeLoadingBottomGap = 10; // 加载条下方间距
  static const double homeErrorBottomGap = 10; // 错误文案下方间距

  // ===== 油电页：统计卡片 =====
  static const double efficiencyCardHeight = 240; // 设备效率卡高度（对齐计时图表卡）
  static const double summaryInnerGap = 12; // 大卡片内上下子容器间距
  static const double summaryTotalValueLeftGap = 8; // 年度总计标题与数值间距
  static const double summaryMetricColumnGap = 18; // 设备效率行右侧指标文字之间的可见间距
  static const double efficiencySingleItemTitleGap = 30; // 单设备时：标题到内容行的垂直间距
  static const double efficiencyListBottomPadding = 4; // 设备效率区滚动列表底部留白
}
