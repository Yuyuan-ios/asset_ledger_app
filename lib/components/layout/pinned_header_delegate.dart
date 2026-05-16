import 'package:flutter/material.dart';

class PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  const PinnedHeaderDelegate({required this.child, required double height})
    : minHeight = height,
      maxHeight = height;

  const PinnedHeaderDelegate.extent({
    required this.child,
    required this.minHeight,
    double? maxHeight,
  }) : maxHeight = maxHeight ?? minHeight,
       assert((maxHeight ?? minHeight) >= minHeight);

  final Widget child;
  final double minHeight;
  final double maxHeight;

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant PinnedHeaderDelegate oldDelegate) {
    return child != oldDelegate.child ||
        minHeight != oldDelegate.minHeight ||
        maxHeight != oldDelegate.maxHeight;
  }
}
