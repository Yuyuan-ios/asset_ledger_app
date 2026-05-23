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
            records: const [],
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
  }) {
    return TimingRecord(
      id: 7,
      deviceId: 1,
      startDate: 20260315,
      contact: '何小波',
      site: 'A工地',
      type: TimingType.hours,
      startMeter: startMeter,
      endMeter: endMeter,
      hours: hours,
      income: 300,
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
}
