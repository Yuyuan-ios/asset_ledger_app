import 'package:flutter/widgets.dart';

bool isZeroLikeNumericText(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return false;
  final value = double.tryParse(trimmed);
  return value != null && value == 0;
}

void selectAllIfZeroLike(TextEditingController controller) {
  if (!isZeroLikeNumericText(controller.text)) return;
  controller.selection = TextSelection(
    baseOffset: 0,
    extentOffset: controller.text.length,
  );
}
