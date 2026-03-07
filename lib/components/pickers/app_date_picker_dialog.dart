import 'package:flutter/material.dart';

import '../../core/foundation/typography.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/timing_tokens.dart';

Future<DateTime?> showSheetDatePickerDialog({
  required BuildContext context,
  required DateTime initialDate,
}) async {
  DateTime tempDate = DateTime(
    initialDate.year,
    initialDate.month,
    initialDate.day,
  );
  DateTime shownMonth = DateTime(initialDate.year, initialDate.month);

  return showDialog<DateTime>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final firstDay = DateTime(shownMonth.year, shownMonth.month, 1);
          final daysInMonth = DateUtils.getDaysInMonth(
            shownMonth.year,
            shownMonth.month,
          );
          final leadingBlank = firstDay.weekday % 7; // 周日=0
          final rowCount = ((leadingBlank + daysInMonth + 6) ~/ 7).clamp(4, 6);
          final slotCount = rowCount * 7;
          final monthStyle = AppTypography.body(
            context,
            fontSize: TimingTokens.dateDialogMonthFontSize,
            color: SheetColors.muted,
            fontWeight: FontWeight.w500,
          );
          final weekDayStyle = AppTypography.caption(
            context,
            fontSize: TimingTokens.dateDialogWeekdayFontSize,
            color: AppColors.textPrimary,
          );

          return Dialog(
            backgroundColor: SheetColors.background,
            surfaceTintColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: TimingTokens.dateDialogInsetH,
              vertical: TimingTokens.dateDialogInsetV,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                TimingTokens.dateDialogRadius,
              ),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: TimingTokens.dateDialogMaxWidth,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  TimingTokens.dateDialogPaddingH,
                  TimingTokens.dateDialogPaddingTop,
                  TimingTokens.dateDialogPaddingH,
                  TimingTokens.dateDialogPaddingBottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${shownMonth.year}年${shownMonth.month}月',
                          style: monthStyle,
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_drop_down,
                          color: SheetColors.muted,
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => setDialogState(
                            () => shownMonth = DateTime(
                              shownMonth.year,
                              shownMonth.month - 1,
                            ),
                          ),
                          icon: const Icon(
                            Icons.chevron_left,
                            color: SheetColors.muted,
                          ),
                        ),
                        IconButton(
                          onPressed: () => setDialogState(
                            () => shownMonth = DateTime(
                              shownMonth.year,
                              shownMonth.month + 1,
                            ),
                          ),
                          icon: const Icon(
                            Icons.chevron_right,
                            color: SheetColors.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: TimingTokens.dateDialogSectionGap),
                    Row(
                      children: [
                        Expanded(
                          child: Center(child: Text('日', style: weekDayStyle)),
                        ),
                        Expanded(
                          child: Center(child: Text('一', style: weekDayStyle)),
                        ),
                        Expanded(
                          child: Center(child: Text('二', style: weekDayStyle)),
                        ),
                        Expanded(
                          child: Center(child: Text('三', style: weekDayStyle)),
                        ),
                        Expanded(
                          child: Center(child: Text('四', style: weekDayStyle)),
                        ),
                        Expanded(
                          child: Center(child: Text('五', style: weekDayStyle)),
                        ),
                        Expanded(
                          child: Center(child: Text('六', style: weekDayStyle)),
                        ),
                      ],
                    ),
                    const SizedBox(height: TimingTokens.dateDialogSectionGap),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: slotCount,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisSpacing: TimingTokens.dateDialogGridMainGap,
                            crossAxisSpacing:
                                TimingTokens.dateDialogGridCrossGap,
                          ),
                      itemBuilder: (context, index) {
                        final day = index - leadingBlank + 1;
                        if (day < 1 || day > daysInMonth) {
                          return const SizedBox.shrink();
                        }
                        final date = DateTime(
                          shownMonth.year,
                          shownMonth.month,
                          day,
                        );
                        final selected = DateUtils.isSameDay(date, tempDate);
                        return InkWell(
                          borderRadius: BorderRadius.circular(
                            TimingTokens.dateDialogDayCellSize / 2,
                          ),
                          onTap: () => setDialogState(() => tempDate = date),
                          child: Center(
                            child: Container(
                              width: TimingTokens.dateDialogDayCellSize,
                              height: TimingTokens.dateDialogDayCellSize,
                              decoration: BoxDecoration(
                                color: selected
                                    ? SheetColors.action
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '$day',
                                style: AppTypography.body(
                                  context,
                                  fontSize: TimingTokens.dateDialogDayFontSize,
                                  color: selected
                                      ? SheetColors.actionOn
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: TimingTokens.dateDialogActionTopGap),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.brand.withValues(
                              alpha: 0.8,
                            ),
                          ),
                          child: const Text('取消'),
                        ),
                        const SizedBox(width: TimingTokens.dateDialogActionGap),
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(
                            DateTime(
                              tempDate.year,
                              tempDate.month,
                              tempDate.day,
                            ),
                          ),
                          child: const Text('确定'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
