import 'package:flutter/material.dart';

class AppColors {
  // Brand / 基础
  static const Color brand = Color(0xFFE67E22); // 你按钮橙色（先用这个）
  static const Color scaffoldBg = Color(0xFFF5F1EE); // 背景（先用一个温白）
  static const Color divider = Color(0xFFE6DED8);

  // Card / Field
  static const Color cardFill = Color(0xFFF7F4F1);
  static const Color cardBorder = Color(0xFFB48A55);

  // Text
  static const Color textPrimary = Color(0xFF2B2B2B);

  // Chart
  static const Color income = Color(0xFF2ECC71);
  static const Color expense = Color(0xFF111111);
}

class AppRadius {
  static const double card = 12;
}

class AppSpace {
  // 页面
  static const double pageHPadding =
      12; // 对齐你Figma padding（先用你当前 kTimingPagePadding 对应值）
  static const double pageVPadding = 12;
  static const double chartHeight = 220;

  // 组件间距
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  // 圆角/高度常用
  static const double fieldHeight = 48;
  static const double tabBarHeight = 64;
}

class AppText {
  // 字号（先按你现有风格，后面用 Figma 再微调）
  static const double title = 20;
  static const double body = 14;
  static const double label = 12;
  static const double big = 18;

  // 重点：你“滚轮数字”那套不在这里，后面单独 token
}
