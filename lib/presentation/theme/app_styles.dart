import 'package:flutter/material.dart';
import 'app_tokens.dart';

class AppDecorations {
  static BoxDecoration cardBox() => BoxDecoration(
    color: AppColors.cardFill,
    borderRadius: BorderRadius.circular(AppRadius.card),
    border: Border.all(color: AppColors.cardBorder),
  );
}
