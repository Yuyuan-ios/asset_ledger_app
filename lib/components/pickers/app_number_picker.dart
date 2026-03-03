import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/foundation/spacing.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/timing_tokens.dart';

/// 纯展示数字滚轮组件：不感知业务，仅收发当前值。
class AppNumberPicker extends StatefulWidget {
  const AppNumberPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 9,
    this.width = TimingTokens.meterCellSize,
    this.itemExtent = TimingTokens.meterItemExtent,
    this.diameterRatio = TimingTokens.meterWheelDiameterRatio,
    this.backgroundColor = SheetColors.meterBackground,
    this.textColor = SheetColors.meterText,
    this.backgroundMargin = EdgeInsets.zero,
    this.backgroundRadius = TimingTokens.digitCellRadius,
  }) : assert(min <= max),
       assert(value >= min && value <= max);

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  final double width;
  final double itemExtent;
  final double diameterRatio;
  final Color backgroundColor;
  final Color textColor;
  final EdgeInsets backgroundMargin;
  final double backgroundRadius;

  @override
  State<AppNumberPicker> createState() => _AppNumberPickerState();
}

class _AppNumberPickerState extends State<AppNumberPicker> {
  late FixedExtentScrollController _controller;
  bool _programmaticScrolling = false;

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(
      initialItem: widget.value - widget.min,
    );
  }

  @override
  void didUpdateWidget(covariant AppNumberPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value && oldWidget.min == widget.min) return;

    final target = widget.value - widget.min;
    if (!_controller.hasClients) {
      _controller.jumpToItem(target);
      return;
    }

    final current = _controller.selectedItem;
    if (current == target) return;

    _programmaticScrolling = true;
    _controller
        .animateToItem(
          target,
          duration: const Duration(
            milliseconds: TimingTokens.meterRollbackAnimMs,
          ),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() => _programmaticScrolling = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.max - widget.min + 1;

    return SizedBox(
      width: widget.width,
      child: Stack(
        children: [
          Container(
            margin: widget.backgroundMargin,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(widget.backgroundRadius),
            ),
            child: ListWheelScrollView.useDelegate(
              controller: _controller,
              itemExtent: widget.itemExtent,
              diameterRatio: widget.diameterRatio,
              squeeze: 1,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (index) {
                if (_programmaticScrolling) return;
                widget.onChanged(widget.min + index);
              },
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: count,
                builder: (context, index) {
                  final value = widget.min + index;
                  final selected = value == widget.value;
                  return Center(
                    child: Text(
                      '$value',
                      style: TextStyle(
                        fontSize: selected
                            ? TimingTokens.meterSelectedTextSize
                            : TimingTokens.meterUnselectedTextSize,
                        height: 1,
                        color: widget.textColor,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                height: widget.itemExtent,
                margin: const EdgeInsets.symmetric(horizontal: AppSpace.xxs),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    TimingTokens.digitOverlayRadius,
                  ),
                  border: Border.all(
                    color: SheetColors.digitHighlight.withValues(alpha: 0.7),
                    width: TimingTokens.digitHighlightBorderWidth,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
