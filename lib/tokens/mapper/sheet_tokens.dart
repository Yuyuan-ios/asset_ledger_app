class SheetTokens {
  // ===== 通用弹窗壳：容器尺寸与圆角 =====
  static const double heightFactor = 0.92; // 弹窗高度占屏比例（默认高度）
  static const double minHeightFactor = 0.2; // 弹窗最小高度占比下限（防止过小不可用）
  static const double maxHeightFactor = 0.98; // 弹窗最大高度占比上限（防止超过设计可控范围）
  static const double radius = 16; // 弹窗顶部圆角半径

  // ===== 通用弹窗壳：内容区与把手间距 =====
  static const double outerHPadding = 8; // 弹窗内容区左右基础外边距（大多数字段对齐基线）
  static const double outerTopPadding = 14; // 标题分割线以下内容的顶部基础内边距
  static const double shellTopGap = 10; // 顶部拖拽条上方留白
  static const double shellHandleBottomGap = 12; // 顶部拖拽条与标题栏之间间距
  static const double shellContentBottomPadding =
      16; // 内容区最底部基础内边距（不含安全区与底部操作栏）

  // ===== 通用弹窗壳：标题区与分割线 =====
  static const double headerSideInset = 8; // 标题行左右额外缩进（叠加在 outerHPadding 上）
  static const double dividerSideInset = 8; // 分割线左右缩进
  static const double dividerThickness =
      1; // 分割线粗细（同时用于 Divider height/thickness）
  static const double headerToDividerGap = 2; // 标题行与分割线之间垂直间距
  static const double dividerToContentGap = 18; // 分割线与内容区之间垂直间距

  // ===== 通用弹窗壳：标题文字与关闭按钮 =====
  static const double titleSize = 20; // 标题字号
  static const double closeSize = 24; // 关闭按钮字号（×）
  static const double closeHorizontalPadding = 8; // 关闭按钮水平内边距
  static const double closeVerticalPadding = 0; // 关闭按钮垂直内边距

  // ===== 通用弹窗壳：顶部拖拽把手 =====
  static const double handleWidth = 36; // 顶部拖拽条宽度
  static const double handleHeight = 5; // 顶部拖拽条高度

  // ===== 通用表单字段：输入框基础样式 =====
  static const double fieldHeight = 48; // 通用输入框高度
  static const double fieldRadius = 8; // 通用输入框圆角
  static const double fieldBorderWidth = 0.9; // 通用输入框边框宽度
  static const double fieldTextSize = 18; // 通用输入框正文文字字号
  static const double fieldLabelSize = 14; // 通用输入框浮动标签字号
  static const double fieldContentHPadding = 16; // 通用输入框内容水平内边距
  static const double fieldContentVPadding = 0; // 通用输入框内容垂直内边距
  static const double fieldSuffixRightPadding = 8; // 通用输入框后缀图标右侧内边距

  // ===== 通用底部操作栏：取消/确定按钮 =====
  static const double footerHorizontal = 25; // 底部操作栏左右边距（取消/确定整体对齐）
  static const double footerTopGap = 8; // 内容区与底部操作栏之间的顶部间距
  static const double footerBottom = 0; // 底部操作栏到安全区上沿的基础间距（最终还会叠加安全区 inset）
  static const double footerKeyboardGap = 12; // 键盘弹起时，操作栏与键盘顶边的固定间距
  static const double actionButtonWidth = 80; // 主要按钮固定宽度（确定）
  static const double actionButtonHeight = 39; // 主要按钮固定高度（确定）
  static const double actionButtonRadius = 20; // 主要按钮圆角
  static const double actionTextSize = 16; // 底部操作栏文字字号（取消/确定）

  // ===== 键盘联动：弹窗与键盘视觉过渡 =====
  static const double keyboardTopOverlap = 14; // 键盘弹起时 sheet 轻微下压，减弱键盘顶部圆角视觉

  // ===== 自动补全下拉菜单 =====
  static const double suggestMenuElevation = 4; // 自动补全下拉菜单阴影高度
  static const double suggestMenuRadius = 8; // 自动补全下拉菜单圆角
  static const double suggestMenuMaxHeight = 220; // 自动补全下拉菜单最大高度
  static const double suggestMenuMinWidth = 220; // 自动补全下拉菜单最小宽度
}
