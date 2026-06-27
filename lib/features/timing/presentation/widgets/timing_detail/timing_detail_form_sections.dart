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
    return buildSheetInputDecoration(
      context,
      hintText: hint,
      labelText: label,
      floatingLabelBehavior: label == null
          ? FloatingLabelBehavior.never
          : FloatingLabelBehavior.always,
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
    Widget? leftIcon,
    Widget? rightIcon,
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
      leftIcon: leftIcon,
      rightIcon: rightIcon,
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
      leftText: _hourLayout.modeLabel,
      rightText: _rentLayout.modeLabel,
    );
  }

  Widget _buildAttachmentSelector({bool compact = false}) {
    final l10n = AppLocalizations.of(context);
    final iconHeight = compact ? 16.0 : 18.0;
    return _buildTwoOptionSegment(
      selectedIndex: _attachmentMode == AttachmentMode.digging ? 0 : 1,
      onTap: _selectAttachmentIndex,
      leftText: l10n.timingAttachmentDigging,
      rightText: l10n.timingAttachmentBreaking,
      leftIcon: _buildAttachmentGlyph(
        asset: _kAttachmentBucketAsset,
        // 挖斗 SVG 填满画布、破碎锤四周留白：挖斗按系数缩小，使两者在
        // toggle 内可见大小对齐（最终系数可运行 app 后微调 _kAttachmentBucketScale）。
        height: iconHeight * _kAttachmentBucketScale,
        semanticLabel: l10n.timingAttachmentDigging,
      ),
      rightIcon: _buildAttachmentGlyph(
        asset: _kAttachmentBreakerAsset,
        height: iconHeight,
        semanticLabel: l10n.timingAttachmentBreaking,
      ),
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

const String _kAttachmentBucketAsset =
    'assets/icons/timing/attachment_bucket.svg';
const String _kAttachmentBreakerAsset =
    'assets/icons/timing/attachment_breaker.svg';

/// 挖斗图标填满 512 画布、破碎锤四周留白；用此系数把挖斗等比缩小，
/// 使两者在分段控件里的可见尺寸对齐（运行 app 后可微调）。
const double _kAttachmentBucketScale = 0.82;

/// 渲染属具 SVG 图标：随 [SheetColors.textPrimary] 着色（线稿跟随文字色），
/// 带无障碍语义标签。
Widget _buildAttachmentGlyph({
  required String asset,
  required double height,
  required String semanticLabel,
}) {
  return SvgPicture.asset(
    asset,
    height: height,
    colorFilter: ColorFilter.mode(SheetColors.textPrimary, BlendMode.srcIn),
    semanticsLabel: semanticLabel,
  );
}

class _TimingTwoOptionSegment extends StatelessWidget {
  const _TimingTwoOptionSegment({
    required this.selectedIndex,
    required this.onTap,
    required this.leftText,
    required this.rightText,
    this.leftIcon,
    this.rightIcon,
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
  final Widget? leftIcon;
  final Widget? rightIcon;
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
            icon: leftIcon,
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
            icon: rightIcon,
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
    this.icon,
  });

  final bool selected;
  final String text;
  final Widget? icon;
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
              // 有图标的分段(如属具挖斗/破碎)靠图标+高亮表达选中,不再叠 ✓;
              // 纯文字分段(如工时/租金)保留 ✓ 标记选中。
              if (selected && icon == null)
                Padding(
                  padding: EdgeInsets.only(right: checkRightGap),
                  child: Text('✓', style: checkStyle),
                ),
              if (icon != null)
                Padding(padding: const EdgeInsets.only(right: 4), child: icon),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle,
                ),
              ),
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
