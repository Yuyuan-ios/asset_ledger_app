import 'package:flutter/material.dart';

import '../../../core/foundation/app_typography.dart';
import '../../../tokens/mapper/core_tokens.dart';
import '../../../tokens/mapper/timing_tokens.dart';

class DeviceSubpageAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const DeviceSubpageAppBar({super.key, required this.title});

  static const double toolbarHeight =
      TimingTokens.headerAddButtonHeight + TimingTokens.headerBottomPadding;

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(toolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: toolbarHeight,
      backgroundColor: AppColors.scaffoldBg,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      title: Text(
        title,
        style: AppTypography.pageTitle(
          context,
          fontSize: TimingTokens.headerTitleSize,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          height: TimingTokens.headerTitleLineHeight,
        ),
      ),
    );
  }
}

class DeviceSubpageSwipeBack extends StatefulWidget {
  const DeviceSubpageSwipeBack({super.key, required this.child});

  final Widget child;

  @override
  State<DeviceSubpageSwipeBack> createState() => _DeviceSubpageSwipeBackState();
}

class _DeviceSubpageSwipeBackState extends State<DeviceSubpageSwipeBack> {
  static const double _minPopDragDistance = 96;
  double _dragDx = 0;
  double _dragDy = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) {
        _dragDx = 0;
        _dragDy = 0;
      },
      onHorizontalDragUpdate: (details) {
        _dragDx += details.delta.dx;
        _dragDy += details.delta.dy.abs();
      },
      onHorizontalDragEnd: (_) {
        if (_dragDx < _minPopDragDistance || _dragDx <= _dragDy) return;
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.maybePop();
        }
      },
      child: widget.child,
    );
  }
}
