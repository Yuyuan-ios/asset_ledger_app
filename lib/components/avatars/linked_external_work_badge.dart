import 'package:flutter/material.dart';

import '../../tokens/mapper/core_tokens.dart';

class LinkedExternalWorkBadge extends StatelessWidget {
  const LinkedExternalWorkBadge({
    super.key,
    this.size = 18,
    this.iconSize = 11,
    this.borderColor,
    this.borderWidth = 2,
    this.tooltip = '已关联外协记录',
  });

  final double size;
  final double iconSize;
  final Color? borderColor;
  final double borderWidth;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final border = borderColor == null
        ? null
        : Border.all(color: borderColor!, width: borderWidth);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        label: tooltip,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.brand,
            shape: BoxShape.circle,
            border: border,
          ),
          alignment: Alignment.center,
          child: Icon(Icons.link, size: iconSize, color: Colors.white),
        ),
      ),
    );
  }
}
