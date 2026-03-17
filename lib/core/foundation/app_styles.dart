import 'package:flutter/material.dart';
import '../../tokens/mapper/core_tokens.dart' as tokens;

/// Legacy decoration helpers.
///
/// Currently kept for compatibility; not exported by `typography.dart`.
class AppDecorations {
  static BoxDecoration cardBox() => BoxDecoration(
    color: tokens.AppColors.cardFill,
    borderRadius: BorderRadius.circular(tokens.RadiusTokens.card),
    border: Border.all(color: tokens.AppColors.cardBorder),
  );
}
