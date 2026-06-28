import 'package:flutter/material.dart';

import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/sheet_tokens.dart';

class SheetFieldPopupToggleIcon extends StatelessWidget {
  const SheetFieldPopupToggleIcon({super.key, required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Icon(
      expanded ? Icons.arrow_drop_up : Icons.arrow_drop_down,
      color: SheetColors.muted,
    );
  }
}

class SheetFieldPopupToggleButton extends StatelessWidget {
  const SheetFieldPopupToggleButton({
    super.key,
    required this.expanded,
    required this.onPressed,
  });

  final bool expanded;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        right: SheetTokens.fieldSuffixRightPadding,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: SheetFieldPopupToggleIcon(expanded: expanded),
      ),
    );
  }
}

MenuStyle sheetFieldPopupMenuStyle({
  double elevation = SheetTokens.suggestMenuElevation,
  double radius = SheetTokens.suggestMenuRadius,
}) {
  return MenuStyle(
    backgroundColor: const WidgetStatePropertyAll<Color>(
      SheetColors.background,
    ),
    elevation: WidgetStatePropertyAll<double>(elevation),
    shape: WidgetStatePropertyAll<OutlinedBorder>(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    ),
  );
}
