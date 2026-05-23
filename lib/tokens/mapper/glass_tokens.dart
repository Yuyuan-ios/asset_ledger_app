import 'package:flutter/material.dart';

class GlassTokens {
  const GlassTokens._();

  static const double blur = 22;
  static const int surfaceTopAlpha = 0xE8;
  static const int surfaceBottomAlpha = 0xBC;
  static const Color surfaceTopBackground = Color.fromARGB(
    surfaceTopAlpha,
    255,
    255,
    255,
  );
  static const Color surfaceBottomBackground = Color.fromARGB(
    surfaceBottomAlpha,
    255,
    255,
    255,
  );
  static const Color topBorderColor = Color(0x66FFFFFF);
}
