import 'package:flutter/material.dart';

import '../../components/buttons/app_primary_button.dart';
import '../../core/foundation/spacing.dart';
import '../../core/foundation/typography.dart';
import '../../patterns/layout/bottom_sheet_shell_pattern.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/sheet_tokens.dart';
import '../../tokens/mapper/timing_tokens.dart';

final DateTime jztDatePickerFirstDate = DateTime(2026, 1, 1);
final DateTime jztDatePickerLastDate = DateTime(2027, 12, 31);

const _monthCount = 24;
const _weekdayLabels = ['日', '一', '二', '三', '四', '五', '六'];
const _datePickerWarmDivider = Color(0xFFE3DCCF);
const _datePickerWarmAccent = Color(0xFFB9854D);
const _calendarGridHorizontalPadding = AppSpace.lg + AppSpace.md;
const _monthSectionGap = 6.0;
const _monthListTopPadding = AppSpace.md;
const _monthTitleHeight = 24.0;
const _monthTitleToDividerGap = 8.0;
const _monthDividerHeight = 1.0;
const _monthAccentLineWidth = 108.0;
const _dividerToGridGap = 8.0;
const _dateCellHeight = 56.0;
const _dateCellSurfaceWidth = 44.0;
const _dateCellSurfaceHeight = 52.0;
const _dateCellLabelHeight = 12.0;
const _dateCellNumberHeight = 22.0;
const _dateCellLabelFontSize = 9.0;
const _bottomActionButtonHeight = 46.0;
const _bottomActionVerticalPadding = AppSpace.sm + AppSpace.lg;
const _monthListBottomExtraPadding = AppSpace.xl;

Future<DateTime?> showSheetDatePickerDialog({
  required BuildContext context,
  required DateTime initialDate,
}) {
  return showJztDatePickerSheet(context: context, initialDate: initialDate);
}

Future<DateTime?> showJztDatePickerSheet({
  required BuildContext context,
  required DateTime initialDate,
}) {
  return showAppBottomSheet<DateTime>(
    context: context,
    useSafeArea: false,
    builder: (_) {
      return AppBottomSheetShell(
        title: null,
        scrollable: false,
        footerEnabled: false,
        contentPadding: EdgeInsets.zero,
        child: JztDatePickerBottomSheet(initialDate: initialDate),
      );
    },
  );
}

class JztDatePickerBottomSheet extends StatefulWidget {
  const JztDatePickerBottomSheet({super.key, required this.initialDate});

  final DateTime initialDate;

  @override
  State<JztDatePickerBottomSheet> createState() =>
      _JztDatePickerBottomSheetState();
}

class _JztDatePickerBottomSheetState extends State<JztDatePickerBottomSheet> {
  late final List<DateTime> _months;
  late final ScrollController _scrollController;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _months = _buildMonths();
    final initialDate = _dateOnly(widget.initialDate);
    _selectedDate = _isInRange(initialDate) ? initialDate : null;
    _scrollController = ScrollController(
      initialScrollOffset: _initialScrollOffset(_months, initialDate),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _selectDate(DateTime date) {
    if (!_isInRange(date)) return;
    setState(() => _selectedDate = _dateOnly(date));
  }

  void _finish() {
    final selected = _selectedDate;
    if (selected == null) return;
    Navigator.of(
      context,
    ).pop(DateTime(selected.year, selected.month, selected.day));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _JztWeekdayRow(),
        Expanded(
          child: ListView.builder(
            key: const ValueKey('jzt-date-picker-month-list'),
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              _calendarGridHorizontalPadding,
              _monthListTopPadding,
              _calendarGridHorizontalPadding,
              _monthListBottomPadding(context),
            ),
            itemCount: _months.length,
            itemBuilder: (context, index) {
              final month = _months[index];
              return JztMonthDateGrid(
                month: month,
                selectedDate: _selectedDate,
                onDateSelected: _selectDate,
              );
            },
          ),
        ),
        _JztBottomActionBar(onPressed: _selectedDate == null ? null : _finish),
      ],
    );
  }
}

class _JztWeekdayRow extends StatelessWidget {
  const _JztWeekdayRow();

  @override
  Widget build(BuildContext context) {
    final weekdayStyle = AppTypography.caption(
      context,
      fontSize: TimingTokens.dateDialogWeekdayFontSize,
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
    );
    final weekendStyle = weekdayStyle?.copyWith(color: _datePickerWarmAccent);
    return Container(
      key: const ValueKey('jzt-date-picker-weekday-row'),
      padding: const EdgeInsets.fromLTRB(
        _calendarGridHorizontalPadding,
        AppSpace.xs,
        _calendarGridHorizontalPadding,
        AppSpace.sm,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _datePickerWarmDivider)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _weekdayLabels.length; i++)
            Expanded(
              child: Center(
                child: Text(
                  _weekdayLabels[i],
                  key: ValueKey('jzt-date-picker-weekday-${_weekdayLabels[i]}'),
                  style: i == 0 || i == 6 ? weekendStyle : weekdayStyle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class JztMonthDateGrid extends StatelessWidget {
  const JztMonthDateGrid({
    super.key,
    required this.month,
    required this.selectedDate,
    required this.onDateSelected,
  });

  final DateTime month;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final leadingEmptyCount = _leadingEmptyCount(month.year, month.month);
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final rowCount = _monthRowCount(month);
    final titleStyle = AppTypography.body(
      context,
      fontSize: TimingTokens.dateDialogMonthFontSize,
      color: _datePickerWarmAccent,
      fontWeight: FontWeight.w700,
    );
    return Padding(
      key: ValueKey('jzt-date-picker-month-${month.year}-${month.month}'),
      padding: const EdgeInsets.only(bottom: _monthSectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _monthTitleHeight,
            child: Row(
              children: [
                Text('${month.year}年${month.month}月', style: titleStyle),
                const Spacer(),
                Icon(
                  Icons.calendar_today_outlined,
                  size: 15,
                  color: _datePickerWarmAccent.withValues(alpha: 0.62),
                ),
              ],
            ),
          ),
          const SizedBox(height: _monthTitleToDividerGap),
          const _JztMonthDivider(),
          const SizedBox(height: _dividerToGridGap),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rowCount * 7,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: _dateCellHeight,
            ),
            itemBuilder: (context, index) {
              final day = index - leadingEmptyCount + 1;
              if (day < 1 || day > daysInMonth) {
                return const SizedBox.shrink();
              }
              final date = DateTime(month.year, month.month, day);
              return JztDateCell(
                date: date,
                selected:
                    selectedDate != null &&
                    DateUtils.isSameDay(date, selectedDate),
                today: DateUtils.isSameDay(date, DateTime.now()),
                onTap: () => onDateSelected(date),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _JztMonthDivider extends StatelessWidget {
  const _JztMonthDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _monthDividerHeight,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Container(
            key: const ValueKey('jzt-date-picker-month-divider-line'),
            height: _monthDividerHeight,
            color: _datePickerWarmDivider,
          ),
          Container(
            key: const ValueKey('jzt-date-picker-month-accent-line'),
            width: _monthAccentLineWidth,
            height: _monthDividerHeight,
            color: _datePickerWarmAccent,
          ),
        ],
      ),
    );
  }
}

class JztDateCell extends StatelessWidget {
  const JztDateCell({
    super.key,
    required this.date,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final bool today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dayKey = _dateKey(date);
    final dayStyle = AppTypography.body(
      context,
      fontSize: TimingTokens.dateDialogDayFontSize,
      color: selected ? SheetColors.actionOn : AppColors.textPrimary,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
    );
    final labelStyle = AppTypography.caption(
      context,
      fontSize: _dateCellLabelFontSize,
      color: selected ? SheetColors.actionOn : AppColors.textPrimary,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
    );
    return InkWell(
      key: ValueKey('jzt-date-picker-day-$dayKey'),
      borderRadius: BorderRadius.circular(SheetTokens.fieldRadius),
      onTap: onTap,
      child: Center(
        child: AnimatedContainer(
          key: ValueKey('jzt-date-picker-day-surface-$dayKey'),
          duration: const Duration(milliseconds: 140),
          width: _dateCellSurfaceWidth,
          height: _dateCellSurfaceHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? SheetColors.action : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _datePickerWarmAccent.withValues(alpha: 0.16),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: _dateCellLabelHeight,
                child: Center(
                  child: today
                      ? Text(
                          '今天',
                          key: ValueKey(
                            'jzt-date-picker-day-top-label-$dayKey',
                          ),
                          style: labelStyle,
                          textScaler: TextScaler.noScaling,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              SizedBox(
                height: _dateCellNumberHeight,
                child: Center(
                  child: Text(
                    '${date.day}',
                    key: ValueKey('jzt-date-picker-day-number-$dayKey'),
                    style: dayStyle,
                  ),
                ),
              ),
              SizedBox(
                height: _dateCellLabelHeight,
                child: Center(
                  child: selected
                      ? Text(
                          '开始',
                          key: ValueKey(
                            'jzt-date-picker-day-bottom-label-$dayKey',
                          ),
                          style: labelStyle,
                          textScaler: TextScaler.noScaling,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JztBottomActionBar extends StatelessWidget {
  const _JztBottomActionBar({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.sm,
        AppSpace.lg,
        AppSpace.lg + bottomInset,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _datePickerWarmDivider)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: AppPrimaryButton(
          label: '完成',
          height: _bottomActionButtonHeight,
          borderRadius: 12,
          onPressed: onPressed,
        ),
      ),
    );
  }
}

List<DateTime> _buildMonths() {
  return List<DateTime>.generate(
    _monthCount,
    (index) => DateTime(2026, index + 1, 1),
  );
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool _isInRange(DateTime date) {
  final day = _dateOnly(date);
  return !day.isBefore(jztDatePickerFirstDate) &&
      !day.isAfter(jztDatePickerLastDate);
}

int _initialMonthIndex(DateTime initialDate) {
  final day = _dateOnly(initialDate);
  if (day.isBefore(jztDatePickerFirstDate)) return 0;
  if (day.isAfter(jztDatePickerLastDate)) return _monthCount - 1;
  return ((day.year - 2026) * 12 + day.month - 1).clamp(0, _monthCount - 1);
}

double _initialScrollOffset(List<DateTime> months, DateTime initialDate) {
  final targetIndex = _initialMonthIndex(initialDate);
  var offset = 0.0;
  for (var i = 0; i < targetIndex; i++) {
    offset += _monthExtent(months[i]);
  }
  return offset;
}

double _monthExtent(DateTime month) {
  return _monthTitleHeight +
      _monthTitleToDividerGap +
      _monthDividerHeight +
      _dividerToGridGap +
      _dateCellHeight * _monthRowCount(month) +
      _monthSectionGap;
}

double _monthListBottomPadding(BuildContext context) {
  return _bottomActionButtonHeight +
      _bottomActionVerticalPadding +
      MediaQuery.of(context).viewPadding.bottom +
      _monthListBottomExtraPadding;
}

int _monthRowCount(DateTime month) {
  final slots =
      _leadingEmptyCount(month.year, month.month) +
      DateUtils.getDaysInMonth(month.year, month.month);
  return (slots + 6) ~/ 7;
}

int _leadingEmptyCount(int year, int month) {
  final firstDay = DateTime(year, month, 1);
  return firstDay.weekday % 7;
}

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}$month$day';
}
