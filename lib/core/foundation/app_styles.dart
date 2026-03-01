import 'package:flutter/material.dart';
import '../../tokens/mapper/core_tokens.dart' as tokens;

class AppDecorations {
  static BoxDecoration cardBox() => BoxDecoration(
    color: tokens.AppColors.cardFill,
    borderRadius: BorderRadius.circular(tokens.AppRadius.card),
    border: Border.all(color: tokens.AppColors.cardBorder),
  );
}
