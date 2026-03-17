import 'package:flutter/material.dart';

/// Timing 弹窗专用 token（仅放业务特有，不放通用 sheet/field）
class TimingTokens {
  // ===== 计时主页：页面容器与整体间距 =====
  static const double homeMaxContainerWidthTrigger = 420; // 主页宽屏触发阈值
  static const double homeFixedContentWidth = 393; // 主页内容固定宽度（宽屏）
  static const double homePageHorizontalPadding = 10; // 主页左右内边距
  static const double homeHeaderBottomGap = 4; // 主页标题区下方间距
  static const double homeChartTopGap = 8; // 图表上方间距
  static const double homeRecordsTitleTopGap = 2; // 最近记录标题上方间距
  static const double homeBottomGap = 16; // 列表尾部留白
  static const double homeLoadingBottomGap = 8; // 加载条下方间距
  static const double homeErrorBottomGap = 8; // 错误文案下方间距
  static const double homeErrorFontSize = 12; // 错误文案字号

  // ===== 计时主页：顶部标题与新建按钮 =====
  static const double headerHorizontalPadding = 12; // 主页标题区左右内边距
  static const double headerBottomPadding = 8; // 主页标题区下内边距
  static const double headerTitleSize = 24; // “计时”标题字号
  static const double headerTitleLineHeight = 1.2; // “计时”标题行高
  static const double headerAddButtonHeight = 38; // “+ 新建”按钮高度
  static const double headerAddButtonHorizontalPadding = 16; // “+ 新建”按钮水平内边距
  static const double headerAddButtonTextSize = 20; // “+ 新建”按钮字号
  static const double headerAddButtonTextLineHeight = 1; // “+ 新建”按钮行高

  // ===== 计时主页：年度图表卡片 =====
  static const double chartCardHeight = 240; // 图表卡片高度
  static const double chartCardRadius = 12; // 图表卡片圆角
  static const double chartCardBorderWidth = 1; // 图表卡片边框宽度
  static const double chartPaddingLeft = 12; // 图表卡片左内边距
  static const double chartPaddingTop = 4; // 图表卡片上内边距
  static const double chartPaddingRight = 12; // 图表卡片右内边距
  static const double chartPaddingBottom = 6; // 图表卡片下内边距
  static const double chartHeaderHeight = 28; // 图表标题栏高度
  static const double chartArrowFontSize = 20; // 年份左右箭头字号
  static const double chartYearFontSize = 18; // 年份字号
  static const double chartPlotTopPadding = 4; // 图表区域上内边距
  static const double chartBarWidth = 6; // 单柱宽度
  static const double chartBarPairGap = 1; // 收入/支出柱间距
  static const double chartMonthTopGap = 2; // 柱体与月份文字间距
  static const double chartMonthFontSize = 11; // 月份字号
  static const double chartLegendTopGap = 4; // 图例上方间距
  static const double chartLegendGap = 10; // 两组图例间距
  static const double chartLegendSwatchSize = 12; // 图例色块尺寸
  static const double chartLegendLabelGap = 6; // 图例色块与文案间距
  static const double chartLegendValueTopGap = 2; // 图例标题与金额间距
  static const double chartLegendLabelFontSize = 11; // 图例标题字号
  static const double chartLegendValueFontSize = 12; // 图例金额字号
  static const double chartDividerThickness = 1; // 图表分割线粗细

  // ===== 计时主页：最近记录标题与列表 =====
  static const double recordsTitleFontSize = 18; // 最近记录标题字号
  static const FontWeight recordsTitleFontWeight = FontWeight.w700; // 最近记录标题字重
  static const double recordsTitleLineHeight = 1; // 最近记录标题行高
  static const double emptyStateHeight = 180; // 空态区域高度
  static const double emptyStateTitleFontSize = 13; // 空态主文案字号
  static const double emptyStateSubtitleTopGap = 6; // 空态主副文案间距
  static const double emptyStateSubtitleFontSize = 12; // 空态副文案字号
  static const double dateHeaderFontSize = 13; // 日期分组标题字号
  static const double dateHeaderLineHeight = 1.2; // 日期分组标题行高
  static const double dateHeaderLeftInset = 10; // 日期分组标题左偏移
  static const double recordRowHeight = 60; // 单条记录行高
  static const double recordRowPaddingLeft = 10; // 单条记录左内边距
  static const double recordRowPaddingRight = 2; // 单条记录右内边距
  static const double recordAvatarSize = 45; // 记录头像占位圆尺寸
  static const double recordAvatarOffsetY = -1; // 记录头像纵向微调
  static const double recordAvatarRightGap = 10; // 头像与文本间距
  static const double recordTitleFontSize = 14; // 联系人·地址字号
  static const double recordTitleLineHeight = 1.1; // 联系人·地址行高
  static const double recordSubTitleTopGap = 6; // 主副标题间距
  static const double recordSubTitleFontSize = 14; // 副标题字号
  static const double recordValueLeftGap = 8; // 左右信息区间距
  static const double recordValueFontSize = 14; // 右侧数值字号
  static const double recordValueBottomGap = 8; // 右侧两行数值间距
  static const double recordHoursIncomeGap = 8; // 工时与金额之间间距（租金模式）
  static const double recordDividerThickness = 1; // 记录分组分割线粗细

  // ===== 全局底部导航栏（计时页样式）=====
  static const double tabBarShadowBlur = 8; // 底栏阴影模糊半径
  static const double tabBarShadowOffsetY = -2; // 底栏阴影 Y 偏移
  static const double tabBarBorderThickness = 1; // 底栏顶部边线粗细
  static const double tabBarHorizontalPadding = 16; // 底栏左右内边距
  static const double tabBarTopPadding = 8; // 底栏上内边距
  static const double tabItemRadius = 8; // 底栏单项点击圆角
  static const double tabItemTopPadding = 2; // 底栏单项上内边距
  static const double tabIconDefaultSize = 26; // 底栏默认图标尺寸
  static const double tabIconBuildSize = 30; // 维保图标尺寸
  static const double tabLabelTopGap = 4; // 图标与文案间距
  static const double tabLabelFontSize = 12; // 底栏文案字号
  static const double tabLabelLineHeight = 1; // 底栏文案行高

  // ===== 计时弹窗：表单主布局 =====
  static const double contentGap = 18; // 表单区标准纵向间距（字段与字段之间）
  static const double twoColumnGap = 6; // “联系人 + 使用地址”双列之间的水平间距
  static const int contactFieldFlex = 170; // 双列里“联系人”所占 flex
  static const int addressFieldFlex = 201; // 双列里“使用地址/工地”所占 flex

  // ===== 计时弹窗：工时/租金分段选择器 =====
  static const double segmentHeight = 42; // 工时/租金分段控件总高度
  static const double segmentInset = 2; // 分段控件外壳内边距
  static const double segmentItemHeight = 38; // 单个分段项高度
  static const double segmentRadius = 12; // 分段控件圆角
  static const double segmentTextSize = 16; // 分段项文本字号
  static const double segmentCheckSize = 14; // 选中态勾号字号
  static const double segmentCheckRightGap = 6; // 选中态勾号与文字间距

  // ===== 计时弹窗：日期行与日期选择弹窗 =====
  static const double dateRowIconSize = 22; // 日期选择器图标大小
  static const double dateRowTextSize = 38 / 2; // 日期选择器文本字号
  static const double dateRowGap = 12; // 日期图标与文本间距
  static const double dateDialogInsetH = 26; // 日期弹窗距屏幕左右边距
  static const double dateDialogInsetV = 80; // 日期弹窗距屏幕上下边距
  static const double dateDialogRadius = 16; // 日期弹窗圆角
  static const double dateDialogMaxWidth = 340; // 日期弹窗最大宽度
  static const double dateDialogPaddingH = 10; // 日期弹窗内容左右内边距
  static const double dateDialogPaddingTop = 8; // 日期弹窗内容上内边距
  static const double dateDialogPaddingBottom = 6; // 日期弹窗内容下内边距
  static const double dateDialogActionTopGap = 4; // 日历与底部按钮行间距（与标题区间距一致）
  static const double dateDialogActionGap = 6; // Cancel 与 OK 按钮间距
  static const double dateDialogSectionGap = 4; // 标题、星期、日期区之间统一垂直间距
  static const double dateDialogWeekdayFontSize = 18; // 星期标题字号
  static const double dateDialogDayFontSize = 18; // 日期字号
  static const double dateDialogDayCellSize = 44; // 日期单元尺寸（圆形高宽）
  static const double dateDialogGridMainGap = 8; // 日期网格纵向间距
  static const double dateDialogGridCrossGap = 6; // 日期网格横向间距
  static const double dateDialogMonthFontSize = 18; // 月份标题字号

  // ===== 计时弹窗：开始/结束工作时间码表 =====
  static const double meterLabelSize = 12; // 码表标题字号（开始/结束工作时间）
  static const double meterLabelHeight = 16; // 码表标题区域固定高度
  static const double meterLabelLeftShift = 12; // 码表标题整体向左微调
  static const double meterLabelBottomGap = 6; // 码表标题与数字滚轮容器之间间距
  static const double meterDotSize = 20; // 小数点字号
  static const double meterDotSlotWidth = 10; // 小数点占位宽度（用于整体宽度对齐计算）
  static const double meterCellSize = 40; // 单个数字位容器尺寸（宽高）
  static const double meterItemExtent =
      40; // 滚轮单项高度（CupertinoPicker itemExtent）
  static const double meterSelectedTextSize = 20; // 当前选中数字字号
  static const double meterUnselectedTextSize = 18; // 未选中数字字号
  static const double meterContainerHeight = 55; // 码表父容器高度（开始/结束共用）
  static const double meterContainerRadius = 8; // 码表整体输入框圆角
  static const double meterContainerHPadding = 8; // 码表整体输入框水平内边距
  static const double meterContainerVPadding = 8; // 码表整体输入框垂直内边距
  static const double meterGap = 10; // 数字位之间标准间距
  static const double meterDecimalGap = 8; // 小数点两侧额外间距
  static const double meterUnitLeftGap = 20; // 码表单位与数字滚轮的左间距
  static const double meterUnitDownShift = 10; // 码表单位向下偏移
  static const double meterWheelDiameterRatio = 2.4; // 滚轮直径比例（影响透视弧度）
  static const int meterRollbackDebounceMs = 1000; // 结束码表停止滑动后回滚校验延迟
  static const int meterRollbackAnimMs = 420; // 码表自动回滚动画时长（毫秒）

  // ===== 计时弹窗：底部包油/包电开关设计 =====
  static const double switchCardMinHeight = 40; // “包油/包电”卡片最小高度
  static const double switchRowRightInset = 8; // 开关组到父容器右侧内边距
  static const double switchCardVPadding = 0; // “包油/包电”行垂直内边距
  static const double switchTitleSize = 13; // “包油/包电”主标题字号
  static const double switchDescSize = 11; // “包油/包电”说明小字字号
  static const double switchInlineGap = 6; // “包油/包电”图标、标题、开关之间间距
  static const double switchDescTopGap = 2; // 主行与说明小字的垂直间距

  // ===== 计时弹窗：开关轨道与滑块 =====
  static const double switchTrackWidth = 52; // 开关轨道宽度
  static const double switchTrackHeight = 32; // 开关轨道高度
  static const double switchTrackInset = 2; // 开关轨道内边距（上下 2）
  static const double switchThumbSize = 28; // 开关滑块尺寸
  static const double switchTrackBorderWidth = 1; // 开关轨道边框宽度

  // ===== 计时弹窗：数字滚轮单元格描边 =====
  static const double digitCellRadius = 2; // 数字滚轮单格边角半径
  static const double digitOverlayRadius = 8; // 数字滚轮选中覆盖层圆角
  static const double digitHighlightBorderWidth = 0.9; // 数字滚轮高亮线宽（弱化边框感）

  // ===== 计时弹窗：底部小提示（校验失败反馈）=====
  static const double tipBottomGap = 8; // 弹窗底部小提示与操作栏之间间距
}
