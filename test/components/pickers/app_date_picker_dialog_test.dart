import 'package:asset_ledger/components/pickers/app_date_picker_dialog.dart';
import 'package:asset_ledger/components/surfaces/app_glass_surface.dart';
import 'package:asset_ledger/tokens/mapper/core_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _expectedDateCellHeight = 56.0;

void main() {
  testWidgets('renders fixed 2026-2027 range and weekday row', (tester) async {
    await _openPicker(tester, DateTime(2026, 1, 8));

    for (final label in const ['日', '一', '二', '三', '四', '五', '六']) {
      expect(
        find.byKey(ValueKey('jzt-date-picker-weekday-$label')),
        findsOneWidget,
      );
    }
    expect(find.text('2026年1月'), findsOneWidget);
    expect(find.text('2025年12月'), findsNothing);
    expect(find.text('2028年1月'), findsNothing);

    await _dragUntilVisible(tester, find.text('2027年12月'));
    expect(find.text('2027年12月'), findsOneWidget);
    expect(find.text('2028年1月'), findsNothing);
  });

  testWidgets('renders no title and no close button', (tester) async {
    await _openPicker(tester, DateTime(2026, 6, 4));

    expect(find.text('选择日期'), findsNothing);
    expect(find.byKey(const ValueKey('jzt-date-picker-title')), findsNothing);
    expect(
      find.byKey(const ValueKey('jzt-date-picker-close-button')),
      findsNothing,
    );
    expect(find.byTooltip('关闭'), findsNothing);
  });

  testWidgets('renders months on the shell surface without a nested panel', (
    tester,
  ) async {
    await _openPicker(tester, DateTime(2026, 6, 4));

    expect(find.byType(AppGlassSurface), findsOneWidget);
    expect(
      find.byKey(const ValueKey('jzt-date-picker-calendar-panel')),
      findsNothing,
    );

    final monthList = tester.widget<ListView>(
      find.byKey(const ValueKey('jzt-date-picker-month-list')),
    );
    final padding = monthList.padding as EdgeInsets;
    expect(padding.left, padding.right);
    expect(padding.left, greaterThan(0));

    final weekdayRow = tester.widget<Container>(
      find.byKey(const ValueKey('jzt-date-picker-weekday-row')),
    );
    final weekdayDecoration = weekdayRow.decoration as BoxDecoration;
    expect(weekdayDecoration.color, isNull);

    final monthTitle = tester.widget<Text>(find.text('2026年6月'));
    expect(monthTitle.style?.color, const Color(0xFFB9854D));

    final sundayLabel = tester.widget<Text>(
      find.byKey(const ValueKey('jzt-date-picker-weekday-日')),
    );
    expect(sundayLabel.style?.color, const Color(0xFFB9854D));

    final accentLineFinder = find
        .byKey(const ValueKey('jzt-date-picker-month-accent-line'))
        .first;
    final accentLine = tester.widget<Container>(accentLineFinder);
    final dividerLine = tester.widget<Container>(
      find.byKey(const ValueKey('jzt-date-picker-month-divider-line')).first,
    );
    expect(tester.getSize(accentLineFinder).width, greaterThanOrEqualTo(96));
    expect(accentLine.color, const Color(0xFFB9854D));
    expect(dividerLine.color, const Color(0xFFE3DCCF));
  });

  testWidgets('aligns weekday row with date grid columns', (tester) async {
    await _openPicker(tester, DateTime(2026, 6, 4));
    _expectWeekdaysAlignedWithDates(tester, const {
      '日': 20260607,
      '一': 20260601,
      '二': 20260602,
      '三': 20260603,
      '四': 20260604,
      '五': 20260605,
      '六': 20260606,
    });

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await _openPicker(tester, DateTime(2026, 9, 1));
    _expectWeekdaysAlignedWithDates(tester, const {
      '日': 20260906,
      '一': 20260907,
      '二': 20260901,
      '三': 20260902,
      '四': 20260903,
      '五': 20260904,
      '六': 20260905,
    });
  });

  testWidgets('uses dynamic month row counts without trailing blank rows', (
    tester,
  ) async {
    await _openPicker(tester, DateTime(2026, 6, 4));
    expect(_monthGridHeight(tester, 2026, 6), _expectedDateCellHeight * 5);
    expect(
      find.byKey(const ValueKey('jzt-date-picker-day-20260630')),
      findsOneWidget,
    );
    expect(find.text('2026年7月'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await _openPicker(tester, DateTime(2026, 5, 1));
    expect(_monthGridHeight(tester, 2026, 5), _expectedDateCellHeight * 6);
    expect(
      find.byKey(const ValueKey('jzt-date-picker-day-20260531')),
      findsOneWidget,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await _openPicker(tester, DateTime(2026, 2, 1));
    expect(_monthGridHeight(tester, 2026, 2), _expectedDateCellHeight * 4);
    expect(
      find.byKey(const ValueKey('jzt-date-picker-day-20260228')),
      findsOneWidget,
    );
  });

  testWidgets('positions the initial month in the main viewport', (
    tester,
  ) async {
    await _openPicker(tester, DateTime(2026, 6, 4));

    final monthFinder = find.byKey(
      const ValueKey('jzt-date-picker-month-2026-6'),
    );
    expect(monthFinder, findsOneWidget);

    final viewportHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(tester.getTopLeft(monthFinder).dy, lessThan(viewportHeight * 0.55));
  });

  testWidgets('selects initial date in range and switches selected state', (
    tester,
  ) async {
    await _openPicker(tester, DateTime(2026, 3, 15, 18, 30));

    expect(_surfaceColor(tester, 20260315), SheetColors.action);
    expect(_surfaceColor(tester, 20260320), isNot(SheetColors.action));

    await tester.tap(
      find.byKey(const ValueKey('jzt-date-picker-day-20260320')),
    );
    await tester.pumpAndSettle();

    expect(_surfaceColor(tester, 20260315), isNot(SheetColors.action));
    expect(_surfaceColor(tester, 20260320), SheetColors.action);
  });

  testWidgets(
    'renders unselected today above the number with primary text color',
    (tester) async {
      final today = _today();
      expect(_isInPickerRange(today), isTrue);
      final selected = _nearbyDateInSameMonth(today);

      await _openPicker(tester, selected);

      final todayKey = _ymd(today);
      final topLabel = find.byKey(
        ValueKey('jzt-date-picker-day-top-label-$todayKey'),
      );
      final dayNumber = find.byKey(
        ValueKey('jzt-date-picker-day-number-$todayKey'),
      );

      expect(topLabel, findsOneWidget);
      expect(dayNumber, findsOneWidget);
      expect(
        find.byKey(ValueKey('jzt-date-picker-day-bottom-label-$todayKey')),
        findsNothing,
      );
      expect(
        tester.getCenter(topLabel).dy,
        lessThan(tester.getCenter(dayNumber).dy),
      );
      expect(_textColor(tester, topLabel), AppColors.textPrimary);
      expect(_textColor(tester, dayNumber), AppColors.textPrimary);
      expect(_surfaceColor(tester, todayKey), isNot(SheetColors.action));
    },
  );

  testWidgets('renders selected today with today number and start in white', (
    tester,
  ) async {
    final today = _today();
    expect(_isInPickerRange(today), isTrue);

    await _openPicker(tester, today);

    final todayKey = _ymd(today);
    final topLabel = find.byKey(
      ValueKey('jzt-date-picker-day-top-label-$todayKey'),
    );
    final dayNumber = find.byKey(
      ValueKey('jzt-date-picker-day-number-$todayKey'),
    );
    final bottomLabel = find.byKey(
      ValueKey('jzt-date-picker-day-bottom-label-$todayKey'),
    );

    expect(topLabel, findsOneWidget);
    expect(dayNumber, findsOneWidget);
    expect(bottomLabel, findsOneWidget);
    expect(_surfaceColor(tester, todayKey), SheetColors.action);
    expect(_textColor(tester, topLabel), SheetColors.actionOn);
    expect(_textColor(tester, dayNumber), SheetColors.actionOn);
    expect(_textColor(tester, bottomLabel), SheetColors.actionOn);
    expect(
      tester.getCenter(topLabel).dy,
      lessThan(tester.getCenter(dayNumber).dy),
    );
    expect(
      tester.getCenter(dayNumber).dy,
      lessThan(tester.getCenter(bottomLabel).dy),
    );
  });

  testWidgets('shows start below the selected regular day and moves it', (
    tester,
  ) async {
    await _openPicker(tester, DateTime(2026, 3, 15));

    expect(
      find.byKey(const ValueKey('jzt-date-picker-day-top-label-20260315')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('jzt-date-picker-day-bottom-label-20260315')),
      findsOneWidget,
    );
    expect(
      tester
          .getCenter(
            find.byKey(const ValueKey('jzt-date-picker-day-number-20260315')),
          )
          .dy,
      lessThan(
        tester
            .getCenter(
              find.byKey(
                const ValueKey('jzt-date-picker-day-bottom-label-20260315'),
              ),
            )
            .dy,
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('jzt-date-picker-day-20260320')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('jzt-date-picker-day-bottom-label-20260315')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('jzt-date-picker-day-bottom-label-20260320')),
      findsOneWidget,
    );
  });

  testWidgets('does not render range or hotel-specific copy', (tester) async {
    await _openPicker(tester, DateTime(2026, 3, 15));

    expect(find.text('入住'), findsNothing);
    expect(find.text('离店'), findsNothing);
    expect(find.text('结束'), findsNothing);
    expect(find.text('完成（1天）'), findsNothing);
    expect(find.widgetWithText(ElevatedButton, '完成'), findsOneWidget);
  });

  testWidgets('returns the selected date when tapping finish', (tester) async {
    final probe = await _openPicker(tester, DateTime(2026, 3, 15));

    await tester.tap(
      find.byKey(const ValueKey('jzt-date-picker-day-20260320')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '完成'));
    await tester.pumpAndSettle();

    expect(probe.completed, isTrue);
    expect(probe.result, DateTime(2026, 3, 20));
  });

  testWidgets('returns null when dismissed with system back', (tester) async {
    final probe = await _openPicker(tester, DateTime(2026, 3, 15));

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(probe.completed, isTrue);
    expect(probe.result, isNull);
  });

  testWidgets('typed result distinguishes clear from cancel', (tester) async {
    final probe = await _openPickerResult(
      tester,
      DateTime(2026, 3, 15),
      allowClear: true,
    );

    await tester.tap(
      find.byKey(const ValueKey('jzt-date-picker-clear-button')),
    );
    await tester.pumpAndSettle();

    expect(probe.completed, isTrue);
    expect(probe.result?.isCleared, isTrue);
    expect(probe.result?.isCancelled, isFalse);
  });

  testWidgets('min and max dates disable out-of-range days', (tester) async {
    final probe = await _openPickerResult(
      tester,
      DateTime(2026, 3, 9),
      minDate: DateTime(2026, 3, 10),
      maxDate: DateTime(2026, 3, 20),
    );

    await tester.tap(
      find.byKey(const ValueKey('jzt-date-picker-day-20260309')),
    );
    await tester.pumpAndSettle();
    expect(_finishButton(tester).onPressed, isNull);

    await tester.tap(
      find.byKey(const ValueKey('jzt-date-picker-day-20260320')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '完成'));
    await tester.pumpAndSettle();

    expect(probe.result?.date, DateTime(2026, 3, 20));
  });

  testWidgets('custom selected label is rendered on selected date', (
    tester,
  ) async {
    await _openPickerResult(tester, DateTime(2026, 3, 15), selectedLabel: '分摊');

    expect(
      find.byKey(const ValueKey('jzt-date-picker-day-bottom-label-20260315')),
      findsOneWidget,
    );
    expect(find.text('分摊'), findsOneWidget);
    expect(find.text('开始'), findsNothing);
  });

  testWidgets('does not silently clamp an initial date before the range', (
    tester,
  ) async {
    final probe = await _openPicker(tester, DateTime(2025, 12, 31));

    expect(find.text('2026年1月'), findsOneWidget);
    expect(_surfaceColor(tester, 20260101), isNot(SheetColors.action));
    expect(_finishButton(tester).onPressed, isNull);
    expect(probe.completed, isFalse);
  });

  testWidgets('does not silently clamp an initial date after the range', (
    tester,
  ) async {
    await _openPicker(tester, DateTime(2028, 1, 1));

    expect(find.text('2027年12月'), findsOneWidget);
    expect(_surfaceColor(tester, 20271231), isNot(SheetColors.action));
    expect(_finishButton(tester).onPressed, isNull);
  });

  testWidgets(
    'keeps bottom padding for the fixed action bar without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(390, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _openPicker(tester, DateTime(2027, 12, 1));

      final list = tester.widget<ListView>(
        find.byKey(const ValueKey('jzt-date-picker-month-list')),
      );
      final padding = list.padding as EdgeInsets;

      expect(padding.bottom, greaterThanOrEqualTo(94));
      expect(tester.takeException(), isNull);

      await tester.drag(
        find.byKey(const ValueKey('jzt-date-picker-month-list')),
        const Offset(0, -280),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );
}

Future<_PickerProbe> _openPicker(
  WidgetTester tester,
  DateTime initialDate,
) async {
  final probe = _PickerProbe();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: TextButton(
                key: const ValueKey('open-picker'),
                onPressed: () async {
                  probe.result = await showJztDatePickerSheet(
                    context: context,
                    initialDate: initialDate,
                  );
                  probe.completed = true;
                },
                child: const Text('打开'),
              ),
            ),
          );
        },
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open-picker')));
  await tester.pumpAndSettle();
  return probe;
}

Future<_PickerResultProbe> _openPickerResult(
  WidgetTester tester,
  DateTime initialDate, {
  DateTime? minDate,
  DateTime? maxDate,
  bool allowClear = false,
  String selectedLabel = '开始',
}) async {
  final probe = _PickerResultProbe();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: TextButton(
                key: const ValueKey('open-picker'),
                onPressed: () async {
                  probe.result = await showJztDatePickerSheetResult(
                    context: context,
                    initialDate: initialDate,
                    minDate: minDate,
                    maxDate: maxDate,
                    allowClear: allowClear,
                    selectedLabel: selectedLabel,
                  );
                  probe.completed = true;
                },
                child: const Text('打开'),
              ),
            ),
          );
        },
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open-picker')));
  await tester.pumpAndSettle();
  return probe;
}

Future<void> _dragUntilVisible(WidgetTester tester, Finder target) async {
  await tester.dragUntilVisible(
    target,
    find.byKey(const ValueKey('jzt-date-picker-month-list')),
    const Offset(0, -460),
    maxIteration: 60,
  );
  await tester.pumpAndSettle();
}

void _expectWeekdaysAlignedWithDates(
  WidgetTester tester,
  Map<String, int> weekdayToDateKey,
) {
  for (final entry in weekdayToDateKey.entries) {
    final weekdayCenter = tester.getCenter(
      find.byKey(ValueKey('jzt-date-picker-weekday-${entry.key}')),
    );
    final dateCenter = tester.getCenter(
      find.byKey(ValueKey('jzt-date-picker-day-${entry.value}')),
    );

    expect(
      weekdayCenter.dx,
      moreOrLessEquals(dateCenter.dx, epsilon: 0.75),
      reason: '${entry.key} should align with ${entry.value}',
    );
  }
}

double _monthGridHeight(WidgetTester tester, int year, int month) {
  final grid = find.descendant(
    of: find.byKey(ValueKey('jzt-date-picker-month-$year-$month')),
    matching: find.byType(GridView),
  );
  expect(grid, findsOneWidget);
  return tester.getSize(grid).height;
}

Color? _surfaceColor(WidgetTester tester, int ymd) {
  final container = tester.widget<AnimatedContainer>(
    find.byKey(ValueKey('jzt-date-picker-day-surface-$ymd')),
  );
  final decoration = container.decoration;
  return decoration is BoxDecoration ? decoration.color : null;
}

Color? _textColor(WidgetTester tester, Finder finder) {
  return tester.widget<Text>(finder).style?.color;
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

DateTime _nearbyDateInSameMonth(DateTime date) {
  final nextDay = date.add(const Duration(days: 1));
  if (nextDay.month == date.month && _isInPickerRange(nextDay)) {
    return nextDay;
  }
  final previousDay = date.subtract(const Duration(days: 1));
  if (previousDay.month == date.month && _isInPickerRange(previousDay)) {
    return previousDay;
  }
  throw StateError('No nearby in-range date in the same month.');
}

bool _isInPickerRange(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return !day.isBefore(jztDatePickerFirstDate) &&
      !day.isAfter(jztDatePickerLastDate);
}

int _ymd(DateTime date) {
  return date.year * 10000 + date.month * 100 + date.day;
}

ElevatedButton _finishButton(WidgetTester tester) {
  return tester.widget<ElevatedButton>(
    find.widgetWithText(ElevatedButton, '完成'),
  );
}

class _PickerProbe {
  DateTime? result;
  bool completed = false;
}

class _PickerResultProbe {
  DatePickerResult? result;
  bool completed = false;
}
