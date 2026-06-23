import 'package:flutter/material.dart';
import '../../core/foundation/typography.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/timing_tokens.dart';

class SectionHeader extends StatelessWidget {
  final String? title;
  final VoidCallback? onAdd;
  final double horizontalPadding;
  final double bottomPadding;
  final double titleSize;
  final double titleLineHeight;
  final double addButtonHeight;
  final double addButtonHorizontalPadding;
  final double addButtonTextSize;
  final double addButtonTextLineHeight;

  const SectionHeader({
    super.key,
    this.title,
    this.onAdd,
    this.horizontalPadding = TimingTokens.headerHorizontalPadding,
    this.bottomPadding = TimingTokens.headerBottomPadding,
    this.titleSize = TimingTokens.headerTitleSize,
    this.titleLineHeight = TimingTokens.headerTitleLineHeight,
    this.addButtonHeight = TimingTokens.headerAddButtonHeight,
    this.addButtonHorizontalPadding =
        TimingTokens.headerAddButtonHorizontalPadding,
    this.addButtonTextSize = TimingTokens.headerAddButtonTextSize,
    this.addButtonTextLineHeight = TimingTokens.headerAddButtonTextLineHeight,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final effectiveTitle = title ?? l10n.timingSectionHeaderTitle;
    final titleStyle = AppTypography.pageTitle(
      context,
      fontSize: titleSize,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
      height: titleLineHeight,
    );
    final addButtonStyle = AppTypography.actionText(
      context,
      fontSize: addButtonTextSize,
      fontWeight: FontWeight.w700,
      height: addButtonTextLineHeight,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        0,
        horizontalPadding,
        bottomPadding,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(effectiveTitle, style: titleStyle),
          SizedBox(
            height: addButtonHeight,
            child: FilledButton(
              onPressed: onAdd,
              style: FilledButton.styleFrom(
                backgroundColor: TimingTokens.headerAddButtonBackground,
                elevation: 0,
                shape: const StadiumBorder(),
                padding: EdgeInsets.symmetric(
                  horizontal: addButtonHorizontalPadding,
                ),
                textStyle: addButtonStyle,
              ),
              child: Text(l10n.commonCreateAction),
            ),
          ),
        ],
      ),
    );
  }
}
