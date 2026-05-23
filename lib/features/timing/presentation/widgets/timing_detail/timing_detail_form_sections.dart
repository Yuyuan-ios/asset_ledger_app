part of '../../../../../patterns/timing/timing_detail_content_pattern.dart';

extension TimingDetailFormSections on TimingDetailContentState {
  Future<void> _openWorkHourCalculator() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final parsedHours = double.tryParse(_hoursCtrl.text.trim());
    final initialHours = parsedHours != null && parsedHours > 0
        ? parsedHours
        : null;

    await showAppBottomSheet<void>(
      context: context,
      useSafeArea: false,
      builder: (_) {
        return WorkHourCalculatorSheet(
          initialHours: initialHours,
          existingHistories: widget.existingCalculationHistories,
          initialStagedHistories: _stagedCalculationHistories,
          onResultApplied: (result) {
            if (!mounted) return;
            _applyCalculatedHours(result);
          },
          onHistoriesChanged: (histories) {
            if (!mounted) return;
            _replaceStagedCalculationHistories(histories);
          },
        );
      },
    );
    if (mounted) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  InputDecoration _sheetDecoration({
    required String hint,
    String? label,
    Widget? suffixIcon,
  }) {
    final hintStyle = AppTypography.bodySecondary(
      context,
      fontSize: SheetTokens.fieldTextSize,
      color: SheetColors.hint,
    );
    final labelStyle = AppTypography.bodySecondary(
      context,
      fontSize: SheetTokens.fieldLabelSize,
      color: SheetColors.textPrimary,
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: hintStyle,
      labelText: label,
      labelStyle: labelStyle,
      floatingLabelBehavior: label == null
          ? FloatingLabelBehavior.never
          : FloatingLabelBehavior.always,
      filled: true,
      fillColor: SheetColors.fieldBackground,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: SheetTokens.fieldContentHPadding,
        vertical: SheetTokens.fieldContentVPadding,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SheetTokens.fieldRadius),
        borderSide: const BorderSide(
          color: SheetColors.fieldBorder,
          width: SheetTokens.fieldBorderWidth,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SheetTokens.fieldRadius),
        borderSide: const BorderSide(
          color: SheetColors.fieldBorder,
          width: SheetTokens.fieldBorderWidth,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SheetTokens.fieldRadius),
        borderSide: const BorderSide(
          color: SheetColors.fieldBorder,
          width: SheetTokens.fieldBorderWidth,
        ),
      ),
      suffixIcon: suffixIcon,
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    String? label,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
    VoidCallback? onTap,
    Widget? suffixIcon,
    bool readOnly = false,
    bool canRequestFocus = true,
    bool? showCursor,
    bool enableInteractiveSelection = true,
    bool selectAllOnTap = false,
  }) {
    final fieldStyle = AppTypography.body(
      context,
      fontSize: SheetTokens.fieldTextSize,
      color: SheetColors.textPrimary,
    );
    return TextField(
      controller: controller,
      readOnly: readOnly,
      canRequestFocus: canRequestFocus,
      showCursor: showCursor,
      enableInteractiveSelection: enableInteractiveSelection,
      keyboardType: keyboardType,
      onTap:
          onTap ??
          (selectAllOnTap
              ? () => selectAllText(controller)
              : (keyboardType == null
                    ? null
                    : () => selectAllIfZeroLike(controller))),
      onChanged: onChanged,
      style: fieldStyle,
      decoration: _sheetDecoration(
        hint: hint,
        label: label,
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _buildTwoOptionSegment({
    required int selectedIndex,
    required void Function(int index) onTap,
    required String leftText,
    required String rightText,
    double? width,
    double? height,
    double? inset,
    double? radius,
    double? itemHeight,
    double? checkRightGap,
    double? checkSize,
    double? textSize,
  }) {
    return _TimingTwoOptionSegment(
      selectedIndex: selectedIndex,
      onTap: onTap,
      leftText: leftText,
      rightText: rightText,
      width: width,
      height: height,
      inset: inset,
      radius: radius,
      itemHeight: itemHeight,
      checkRightGap: checkRightGap,
      checkSize: checkSize,
      textSize: textSize,
    );
  }

  Widget _buildModeSelector() {
    return _buildTwoOptionSegment(
      selectedIndex: _mode == WorkMode.hours ? 0 : 1,
      onTap: _selectModeIndex,
      leftText: '工时',
      rightText: '租金(台班)',
    );
  }

  Widget _buildAttachmentSelector({bool compact = false}) {
    return _buildTwoOptionSegment(
      selectedIndex: _attachmentMode == AttachmentMode.digging ? 0 : 1,
      onTap: _selectAttachmentIndex,
      leftText: '挖斗',
      rightText: '破碎',
      width: compact ? 148 : null,
      height: compact ? SheetTokens.fieldHeight : null,
      inset: compact ? 2 : null,
      radius: compact ? SheetTokens.fieldRadius : null,
      itemHeight: compact ? SheetTokens.fieldHeight - 4 : null,
      checkRightGap: compact ? 2 : null,
      checkSize: compact ? 10 : null,
      textSize: compact ? 12 : null,
    );
  }
}

class _TimingTwoOptionSegment extends StatelessWidget {
  const _TimingTwoOptionSegment({
    required this.selectedIndex,
    required this.onTap,
    required this.leftText,
    required this.rightText,
    this.width,
    this.height,
    this.inset,
    this.radius,
    this.itemHeight,
    this.checkRightGap,
    this.checkSize,
    this.textSize,
  });

  final int selectedIndex;
  final void Function(int index) onTap;
  final String leftText;
  final String rightText;
  final double? width;
  final double? height;
  final double? inset;
  final double? radius;
  final double? itemHeight;
  final double? checkRightGap;
  final double? checkSize;
  final double? textSize;

  @override
  Widget build(BuildContext context) {
    final resolvedRadius = radius ?? TimingTokens.segmentRadius;
    final resolvedHeight = height ?? TimingTokens.segmentHeight;
    final resolvedInset = inset ?? TimingTokens.segmentInset;
    final resolvedItemHeight = itemHeight ?? TimingTokens.segmentItemHeight;
    final resolvedCheckRightGap =
        checkRightGap ?? TimingTokens.segmentCheckRightGap;
    final resolvedCheckSize = checkSize ?? TimingTokens.segmentCheckSize;
    final resolvedTextSize = textSize ?? TimingTokens.segmentTextSize;
    final checkStyle = AppTypography.caption(
      context,
      fontSize: resolvedCheckSize,
      color: SheetColors.textPrimary,
    );
    final segmentTextStyle = AppTypography.body(
      context,
      fontSize: resolvedTextSize,
      color: SheetColors.textPrimary,
    );

    return Container(
      width: width ?? double.infinity,
      height: resolvedHeight,
      padding: EdgeInsets.all(resolvedInset),
      decoration: BoxDecoration(
        color: SheetColors.segmentBackground,
        borderRadius: BorderRadius.circular(resolvedRadius),
        border: Border.all(color: SheetColors.segmentBorder),
      ),
      child: Row(
        children: [
          _TimingTwoOptionSegmentItem(
            selected: selectedIndex == 0,
            text: leftText,
            radius: resolvedRadius,
            height: resolvedItemHeight,
            checkRightGap: resolvedCheckRightGap,
            checkStyle: checkStyle,
            textStyle: segmentTextStyle,
            onTap: () => onTap(0),
          ),
          _TimingTwoOptionSegmentItem(
            selected: selectedIndex == 1,
            text: rightText,
            radius: resolvedRadius,
            height: resolvedItemHeight,
            checkRightGap: resolvedCheckRightGap,
            checkStyle: checkStyle,
            textStyle: segmentTextStyle,
            onTap: () => onTap(1),
          ),
        ],
      ),
    );
  }
}

class _TimingTwoOptionSegmentItem extends StatelessWidget {
  const _TimingTwoOptionSegmentItem({
    required this.selected,
    required this.text,
    required this.radius,
    required this.height,
    required this.checkRightGap,
    required this.checkStyle,
    required this.textStyle,
    required this.onTap,
  });

  final bool selected;
  final String text;
  final double radius;
  final double height;
  final double checkRightGap;
  final TextStyle? checkStyle;
  final TextStyle? textStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: selected ? SheetColors.segmentSelected : Colors.transparent,
            borderRadius: BorderRadius.circular(radius),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (selected)
                Padding(
                  padding: EdgeInsets.only(right: checkRightGap),
                  child: Text('✓', style: checkStyle),
                ),
              Text(text, style: textStyle),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimingFieldAssetIconButton extends StatelessWidget {
  const _TimingFieldAssetIconButton({
    required this.tooltip,
    required this.assetPath,
    required this.onPressed,
  });

  final String tooltip;
  final String assetPath;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      padding: const EdgeInsets.all(1),
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      icon: Opacity(
        opacity: onPressed == null ? 0.45 : 1,
        child: Image.asset(
          assetPath,
          width: _timingFieldIconSize,
          height: _timingFieldIconSize,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
