import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/models/timing_calculation_history.dart';
import 'package:asset_ledger/patterns/device/device_picker_pattern.dart';
import 'package:asset_ledger/patterns/timing/timing_detail_content_pattern.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpTimingDetail(
    WidgetTester tester, {
    GlobalKey<TimingDetailContentState>? key,
    TimingRecord? editing,
    List<TimingRecord> records = const [],
    required List<Device> devices,
    List<TimingCalculationHistory> existingCalculationHistories = const [],
    TimingDetailSubmitHandler? onSubmit,
  }) async {
    final deviceItems = devices
        .where((device) => device.id != null)
        .map((device) => DevicePickerItemVm(id: device.id!, label: device.name))
        .toList();
    final deviceById = {
      for (final device in devices)
        if (device.id != null) device.id!: device,
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimingDetailContent(
            key: key,
            editing: editing,
            records: records,
            activeDevices: devices.where((device) => device.isActive).toList(),
            allDevices: devices,
            deviceById: deviceById,
            deviceItems: deviceItems,
            projectRates: const <ProjectDeviceRate>[],
            existingCalculationHistories: existingCalculationHistories,
            contactSuggestions: (_) => const <String>[],
            siteSuggestions: (_) => const <String>[],
            resolveIncome:
                ({
                  required int deviceId,
                  required String contact,
                  required String site,
                  required bool isBreaking,
                  required double hours,
                }) => 0,
            validateMeterBounds:
                ({
                  required int deviceId,
                  required int startDate,
                  required double endMeter,
                  int? excludeId,
                }) => null,
            resolveCurrentMeter: (_) => 0,
            onSubmit: onSubmit ?? (_, _) async {},
            onToast: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Device buildDevice({
    required int id,
    double? breakingUnitPrice,
    EquipmentType equipmentType = EquipmentType.excavator,
  }) {
    return Device(
      id: id,
      name: 'SANY $id#',
      brand: 'SANY',
      defaultUnitPrice: 100,
      breakingUnitPrice: breakingUnitPrice,
      baseMeterHours: 0,
      equipmentType: equipmentType,
    );
  }

  TimingRecord buildEditableTimingRecord({
    double startMeter = 10,
    double endMeter = 12,
    double hours = 2,
    int startDate = 20260315,
    int? allocationCutoffExclusiveYmd,
    int? displayEndDate,
    TimingType type = TimingType.hours,
    double income = 300,
  }) {
    return TimingRecord(
      id: 7,
      deviceId: 1,
      startDate: startDate,
      allocationCutoffDate: allocationCutoffExclusiveYmd,
      displayEndDate: displayEndDate,
      contact: '何小波',
      site: 'A工地',
      type: type,
      startMeter: startMeter,
      endMeter: endMeter,
      hours: hours,
      income: income,
    );
  }

  Future<void> tapCalculatorTextKey(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(OutlinedButton, label).last);
    await tester.pumpAndSettle();
  }

  Future<void> closeCalculatorSheet(WidgetTester tester) async {
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
  }

  String collectUiCopy(WidgetTester tester) {
    final parts = <String>[];
    for (final widget in tester.allWidgets) {
      if (widget is Text) {
        parts.add(widget.data ?? widget.textSpan?.toPlainText() ?? '');
      } else if (widget is Tooltip) {
        parts.add(widget.message ?? widget.richMessage?.toPlainText() ?? '');
      } else if (widget is TextField) {
        final decoration = widget.decoration;
        if (decoration == null) continue;
        parts
          ..add(decoration.labelText ?? '')
          ..add(decoration.hintText ?? '')
          ..add(decoration.helperText ?? '');
      }
    }
    return parts.where((part) => part.isNotEmpty).join('\n');
  }

  Finder focusedEditableTexts() {
    return find.byWidgetPredicate((widget) {
      return widget is EditableText && widget.focusNode.hasFocus;
    });
  }

  TimingCalculationHistory existingHistory({
    String id = 'existing-h1',
    DateTime? createdAt,
  }) {
    return TimingCalculationHistory(
      id: id,
      timingRecordId: 7,
      createdAt: createdAt ?? DateTime.utc(2026, 5, 13, 18, 20),
      expression: '8+8.2+7.8',
      result: 24.0,
      ticketCount: 3,
    );
  }

  testWidgets(
    'shows breaking selector only when device supports breaking mode',
    (WidgetTester tester) async {
      await pumpTimingDetail(
        tester,
        devices: [buildDevice(id: 1, breakingUnitPrice: null)],
      );

      expect(find.text('破碎'), findsNothing);

      await pumpTimingDetail(
        tester,
        devices: [buildDevice(id: 1, breakingUnitPrice: 180)],
      );

      expect(find.text('破碎'), findsOneWidget);
    },
  );

  testWidgets(
    'keeps breaking selector visible for editing legacy breaking records',
    (WidgetTester tester) async {
      final device = buildDevice(id: 1, breakingUnitPrice: null);
      final editing = buildEditableTimingRecord().copyWith(isBreaking: true);

      await pumpTimingDetail(tester, editing: editing, devices: [device]);

      expect(find.text('破碎'), findsOneWidget);
    },
  );

  testWidgets('hides breaking selector for loaders', (
    WidgetTester tester,
  ) async {
    await pumpTimingDetail(
      tester,
      devices: [
        buildDevice(
          id: 1,
          breakingUnitPrice: 180,
          equipmentType: EquipmentType.loader,
        ),
      ],
    );

    expect(find.text('破碎'), findsNothing);
  });

  testWidgets('opens the calculator sheet when tapping the hours field', (
    WidgetTester tester,
  ) async {
    final device = buildDevice(id: 1);
    final editing = buildEditableTimingRecord();

    await pumpTimingDetail(tester, editing: editing, devices: [device]);

    final hoursField = find.widgetWithText(TextField, '工时（小时）');
    final textField = tester.widget<TextField>(hoursField);
    expect(textField.readOnly, isTrue);
    expect(textField.canRequestFocus, isFalse);
    expect(textField.showCursor, isFalse);
    expect(textField.enableInteractiveSelection, isFalse);
    expect(
      textField.keyboardType,
      isNot(const TextInputType.numberWithOptions(decimal: true)),
    );

    await tester.tap(hoursField);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, '='), findsOneWidget);
    expect(find.text('填入'), findsOneWidget);
    expect(find.text('未计算'), findsOneWidget);

    await closeCalculatorSheet(tester);
    expect(focusedEditableTexts(), findsNothing);
  });

  testWidgets('opens the calculator sheet when tapping the calculator icon', (
    WidgetTester tester,
  ) async {
    final device = buildDevice(id: 1);
    final editing = buildEditableTimingRecord();

    await pumpTimingDetail(tester, editing: editing, devices: [device]);

    await tester.tap(find.byTooltip('工时计算依据'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, '='), findsOneWidget);
    expect(find.text('填入'), findsOneWidget);
  });

  testWidgets('editing date picker updates draft and submit writes startDate', (
    WidgetTester tester,
  ) async {
    final key = GlobalKey<TimingDetailContentState>();
    TimingRecord? submittedRecord;

    await pumpTimingDetail(
      tester,
      key: key,
      editing: buildEditableTimingRecord(),
      devices: [buildDevice(id: 1)],
      onSubmit: (record, _) async {
        submittedRecord = record;
      },
    );

    expect(find.text('2026.03.15'), findsOneWidget);

    await tester.tap(find.text('2026.03.15'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('jzt-date-picker-day-20260320')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '完成'));
    await tester.pumpAndSettle();

    expect(find.text('2026.03.20'), findsOneWidget);
    expect(submittedRecord, isNull);

    await key.currentState!.submit();
    await tester.pumpAndSettle();

    expect(submittedRecord?.startDate, 20260320);
  });

  testWidgets('closing date picker keeps editing draft unchanged', (
    WidgetTester tester,
  ) async {
    final key = GlobalKey<TimingDetailContentState>();
    TimingRecord? submittedRecord;

    await pumpTimingDetail(
      tester,
      key: key,
      editing: buildEditableTimingRecord(),
      devices: [buildDevice(id: 1)],
      onSubmit: (record, _) async {
        submittedRecord = record;
      },
    );

    await tester.tap(find.text('2026.03.15'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('2026.03.15'), findsOneWidget);

    await key.currentState!.submit();
    await tester.pumpAndSettle();

    expect(submittedRecord?.startDate, 20260315);
  });

  testWidgets(
    'hours editor hides end date entry and preserves existing cutoff',
    (WidgetTester tester) async {
      final key = GlobalKey<TimingDetailContentState>();
      TimingRecord? submittedRecord;

      await pumpTimingDetail(
        tester,
        key: key,
        editing: buildEditableTimingRecord(
          allocationCutoffExclusiveYmd: 20260319,
        ),
        devices: [buildDevice(id: 1)],
        onSubmit: (record, _) async {
          submittedRecord = record;
        },
      );

      final uiCopy = collectUiCopy(tester);
      expect(uiCopy, isNot(contains('结束日')));
      expect(uiCopy, isNot(contains('只影响收入图表月份分布，不改变项目总应收')));

      await key.currentState!.submit();
      await tester.pumpAndSettle();

      expect(submittedRecord?.allocationCutoffDate, 20260319);
      expect(submittedRecord?.displayEndDate, isNull);
      expect(submittedRecord?.income, 0);
    },
  );

  testWidgets('new hours record submits null cutoff without end date entry', (
    WidgetTester tester,
  ) async {
    final key = GlobalKey<TimingDetailContentState>();
    TimingRecord? submittedRecord;

    await pumpTimingDetail(
      tester,
      key: key,
      devices: [buildDevice(id: 1)],
      onSubmit: (record, _) async {
        submittedRecord = record;
      },
    );

    await tester.enterText(find.widgetWithText(TextField, '联系人'), '新甲方');
    await tester.enterText(find.widgetWithText(TextField, '使用地址/工地'), '新工地');

    await key.currentState!.submit();
    await tester.pumpAndSettle();

    expect(submittedRecord?.type, TimingType.hours);
    expect(submittedRecord?.allocationCutoffDate, isNull);
    expect(submittedRecord?.displayEndDate, isNull);
  });

  testWidgets('new timing date picker updates draft before creating record', (
    WidgetTester tester,
  ) async {
    final key = GlobalKey<TimingDetailContentState>();
    TimingRecord? submittedRecord;

    await pumpTimingDetail(
      tester,
      key: key,
      devices: [buildDevice(id: 1)],
      onSubmit: (record, _) async {
        submittedRecord = record;
      },
    );

    await tester.tap(find.byTooltip('选择日期'));
    await tester.pumpAndSettle();
    final defaultPickerMonth = visibleInitialPickerMonth(DateTime.now());
    final pickedDate = DateTime(
      defaultPickerMonth.year,
      defaultPickerMonth.month,
      2,
    );
    final pickedDateYmd = ymdFromDate(pickedDate);
    await tester.tap(
      find.byKey(ValueKey('jzt-date-picker-day-$pickedDateYmd')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '完成'));
    await tester.pumpAndSettle();

    expect(submittedRecord, isNull);
    await tester.enterText(find.widgetWithText(TextField, '联系人'), '新甲方');
    await tester.enterText(find.widgetWithText(TextField, '使用地址/工地'), '新工地');
    await key.currentState!.submit();
    await tester.pumpAndSettle();

    expect(submittedRecord?.id, isNull);
    expect(submittedRecord?.startDate, pickedDateYmd);
  });

  testWidgets('submits an empty calculation history list by default', (
    WidgetTester tester,
  ) async {
    final key = GlobalKey<TimingDetailContentState>();
    List<TimingCalculationHistory>? submittedHistories;

    await pumpTimingDetail(
      tester,
      key: key,
      editing: buildEditableTimingRecord(),
      devices: [buildDevice(id: 1)],
      onSubmit: (_, histories) async {
        submittedHistories = histories;
      },
    );

    await key.currentState!.submit();
    await tester.pumpAndSettle();

    expect(submittedHistories, isEmpty);
  });

  testWidgets('submits staged calculator histories on confirm', (
    WidgetTester tester,
  ) async {
    final key = GlobalKey<TimingDetailContentState>();
    List<TimingCalculationHistory>? submittedHistories;

    await pumpTimingDetail(
      tester,
      key: key,
      editing: buildEditableTimingRecord(
        startMeter: 10,
        endMeter: 10,
        hours: 0,
      ),
      devices: [buildDevice(id: 1)],
      onSubmit: (_, histories) async {
        submittedHistories = histories;
      },
    );

    await tester.tap(find.byTooltip('工时计算依据'));
    await tester.pumpAndSettle();
    expect(find.text('计算依据'), findsNothing);
    expect(find.byTooltip('关闭'), findsNothing);
    expect(find.widgetWithText(TextButton, '关闭'), findsNothing);
    expect(find.widgetWithText(FilledButton, '完成'), findsNothing);
    await tapCalculatorTextKey(tester, '8');
    await tapCalculatorTextKey(tester, '+');
    await tapCalculatorTextKey(tester, '8');
    await tester.tap(find.widgetWithText(FilledButton, '=').last);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('8 + 8 = 16.0 h', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('已填入工时'), findsOneWidget);

    await closeCalculatorSheet(tester);

    final hoursField = tester.widget<TextField>(
      find.widgetWithText(TextField, '工时（小时）'),
    );
    expect(hoursField.controller?.text, '16.0');

    await key.currentState!.submit();
    await tester.pumpAndSettle();

    expect(submittedHistories, hasLength(1));
    final history = submittedHistories!.single;
    expect(history.timingRecordId, 7);
    expect(history.expression, '8+8');
    expect(history.result, 16.0);
    expect(history.ticketCount, 2);
  });

  testWidgets('shows existing histories but submits only staged histories', (
    WidgetTester tester,
  ) async {
    final key = GlobalKey<TimingDetailContentState>();
    List<TimingCalculationHistory>? submittedHistories;

    await pumpTimingDetail(
      tester,
      key: key,
      editing: buildEditableTimingRecord(
        startMeter: 10,
        endMeter: 10,
        hours: 0,
      ),
      devices: [buildDevice(id: 1)],
      existingCalculationHistories: [existingHistory()],
      onSubmit: (_, histories) async {
        submittedHistories = histories;
      },
    );

    await tester.tap(find.byTooltip('工时计算依据'));
    await tester.pumpAndSettle();

    expect(find.textContaining('[已保存]'), findsNothing);
    expect(
      find.textContaining('8 + 8.2 + 7.8 = 24.0 h', findRichText: true),
      findsOneWidget,
    );

    await tapCalculatorTextKey(tester, '8');
    await tapCalculatorTextKey(tester, '+');
    await tapCalculatorTextKey(tester, '8');
    await tester.tap(find.widgetWithText(FilledButton, '=').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('[本次]'), findsNothing);
    expect(
      find.textContaining('8 + 8 = 16.0 h', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('已填入工时'), findsOneWidget);

    await closeCalculatorSheet(tester);
    await key.currentState!.submit();
    await tester.pumpAndSettle();

    expect(submittedHistories, hasLength(1));
    expect(submittedHistories!.single.expression, '8+8');
    expect(submittedHistories!.single.id, isNot('existing-h1'));
  });

  testWidgets('does not submit staged histories after switching to rent mode', (
    WidgetTester tester,
  ) async {
    final key = GlobalKey<TimingDetailContentState>();
    List<TimingCalculationHistory>? submittedHistories;

    await pumpTimingDetail(
      tester,
      key: key,
      editing: buildEditableTimingRecord(
        startMeter: 10,
        endMeter: 10,
        hours: 0,
      ),
      devices: [buildDevice(id: 1)],
      onSubmit: (_, histories) async {
        submittedHistories = histories;
      },
    );

    await tester.tap(find.byTooltip('工时计算依据'));
    await tester.pumpAndSettle();
    await tapCalculatorTextKey(tester, '8');
    await tapCalculatorTextKey(tester, '+');
    await tapCalculatorTextKey(tester, '8');
    await tester.tap(find.widgetWithText(FilledButton, '=').last);
    await tester.pumpAndSettle();
    await closeCalculatorSheet(tester);

    await tester.tap(find.text('租金(台班)'));
    await tester.pumpAndSettle();
    await key.currentState!.submit();
    await tester.pumpAndSettle();

    expect(submittedHistories, isEmpty);
  });

  testWidgets('hides calculator entry in rent mode', (
    WidgetTester tester,
  ) async {
    await pumpTimingDetail(
      tester,
      editing: buildEditableTimingRecord().copyWith(
        type: TimingType.rent,
        income: 500,
      ),
      devices: [buildDevice(id: 1)],
      existingCalculationHistories: [existingHistory()],
    );

    expect(find.byTooltip('工时计算依据'), findsNothing);
    final hoursField = tester.widget<TextField>(
      find.widgetWithText(TextField, '工时（小时，可空）'),
    );
    expect(hoursField.readOnly, isFalse);
    expect(hoursField.canRequestFocus, isTrue);
    expect(hoursField.enableInteractiveSelection, isTrue);
    expect(
      hoursField.keyboardType,
      const TextInputType.numberWithOptions(decimal: true),
    );
  });

  testWidgets('rent editor hides end date entry and preserves display end', (
    WidgetTester tester,
  ) async {
    final key = GlobalKey<TimingDetailContentState>();
    TimingRecord? submittedRecord;

    await pumpTimingDetail(
      tester,
      key: key,
      editing: buildEditableTimingRecord(
        type: TimingType.rent,
        income: 500,
        allocationCutoffExclusiveYmd: 20260319,
        displayEndDate: 20260318,
      ),
      devices: [buildDevice(id: 1)],
      onSubmit: (record, _) async {
        submittedRecord = record;
      },
    );

    final uiCopy = collectUiCopy(tester);
    expect(uiCopy, isNot(contains('结束日')));
    expect(uiCopy, isNot(contains('仅用于记录展示，不影响收入和结清。')));

    await key.currentState!.submit();
    await tester.pumpAndSettle();

    expect(submittedRecord?.type, TimingType.rent);
    expect(submittedRecord?.allocationCutoffDate, isNull);
    expect(submittedRecord?.displayEndDate, 20260318);
  });

  testWidgets('new rent record submits null display end without entry', (
    WidgetTester tester,
  ) async {
    final key = GlobalKey<TimingDetailContentState>();
    TimingRecord? submittedRecord;

    await pumpTimingDetail(
      tester,
      key: key,
      devices: [buildDevice(id: 1)],
      onSubmit: (record, _) async {
        submittedRecord = record;
      },
    );

    await tester.tap(find.text('租金(台班)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '联系人'), '新甲方');
    await tester.enterText(find.widgetWithText(TextField, '使用地址/工地'), '新工地');
    await tester.enterText(find.widgetWithText(TextField, '金额（元）'), '500');

    await key.currentState!.submit();
    await tester.pumpAndSettle();

    expect(submittedRecord?.type, TimingType.rent);
    expect(submittedRecord?.displayEndDate, isNull);
    expect(submittedRecord?.allocationCutoffDate, isNull);
  });

  testWidgets(
    'switching mode does not cross-write display and allocation ends',
    (WidgetTester tester) async {
      final key = GlobalKey<TimingDetailContentState>();
      final submitted = <TimingRecord>[];

      await pumpTimingDetail(
        tester,
        key: key,
        editing: buildEditableTimingRecord(
          allocationCutoffExclusiveYmd: 20260319,
        ),
        devices: [buildDevice(id: 1)],
        onSubmit: (record, _) async {
          submitted.add(record);
        },
      );

      await tester.tap(find.text('租金(台班)'));
      await tester.pumpAndSettle();
      await key.currentState!.submit();
      await tester.pumpAndSettle();

      expect(submitted.single.type, TimingType.rent);
      expect(submitted.single.allocationCutoffDate, isNull);
      expect(submitted.single.displayEndDate, isNull);
    },
  );

  testWidgets('switching rent to hours does not reuse display end as cutoff', (
    WidgetTester tester,
  ) async {
    final key = GlobalKey<TimingDetailContentState>();
    TimingRecord? submittedRecord;

    await pumpTimingDetail(
      tester,
      key: key,
      editing: buildEditableTimingRecord(
        type: TimingType.rent,
        income: 500,
        displayEndDate: 20260318,
      ),
      devices: [buildDevice(id: 1)],
      onSubmit: (record, _) async {
        submittedRecord = record;
      },
    );

    await tester.tap(find.text('工时'));
    await tester.pumpAndSettle();
    await key.currentState!.submit();
    await tester.pumpAndSettle();

    expect(submittedRecord?.type, TimingType.hours);
    expect(submittedRecord?.allocationCutoffDate, isNull);
    expect(submittedRecord?.displayEndDate, isNull);
  });
}

DateTime visibleInitialPickerMonth(DateTime initialDate) {
  final day = DateTime(initialDate.year, initialDate.month, initialDate.day);
  if (day.isBefore(DateTime(2026, 1, 1))) {
    return DateTime(2026, 1);
  }
  if (day.isAfter(DateTime(2027, 12, 31))) {
    return DateTime(2027, 12);
  }
  return DateTime(day.year, day.month);
}

int ymdFromDate(DateTime date) {
  return date.year * 10000 + date.month * 100 + date.day;
}
