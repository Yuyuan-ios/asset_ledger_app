class BottomSheetTokens {
  // ===== 通用底部弹窗：开合动画 =====
  static const Duration animationDuration = Duration(milliseconds: 500);
  static const Duration reverseAnimationDuration = Duration(milliseconds: 320);

  // ===== 通用弹窗壳：容器尺寸与圆角 =====
  static const double heightFactor = 0.92;
  static const double minHeightFactor = 0.2;
  static const double maxHeightFactor = 0.98;
  static const double radius = 16;

  // ===== 通用弹窗壳：内容区与把手间距 =====
  static const double outerHPadding = 8;
  static const double outerTopPadding = 14;
  static const double shellTopGap = 10;
  static const double shellHandleBottomGap = 12;
  static const double shellContentBottomPadding = 16;

  // ===== 通用弹窗壳：标题区与分割线 =====
  static const double dividerThickness = 1;
  static const double headerToDividerGap = 2;
  static const double dividerToContentGap = 18;
  static const double titleSize = 20;

  // ===== 通用弹窗壳：顶部拖拽把手 =====
  static const double handleWidth = 36;
  static const double handleHeight = 5;

  // ===== 通用底部操作区 =====
  static const double footerHorizontal = 25;
  static const double footerContentGap = 8;
  static const double footerBottom = 8;
  static const double actionButtonWidth = 80;
  static const double actionButtonHeight = 39;
  static const double actionButtonRadius = 20;
  static const double actionTextSize = 16;

  // ===== 键盘联动 =====
  static const double keyboardTopOverlap = 20;
}
