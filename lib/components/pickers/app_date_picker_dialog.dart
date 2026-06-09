import 'package:flutter/material.dart';

import '../../components/buttons/app_primary_button.dart';
import '../../core/foundation/spacing.dart';
import '../../core/foundation/typography.dart';
import '../../tokens/mapper/bottom_sheet_tokens.dart';
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
const _datePickerRangeFill = Color(0xFFEDEBE8);
const _calendarGridHorizontalPadding = AppSpace.lg + AppSpace.md;
const _monthSectionGap = 0.0;
const _monthListTopPadding = AppSpace.md;
const _monthHeaderLift = 8.0;
const _monthTitleHeight = 24.0;
const _monthTitleToDividerGap = 8.0;
const _monthDividerHeight = 1.0;
const _monthAccentLineWidth = 108.0;
const _dividerToGridGap = 0.0;
const _dateCellHeight = 56.0;
const _dateCellSurfaceWidth = 44.0;
const _dateCellSurfaceHeight = 52.0;
const _dateCellLabelHeight = 12.0;
const _dateCellNumberHeight = 22.0;
const _dateCellLabelFontSize = 9.0;
const _bottomActionButtonHeight = 46.0;
const _bottomActionVerticalPadding = AppSpace.sm + AppSpace.lg;
const _monthListBottomExtraPadding = AppSpace.xl;

typedef DatePickerDisabledDatePredicate = bool Function(DateTime date);

enum DatePickerResultType { selected, cleared, cancelled }

class DatePickerResult {
  const DatePickerResult._(this.type, this.date);

  const DatePickerResult.selected(DateTime date)
    : this._(DatePickerResultType.selected, date);

  const DatePickerResult.cleared() : this._(DatePickerResultType.cleared, null);

  const DatePickerResult.cancelled()
    : this._(DatePickerResultType.cancelled, null);

  final DatePickerResultType type;
  final DateTime? date;

  bool get isSelected => type == DatePickerResultType.selected;
  bool get isCleared => type == DatePickerResultType.cleared;
  bool get isCancelled => type == DatePickerResultType.cancelled;
}

enum DateRangePickerResultType { selected, cancelled }

class DateRangePickerResult {
  const DateRangePickerResult._(this.type, this.startDate, this.endDate);

  const DateRangePickerResult.selected(DateTime startDate, DateTime? endDate)
    : this._(DateRangePickerResultType.selected, startDate, endDate);

  const DateRangePickerResult.cancelled()
    : this._(DateRangePickerResultType.cancelled, null, null);

  final DateRangePickerResultType type;
  final DateTime? startDate;
  final DateTime? endDate;

  bool get isSelected => type == DateRangePickerResultType.selected;
  bool get isCancelled => type == DateRangePickerResultType.cancelled;
}

Future<DateTime?> showSheetDatePickerDialog({
  required BuildContext context,
  required DateTime initialDate,
  DateTime? minDate,
  DateTime? maxDate,
  bool allowClear = false,
  String selectedLabel = '开始',
  String clearText = '清空',
  String confirmText = '完成',
  DatePickerDisabledDatePredicate? disabledDate,
}) {
  return showJztDatePickerSheet(
    context: context,
    initialDate: initialDate,
    minDate: minDate,
    maxDate: maxDate,
    allowClear: allowClear,
    selectedLabel: selectedLabel,
    clearText: clearText,
    confirmText: confirmText,
    disabledDate: disabledDate,
  );
}

Future<DateTime?> showJztDatePickerSheet({
  required BuildContext context,
  required DateTime initialDate,
  DateTime? minDate,
  DateTime? maxDate,
  bool allowClear = false,
  String selectedLabel = '开始',
  String clearText = '清空',
  String confirmText = '完成',
  DatePickerDisabledDatePredicate? disabledDate,
}) async {
  final result = await showJztDatePickerSheetResult(
    context: context,
    initialDate: initialDate,
    minDate: minDate,
    maxDate: maxDate,
    allowClear: allowClear,
    selectedLabel: selectedLabel,
    clearText: clearText,
    confirmText: confirmText,
    disabledDate: disabledDate,
  );
  return result.isSelected ? result.date : null;
}

Future<DatePickerResult> showSheetDatePickerDialogResult({
  required BuildContext context,
  required DateTime initialDate,
  DateTime? minDate,
  DateTime? maxDate,
  bool allowClear = false,
  String selectedLabel = '开始',
  String clearText = '清空',
  String confirmText = '完成',
  DatePickerDisabledDatePredicate? disabledDate,
}) {
  return showJztDatePickerSheetResult(
    context: context,
    initialDate: initialDate,
    minDate: minDate,
    maxDate: maxDate,
    allowClear: allowClear,
    selectedLabel: selectedLabel,
    clearText: clearText,
    confirmText: confirmText,
    disabledDate: disabledDate,
  );
}

Future<DatePickerResult> showJztDatePickerSheetResult({
  required BuildContext context,
  required DateTime initialDate,
  DateTime? minDate,
  DateTime? maxDate,
  bool allowClear = false,
  String selectedLabel = '开始',
  String clearText = '清空',
  String confirmText = '完成',
  DatePickerDisabledDatePredicate? disabledDate,
}) async {
  final result = await showAppBottomSheet<DatePickerResult>(
    context: context,
    useSafeArea: false,
    builder: (_) {
      return AppBottomSheetShell(
        title: null,
        scrollable: false,
        footerEnabled: false,
        contentPadding: EdgeInsets.zero,
        child: JztDatePickerBottomSheet(
          initialDate: initialDate,
          minDate: minDate,
          maxDate: maxDate,
          allowClear: allowClear,
          selectedLabel: selectedLabel,
          clearText: clearText,
          confirmText: confirmText,
          disabledDate: disabledDate,
        ),
      );
    },
  );
  return result ?? const DatePickerResult.cancelled();
}

Future<DateRangePickerResult> showSheetDateRangePickerDialogResult({
  required BuildContext context,
  required DateTime initialStartDate,
  DateTime? initialEndDate,
  DateTime? minDate,
  DateTime? maxDate,
  DatePickerDisabledDatePredicate? disabledDate,
}) {
  return showJztDateRangePickerSheetResult(
    context: context,
    initialStartDate: initialStartDate,
    initialEndDate: initialEndDate,
    minDate: minDate,
    maxDate: maxDate,
    disabledDate: disabledDate,
  );
}

Future<DateRangePickerResult> showJztDateRangePickerSheetResult({
  required BuildContext context,
  required DateTime initialStartDate,
  DateTime? initialEndDate,
  DateTime? minDate,
  DateTime? maxDate,
  DatePickerDisabledDatePredicate? disabledDate,
}) async {
  final result = await showAppBottomSheet<DateRangePickerResult>(
    context: context,
    useSafeArea: false,
    builder: (_) {
      return AppBottomSheetShell(
        title: null,
        scrollable: false,
        footerEnabled: false,
        contentPadding: EdgeInsets.zero,
        child: JztDatePickerBottomSheet(
          initialDate: initialStartDate,
          initialEndDate: initialEndDate,
          minDate: minDate,
          maxDate: maxDate,
          rangeMode: true,
          disabledDate: disabledDate,
        ),
      );
    },
  );
  return result ?? const DateRangePickerResult.cancelled();
}

class JztDatePickerBottomSheet extends StatefulWidget {
  const JztDatePickerBottomSheet({
    super.key,
    required this.initialDate,
    this.initialEndDate,
    this.minDate,
    this.maxDate,
    this.rangeMode = false,
    this.allowClear = false,
    this.selectedLabel = '开始',
    this.clearText = '清空',
    this.confirmText = '完成',
    this.disabledDate,
  });

  final DateTime initialDate;
  final DateTime? initialEndDate;
  final DateTime? minDate;
  final DateTime? maxDate;
  final bool rangeMode;
  final bool allowClear;
  final String selectedLabel;
  final String clearText;
  final String confirmText;
  final DatePickerDisabledDatePredicate? disabledDate;

  @override
  State<JztDatePickerBottomSheet> createState() =>
      _JztDatePickerBottomSheetState();
}

enum _DateRangeSelectionStep { start, end }

class _JztDatePickerBottomSheetState extends State<JztDatePickerBottomSheet> {
  late final List<DateTime> _months;
  late final ScrollController _scrollController;
  late final DateTime _firstDate;
  late final DateTime _lastDate;
  DateTime? _selectedDate;
  DateTime? _selectedEndDate;
  _DateRangeSelectionStep _rangeStep = _DateRangeSelectionStep.start;

  @override
  void initState() {
    super.initState();
    _firstDate = _resolveFirstDate(widget.minDate, widget.maxDate);
    _lastDate = _resolveLastDate(widget.minDate, widget.maxDate);
    _months = _buildMonths(firstDate: _firstDate, lastDate: _lastDate);
    final initialDate = _dateOnly(widget.initialDate);
    _selectedDate = _isInRange(initialDate) ? initialDate : null;
    if (widget.rangeMode) {
      final initialEndDate = widget.initialEndDate;
      if (_selectedDate != null && initialEndDate != null) {
        final endDate = _dateOnly(initialEndDate);
        if (_isInRange(endDate) && !endDate.isBefore(_selectedDate!)) {
          _selectedEndDate = endDate;
          _rangeStep = _DateRangeSelectionStep.end;
        }
      }
    }
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
    final day = _dateOnly(date);
    if (!_isDateEnabled(day)) return;
    if (!widget.rangeMode) {
      setState(() => _selectedDate = day);
      return;
    }

    setState(() {
      final startDate = _selectedDate;
      if (_rangeStep == _DateRangeSelectionStep.start || startDate == null) {
        _selectedDate = day;
        _selectedEndDate = null;
        _rangeStep = _DateRangeSelectionStep.end;
        return;
      }

      if (day.isBefore(startDate)) return;
      if (_selectedEndDate != null && DateUtils.isSameDay(day, startDate)) {
        _selectedEndDate = null;
        _rangeStep = _DateRangeSelectionStep.end;
        return;
      }

      _selectedEndDate = day;
      _rangeStep = _DateRangeSelectionStep.start;
    });
  }

  void _finish() {
    final selected = _selectedDate;
    if (selected == null) return;
    if (widget.rangeMode) {
      final endDate = _normalizedEndDate();
      Navigator.of(context).pop(
        DateRangePickerResult.selected(
          DateTime(selected.year, selected.month, selected.day),
          endDate == null
              ? null
              : DateTime(endDate.year, endDate.month, endDate.day),
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      DatePickerResult.selected(
        DateTime(selected.year, selected.month, selected.day),
      ),
    );
  }

  void _clear() {
    Navigator.of(context).pop(const DatePickerResult.cleared());
  }

  bool _isInRange(DateTime date) {
    final day = _dateOnly(date);
    return !day.isBefore(_firstDate) && !day.isAfter(_lastDate);
  }

  bool _isDisabled(DateTime date) {
    final predicate = widget.disabledDate;
    return predicate != null && predicate(_dateOnly(date));
  }

  bool _isDateEnabled(DateTime date) {
    final day = _dateOnly(date);
    if (!_isInRange(day) || _isDisabled(day)) return false;
    if (!widget.rangeMode) return true;
    final startDate = _selectedDate;
    if (_rangeStep != _DateRangeSelectionStep.end || startDate == null) {
      return true;
    }
    return !day.isBefore(startDate);
  }

  DateTime? _normalizedEndDate() {
    final startDate = _selectedDate;
    final endDate = _selectedEndDate;
    if (startDate == null || endDate == null) return null;
    if (endDate.isBefore(startDate)) return null;
    return endDate;
  }

  String _rangePromptText() {
    return _rangeStep == _DateRangeSelectionStep.start
        ? '指定日期：请选择开始日'
        : '指定日期：请选择结束日（可不选）';
  }

  String _confirmText() {
    if (!widget.rangeMode) return widget.confirmText;
    final startDate = _selectedDate;
    final endDate = _normalizedEndDate();
    if (startDate == null || endDate == null) return widget.confirmText;
    if (!endDate.isAfter(startDate)) return widget.confirmText;
    final days = endDate.difference(startDate).inDays + 1;
    return '${widget.confirmText}($days天)';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.rangeMode) _JztRangePromptRow(text: _rangePromptText()),
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
                selectedEndDate: _normalizedEndDate(),
                rangeMode: widget.rangeMode,
                onDateSelected: _selectDate,
                isDateEnabled: _isDateEnabled,
                selectedLabel: widget.selectedLabel,
              );
            },
          ),
        ),
        _JztBottomActionBar(
          onPressed: _selectedDate == null ? null : _finish,
          allowClear: !widget.rangeMode && widget.allowClear,
          clearText: widget.clearText,
          confirmText: _confirmText(),
          onClear: _clear,
        ),
      ],
    );
  }
}

class _JztRangePromptRow extends StatelessWidget {
  const _JztRangePromptRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('jzt-date-picker-range-prompt'),
      alignment: Alignment.center,
      padding: const EdgeInsets.fromLTRB(
        _calendarGridHorizontalPadding,
        AppSpace.xs,
        _calendarGridHorizontalPadding,
        AppSpace.xs,
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTypography.actionText(
          context,
          fontSize: BottomSheetTokens.dateRangePromptTextSize,
          fontWeight: FontWeight.w600,
        )?.copyWith(color: AppColors.textPrimary),
      ),
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
    this.selectedEndDate,
    this.rangeMode = false,
    required this.onDateSelected,
    required this.isDateEnabled,
    required this.selectedLabel,
  });

  final DateTime month;
  final DateTime? selectedDate;
  final DateTime? selectedEndDate;
  final bool rangeMode;
  final ValueChanged<DateTime> onDateSelected;
  final bool Function(DateTime date) isDateEnabled;
  final String selectedLabel;

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
          Transform.translate(
            offset: const Offset(0, -_monthHeaderLift),
            child: Column(
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
              ],
            ),
          ),
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
              final rangeRole = _dateRangeRole(date);
              return JztDateCell(
                date: date,
                selected:
                    rangeRole == _DateCellRangeRole.start ||
                    rangeRole == _DateCellRangeRole.end,
                inRange: rangeRole == _DateCellRangeRole.middle,
                today: DateUtils.isSameDay(date, DateTime.now()),
                enabled: isDateEnabled(date),
                selectedLabel: rangeRole == _DateCellRangeRole.end
                    ? '截止'
                    : selectedLabel,
                onTap: () => onDateSelected(date),
              );
            },
          ),
        ],
      ),
    );
  }

  _DateCellRangeRole _dateRangeRole(DateTime date) {
    final startDate = selectedDate;
    if (startDate == null) return _DateCellRangeRole.none;
    if (!rangeMode) {
      return DateUtils.isSameDay(date, startDate)
          ? _DateCellRangeRole.start
          : _DateCellRangeRole.none;
    }
    final endDate = selectedEndDate;
    if (DateUtils.isSameDay(date, startDate)) {
      return _DateCellRangeRole.start;
    }
    if (endDate == null || !endDate.isAfter(startDate)) {
      return _DateCellRangeRole.none;
    }
    if (DateUtils.isSameDay(date, endDate)) return _DateCellRangeRole.end;
    if (date.isAfter(startDate) && date.isBefore(endDate)) {
      return _DateCellRangeRole.middle;
    }
    return _DateCellRangeRole.none;
  }
}

enum _DateCellRangeRole { none, start, middle, end }

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
    this.inRange = false,
    required this.today,
    required this.enabled,
    required this.selectedLabel,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final bool inRange;
  final bool today;
  final bool enabled;
  final String selectedLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dayKey = _dateKey(date);
    final textColor = enabled ? AppColors.textPrimary : SheetColors.hint;
    final dayStyle = AppTypography.body(
      context,
      fontSize: TimingTokens.dateDialogDayFontSize,
      color: selected ? SheetColors.actionOn : textColor,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
    );
    final labelStyle = AppTypography.caption(
      context,
      fontSize: _dateCellLabelFontSize,
      color: selected ? SheetColors.actionOn : textColor,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
    );
    return InkWell(
      key: ValueKey('jzt-date-picker-day-$dayKey'),
      borderRadius: BorderRadius.circular(SheetTokens.fieldRadius),
      onTap: enabled ? onTap : null,
      child: Center(
        child: AnimatedContainer(
          key: ValueKey('jzt-date-picker-day-surface-$dayKey'),
          duration: const Duration(milliseconds: 140),
          width: _dateCellSurfaceWidth,
          height: _dateCellSurfaceHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? SheetColors.action
                : inRange
                ? _datePickerRangeFill
                : Colors.transparent,
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
                          selectedLabel,
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
  const _JztBottomActionBar({
    required this.onPressed,
    required this.allowClear,
    required this.clearText,
    required this.confirmText,
    required this.onClear,
  });

  final VoidCallback? onPressed;
  final bool allowClear;
  final String clearText;
  final String confirmText;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final finishButton = AppPrimaryButton(
      label: confirmText,
      height: _bottomActionButtonHeight,
      borderRadius: 12,
      onPressed: onPressed,
    );
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
        child: allowClear
            ? Row(
                children: [
                  TextButton(
                    key: const ValueKey('jzt-date-picker-clear-button'),
                    onPressed: onClear,
                    child: Text(clearText),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(child: finishButton),
                ],
              )
            : finishButton,
      ),
    );
  }
}

List<DateTime> _buildMonths({DateTime? firstDate, DateTime? lastDate}) {
  final first = firstDate == null
      ? jztDatePickerFirstDate
      : DateTime(firstDate.year, firstDate.month);
  final last = lastDate == null
      ? jztDatePickerLastDate
      : DateTime(lastDate.year, lastDate.month);
  final count = ((last.year - first.year) * 12 + last.month - first.month + 1)
      .clamp(1, _monthCount)
      .toInt();
  return List<DateTime>.generate(
    count,
    (index) => DateTime(first.year, first.month + index, 1),
  );
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

double _initialScrollOffset(List<DateTime> months, DateTime initialDate) {
  final targetIndex = _initialMonthIndexForMonths(months, initialDate);
  var offset = 0.0;
  for (var i = 0; i < targetIndex; i++) {
    offset += _monthExtent(months[i]);
  }
  return offset;
}

int _initialMonthIndexForMonths(List<DateTime> months, DateTime initialDate) {
  if (months.isEmpty) return 0;
  final day = _dateOnly(initialDate);
  final first = months.first;
  final last = months.last;
  if (day.isBefore(first)) return 0;
  if (day.isAfter(DateTime(last.year, last.month + 1, 0))) {
    return months.length - 1;
  }
  return ((day.year - first.year) * 12 + day.month - first.month)
      .clamp(0, months.length - 1)
      .toInt();
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

DateTime _resolveFirstDate(DateTime? minDate, DateTime? maxDate) {
  final min = minDate == null ? jztDatePickerFirstDate : _dateOnly(minDate);
  final max = maxDate == null ? jztDatePickerLastDate : _dateOnly(maxDate);
  if (min.isAfter(max)) return max;
  return min;
}

DateTime _resolveLastDate(DateTime? minDate, DateTime? maxDate) {
  final min = minDate == null ? jztDatePickerFirstDate : _dateOnly(minDate);
  final max = maxDate == null ? jztDatePickerLastDate : _dateOnly(maxDate);
  if (max.isBefore(min)) return min;
  return max;
}
