import 'package:flutter/material.dart';

import 'color_tokens.dart';
import 'radius_tokens.dart';

class SummaryCardTokens {
  // ===== 主页上方卡片：共享视觉 chrome =====
  static const Color cardBackground = SheetColors.background; // 卡片背景色
  static const double cardRadius = RadiusTokens.card; // 卡片圆角（对齐计时卡片）
  static const Color cardBorderColor = TimingColors.cardBorder; // 卡片边框色
  static const double cardBorderWidth = 0; // 卡片边框粗细
  static const Color cardShadowColor = Color(0x00000000); // 卡片阴影色
  static const double cardShadowBlur = 0; // 卡片阴影模糊
  static const double cardShadowOffsetX = 0; // 卡片阴影 X 偏移
  static const double cardShadowOffsetY = 0; // 卡片阴影 Y 偏移

  static BorderRadius get cardBorderRadius => BorderRadius.circular(cardRadius);

  static BoxBorder? get cardBorder {
    if (cardBorderWidth <= 0) return null;
    return Border.all(color: cardBorderColor, width: cardBorderWidth);
  }

  static List<BoxShadow>? get cardShadows {
    if (cardShadowBlur <= 0) return null;
    return [
      BoxShadow(
        color: cardShadowColor,
        blurRadius: cardShadowBlur,
        offset: const Offset(cardShadowOffsetX, cardShadowOffsetY),
      ),
    ];
  }

  static BoxDecoration cardDecoration({Color color = cardBackground}) {
    return BoxDecoration(
      color: color,
      border: cardBorder,
      borderRadius: cardBorderRadius,
      boxShadow: cardShadows,
    );
  }

  // ===== 油电/维保页：统计卡共享排版 =====
  static const double cardPadding = 24; // 统计卡垂直内边距（油电/维保统一）
  static const double cardHorizontalPadding = 12; // 统计卡左右内边距（对齐计时/账户）
  static const double cardVerticalPadding = cardPadding; // 统计卡上下内边距
  static const double titleFontSize = 15; // 统计卡标题字号
  static const double titleToContentGap = 10; // 标题与内容间距
  static const double rowLeftInset = 16; // 内容行左侧内边距
  static const double rowBottomGap = 8; // 内容行间距
  static const double rowLabelFontSize = 14; // 内容行左侧标签字号
  static const double rowRateGap = 48; // 内容行标签与中间费率间距
  static const double rowValueFontSize = 13; // 内容行右侧数值字号
  static const double totalLabelFontSize = 15; // 合计/年度总计标签字号
  static const double totalValueFontSize = 14; // 合计/年度总计数值字号
}
