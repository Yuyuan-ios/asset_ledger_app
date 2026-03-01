import 'package:flutter/material.dart';

import '../../components/pickers/app_number_picker.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/timing_tokens.dart';

class TimingTimeBlock extends StatefulWidget {
  const TimingTimeBlock({
    super.key,
    required this.title,
    required this.controller,
    required this.onChanged,
  });

  final String title;
  final TextEditingController controller;
  final ValueChanged<double> onChanged;

  @override
  State<TimingTimeBlock> createState() => _TimingTimeBlockState();
}

class _TimingTimeBlockState extends State<TimingTimeBlock> {
  late List<int> _digits;
  bool _syncingController = false;

  @override
  void initState() {
    super.initState();
    _digits = _digitsFromValue(_parse(widget.controller.text));
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant TimingTimeBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _digits = _digitsFromValue(_parse(widget.controller.text));
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (_syncingController) return;
    final next = _digitsFromValue(_parse(widget.controller.text));
    if (_sameDigits(next, _digits)) return;
    setState(() => _digits = next);
  }

  bool _sameDigits(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  double _parse(String text) => double.tryParse(text.trim()) ?? 0.0;

  List<int> _digitsFromValue(double value) {
    final tenths = (value * 10).round().clamp(0, 999999);
    final intPart = tenths ~/ 10;
    final decimal = tenths % 10;
    return <int>[
      (intPart ~/ 10000) % 10,
      (intPart ~/ 1000) % 10,
      (intPart ~/ 100) % 10,
      (intPart ~/ 10) % 10,
      intPart % 10,
      decimal,
    ];
  }

  double _valueFromDigits(List<int> digits) {
    final intPart =
        digits[0] * 10000 +
        digits[1] * 1000 +
        digits[2] * 100 +
        digits[3] * 10 +
        digits[4];
    return intPart + digits[5] / 10.0;
  }

  void _onDigitChanged(int index, int digit) {
    final next = [..._digits]..[index] = digit;
    final value = _valueFromDigits(next);

    _syncingController = true;
    widget.controller.text = value.toStringAsFixed(1);
    _syncingController = false;

    setState(() => _digits = next);
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final groupWidth =
        TimingTokens.meterCellSize * 6 +
        TimingTokens.meterGap * 4 +
        TimingTokens.meterDecimalGap * 2 +
        TimingTokens.meterDotSlotWidth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: SizedBox(
            width: groupWidth,
            child: SizedBox(
              height: TimingTokens.meterLabelHeight,
              child: Text(
                widget.title,
                style: const TextStyle(
                  fontSize: TimingTokens.meterLabelSize,
                  color: AppColors.sheetTextPrimary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: TimingTokens.meterLabelBottomGap),
        Listener(
          onPointerDown: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          child: Container(
            height: TimingTokens.meterContainerHeight,
            padding: const EdgeInsets.symmetric(
              horizontal: TimingTokens.meterContainerHPadding,
              vertical: TimingTokens.meterContainerVPadding,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                TimingTokens.meterContainerRadius,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < 5; i++) ...[
                  AppNumberPicker(
                    value: _digits[i],
                    onChanged: (v) => _onDigitChanged(i, v),
                  ),
                  if (i < 4) const SizedBox(width: TimingTokens.meterGap),
                ],
                const SizedBox(width: TimingTokens.meterDecimalGap),
                const SizedBox(
                  width: TimingTokens.meterDotSlotWidth,
                  child: Center(
                    child: Text(
                      '.',
                      style: TextStyle(
                        fontSize: TimingTokens.meterDotSize,
                        fontWeight: FontWeight.w700,
                        color: AppColors.sheetTextPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: TimingTokens.meterDecimalGap),
                AppNumberPicker(
                  value: _digits[5],
                  onChanged: (v) => _onDigitChanged(5, v),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
