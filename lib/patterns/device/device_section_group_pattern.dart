import 'package:flutter/material.dart';

import '../../core/foundation/typography.dart';
import '../../tokens/mapper/device_tokens.dart';

class DeviceSectionGroup extends StatelessWidget {
  const DeviceSectionGroup({
    super.key,
    required this.title,
    required this.children,
    this.padding = EdgeInsets.zero,
    this.titleToContentGap = DeviceTokens.sectionTitleToCardGap,
    this.itemGap = DeviceTokens.sectionTitleToCardGap,
  });

  final String title;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final double titleToContentGap;
  final double itemGap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.body(
              context,
              fontSize: DeviceTokens.sectionTitleFontSize,
              fontWeight: DeviceTokens.sectionTitleFontWeight,
              color: DeviceTokens.actionCardTitleColor.withValues(
                alpha: DeviceTokens.sectionTitleAlpha,
              ),
            ),
          ),
          SizedBox(height: titleToContentGap),
          ..._childrenWithGap(children, itemGap),
        ],
      ),
    );
  }

  List<Widget> _childrenWithGap(List<Widget> widgets, double gap) {
    if (widgets.isEmpty) return const [];
    final out = <Widget>[];
    for (var i = 0; i < widgets.length; i++) {
      if (i > 0) out.add(SizedBox(height: gap));
      out.add(widgets[i]);
    }
    return out;
  }
}
