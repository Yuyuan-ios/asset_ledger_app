import 'package:flutter/material.dart';

import '../../core/foundation/typography.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/timing_tokens.dart';

class ExcludeFuelSwitchCard extends StatelessWidget {
  const ExcludeFuelSwitchCard({
    super.key,
    required this.value,
    required this.onChanged,
    this.trailing,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final titleStyle = AppTypography.body(
      context,
      fontWeight: FontWeight.w700,
      fontSize: TimingTokens.switchTitleSize,
      color: SheetColors.textPrimary,
    );
    final descStyle = AppTypography.bodySecondary(
      context,
      fontSize: TimingTokens.switchDescSize,
      color: SheetColors.hint,
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: TimingTokens.switchCardMinHeight,
      ),
      child: Padding(
        padding: const EdgeInsets.only(
          left: TimingTokens.switchRowRightInset,
          top: TimingTokens.switchCardVPadding,
          bottom: TimingTokens.switchCardVPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _FigmaSwitch(value: value, onChanged: onChanged),
                const SizedBox(width: TimingTokens.switchInlineGap),
                Text('包油/包电', style: titleStyle),
                if (trailing != null) ...[const Spacer(), trailing!],
              ],
            ),
            const SizedBox(height: TimingTokens.switchDescTopGap),
            Text('开启后：本条工时不参与油耗效率统计。', style: descStyle),
          ],
        ),
      ),
    );
  }
}

class _FigmaSwitch extends StatelessWidget {
  const _FigmaSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: value,
      child: InkWell(
        borderRadius: BorderRadius.circular(TimingTokens.switchTrackHeight / 2),
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          width: TimingTokens.switchTrackWidth,
          height: TimingTokens.switchTrackHeight,
          padding: const EdgeInsets.all(TimingTokens.switchTrackInset),
          decoration: BoxDecoration(
            color: value ? SheetColors.action : SheetColors.switchTrackOff,
            borderRadius: BorderRadius.circular(
              TimingTokens.switchTrackHeight / 2,
            ),
            border: Border.all(
              color: SheetColors.switchThumb,
              width: TimingTokens.switchTrackBorderWidth,
            ),
          ),
          child: Align(
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: TimingTokens.switchThumbSize,
              height: TimingTokens.switchThumbSize,
              decoration: BoxDecoration(
                color: SheetColors.switchThumbFill,
                shape: BoxShape.circle,
                border: Border.all(
                  color: SheetColors.switchThumbBorder,
                  width: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
