import 'package:asset_ledger/core/measure/energy_type.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/models/timing_calculation_history.dart';
import 'package:asset_ledger/features/timing/domain/services/timing_entry_template.dart';
import 'package:asset_ledger/components/pickers/app_date_picker_dialog.dart';
import 'package:asset_ledger/l10n/gen/app_localizations.dart';
import 'package:asset_ledger/patterns/device/device_picker_pattern.dart';
import 'package:asset_ledger/patterns/timing/timing_detail_content_pattern.dart';
import 'package:asset_ledger/tokens/mapper/core_tokens.dart';
import 'package:asset_ledger/tokens/mapper/sheet_tokens.dart';
import 'package:asset_ledger/tokens/mapper/timing_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpTimingDetail(
    WidgetTester tester, {
    Locale locale = const Locale('zh'),
    GlobalKey<TimingDetailContentState>? key,
    TimingRecord? editing,
    List<TimingRecord> records = const [],
    required List<Device> devices,
    int? initialDeviceId,
    String? initialContact,
    String? initialSite,
    List<TimingCalculationHistory> existingCalculationHistories = const [],
    TimingEntryTemplateResolver? resolveEntryTemplate,
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
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh'), Locale('en')],
        home: Scaffold(
          body: TimingDetailContent(
            key: key,
            editing: editing,
            records: records,
            activeDevices: devices.where((device) => device.isActive).toList(),
            allDevices: devices,
            deviceById: deviceById,
            deviceItems: deviceItems,
            initialDeviceId: initialDeviceId,
            initialContact: initialContact,
            initialSite: initialSite,
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
            resolveEntryTemplate: resolveEntryTemplate,
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
    await tester.tap(
      find.widgetWithText(OutlinedButton, label).hitTestable().last,
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapCalculatorEqualKey(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, '=').hitTestable().last);
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

      expect(find.text('挖斗'), findsOneWidget);
      expect(find.text('破碎'), findsOneWidget);
    },
  );

  testWidgets('renders localized en attachment selector labels', (
    WidgetTester tester,
  ) async {
    await pumpTimingDetail(
      tester,
      locale: const Locale('en'),
      devices: [buildDevice(id: 1, breakingUnitPrice: 180)],
    );

    expect(find.text('Bucket'), findsOneWidget);
    expect(find.text('Breaker'), findsOneWidget);
    expect(find.text('挖斗'), findsNothing);
    expect(find.text('破碎'), findsNothing);
  });

  testWidgets('renders localized zh entry display labels', (
    WidgetTester tester,
  ) async {
    await pumpTimingDetail(
      tester,
      devices: [buildDevice(id: 1, breakingUnitPrice: 180)],
    );

    final uiCopy = collectUiCopy(tester);
    expect(uiCopy, contains('联系人'));
    expect(uiCopy, contains('使用地址/工地'));
    expect(uiCopy, contains('开始工作时间'));
    expect(uiCopy, contains('结束工作时间'));
    expect(find.byTooltip('工时计算依据'), findsOneWidget);

    expect(
      tester.widget<Text>(find.text('开始工作时间')).style?.color,
      SheetColors.fieldLabel,
    );
    expect(
      tester.widget<Text>(find.text('结束工作时间')).style?.color,
      SheetColors.fieldLabel,
    );
    expect(_findBoxBorderColor(SheetColors.fieldBorder), findsWidgets);
    expect(_findSegmentContainersWithBorder(), findsWidgets);
    expect(_findBoxColor(SheetColors.meterBackground), findsNWidgets(2));
    expect(TimingTokens.segmentHeight, SheetTokens.fieldHeight);
    expect(TimingTokens.segmentItemHeight, 44);
    expect(TimingTokens.segmentRadius, 4);
    expect(TimingTokens.segmentTextSize, SheetTokens.fieldTextSize);
    expect(TimingTokens.meterContainerRadius, RadiusTokens.recordCard);
  });

  testWidgets(
    'new timing record defaults contact and site from initial context',
    (WidgetTester tester) async {
      final key = GlobalKey<TimingDetailContentState>();
      TimingRecord? submittedRecord;

      await pumpTimingDetail(
        tester,
        key: key,
        devices: [buildDevice(id: 1), buildDevice(id: 2)],
        initialDeviceId: 2,
        initialContact: '李洋',
        initialSite: '五里山',
        onSubmit: (record, _) async {
          submittedRecord = record;
        },
      );

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == '联系人' &&
              widget.controller?.text == '李洋',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == '使用地址/工地' &&
              widget.controller?.text == '五里山',
        ),
        findsOneWidget,
      );

      await key.currentState!.submit();
      await tester.pumpAndSettle();

      expect(submittedRecord?.deviceId, 2);
      expect(submittedRecord?.contact, '李洋');
      expect(submittedRecord?.site, '五里山');
    },
  );

  testWidgets('renders localized en entry display labels', (
    WidgetTester tester,
  ) async {
    await pumpTimingDetail(
      tester,
      locale: const Locale('en'),
      devices: [buildDevice(id: 1, breakingUnitPrice: 180)],
    );

    var uiCopy = collectUiCopy(tester);
    expect(uiCopy, contains('Contact'));
    expect(uiCopy, contains('Work site/address'));
    expect(uiCopy, contains('Start work time'));
    expect(uiCopy, contains('End work time'));
    expect(find.byTooltip('Work hour calculation basis'), findsOneWidget);
    expect(uiCopy, isNot(contains('开始工作时间')));
    expect(uiCopy, isNot(contains('结束工作时间')));

    await tester.tap(find.text('台班(租金)'));
    await tester.pumpAndSettle();

    uiCopy = collectUiCopy(tester);
    expect(uiCopy, contains('Amount (CNY)'));
  });

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

  testWidgets('uses the entry template energy label for fuel equipment', (
    WidgetTester tester,
  ) async {
    await pumpTimingDetail(tester, devices: [buildDevice(id: 1)]);

    expect(find.text('包油'), findsOneWidget);
    expect(find.text('包油/包电'), findsNothing);
  });

  testWidgets(
    'hides energy marker when the entry template energy type is NONE',
    (WidgetTester tester) async {
      final key = GlobalKey<TimingDetailContentState>();
      TimingRecord? submittedRecord;
      const noEnergyTemplate = TimingEntryTemplate(
        equipmentKey: 'no_energy',
        equipmentLabel: '无能耗设备',
        energyType: EnergyType.none,
        unitLayouts: [
          TimingEntryTemplates.hourLayout,
          TimingEntryTemplates.rentLayout,
        ],
      );

      await pumpTimingDetail(
        tester,
        key: key,
        editing: buildEditableTimingRecord().copyWith(
          excludeFromFuelEfficiency: true,
        ),
        devices: [buildDevice(id: 1)],
        resolveEntryTemplate: (_) => noEnergyTemplate,
        onSubmit: (record, _) async {
          submittedRecord = record;
        },
      );

      expect(find.text('包油'), findsNothing);
      expect(find.text('包油/包电'), findsNothing);

      await key.currentState!.submit();
      await tester.pumpAndSettle();

      expect(submittedRecord?.excludeFromFuelEfficiency, isFalse);
    },
  );

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
      expect(find.text('2026.03.15 - 2026.03.18'), findsOneWidget);

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

  testWidgets('new hours range saves exclusive allocation cutoff', (
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
    final startDate = DateTime(
      defaultPickerMonth.year,
      defaultPickerMonth.month,
      2,
    );
    final endDate = DateTime(
      defaultPickerMonth.year,
      defaultPickerMonth.month,
      4,
    );
    await tester.tap(
      find.byKey(ValueKey('jzt-date-picker-day-${ymdFromDate(startDate)}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(ValueKey('jzt-date-picker-day-${ymdFromDate(endDate)}')),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ElevatedButton, '完成(3天)'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, '完成(3天)'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        '${formatDateForInput(startDate)} - ${formatDateForInput(endDate)}',
      ),
      findsOneWidget,
    );

    await tester.enterText(find.widgetWithText(TextField, '联系人'), '新甲方');
    await tester.enterText(find.widgetWithText(TextField, '使用地址/工地'), '新工地');
    await key.currentState!.submit();
    await tester.pumpAndSettle();

    expect(submittedRecord?.type, TimingType.hours);
    expect(
      submittedRecord?.allocationCutoffDate,
      ymdFromDate(endDate.add(const Duration(days: 1))),
    );
    expect(submittedRecord?.displayEndDate, isNull);
  });

  testWidgets('hours range allows end date on next same-device start date', (
    WidgetTester tester,
  ) async {
    final key = GlobalKey<TimingDetailContentState>();
    TimingRecord? submittedRecord;
    final editing = buildEditableTimingRecord(startDate: 20260315);
    final nextRecord = buildEditableTimingRecord(startDate: 20260320).copyWith(
      id: 8,
      startMeter: 12,
      endMeter: 14,
      contact: '何小波',
      site: 'B工地',
    );

    await pumpTimingDetail(
      tester,
      key: key,
      editing: editing,
      records: [editing, nextRecord],
      devices: [buildDevice(id: 1)],
      onSubmit: (record, _) async {
        submittedRecord = record;
      },
    );

    await tester.tap(find.text('2026.03.15'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('jzt-date-picker-day-20260315')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('jzt-date-picker-day-20260321')),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ElevatedButton, '完成(7天)'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('jzt-date-picker-day-20260320')),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ElevatedButton, '完成(6天)'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, '完成(6天)'));
    await tester.pumpAndSettle();

    await key.currentState!.submit();
    await tester.pumpAndSettle();

    expect(submittedRecord?.allocationCutoffDate, 20260321);
    expect(submittedRecord?.displayEndDate, isNull);
  });

  testWidgets('hours range allows same-day handoff end date', (
    WidgetTester tester,
  ) async {
    final key = GlobalKey<TimingDetailContentState>();
    TimingRecord? submittedRecord;
    final editing = buildEditableTimingRecord(startDate: 20260315);
    final sameDayNext = buildEditableTimingRecord(startDate: 20260315).copyWith(
      id: 8,
      startMeter: 12,
      endMeter: 14,
      contact: '何小波',
      site: 'B工地',
    );

    await pumpTimingDetail(
      tester,
      key: key,
      editing: editing,
      records: [editing, sameDayNext],
      devices: [buildDevice(id: 1)],
      onSubmit: (record, _) async {
        submittedRecord = record;
      },
    );

    await tester.tap(find.text('2026.03.15'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('jzt-date-picker-day-20260315')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('jzt-date-picker-day-20260315')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '完成'));
    await tester.pumpAndSettle();

    await key.currentState!.submit();
    await tester.pumpAndSettle();

    expect(submittedRecord?.allocationCutoffDate, 20260316);
    expect(submittedRecord?.displayEndDate, isNull);
  });

  testWidgets('rent range is not limited by next same-device start date', (
    WidgetTester tester,
  ) async {
    final key = GlobalKey<TimingDetailContentState>();
    TimingRecord? submittedRecord;
    final editing = buildEditableTimingRecord(
      startDate: 20260315,
      type: TimingType.rent,
      income: 300,
    );
    final nextRecord = buildEditableTimingRecord(startDate: 20260320).copyWith(
      id: 8,
      startMeter: 12,
      endMeter: 14,
      contact: '何小波',
      site: 'B工地',
    );

    await pumpTimingDetail(
      tester,
      key: key,
      editing: editing,
      records: [editing, nextRecord],
      devices: [buildDevice(id: 1)],
      onSubmit: (record, _) async {
        submittedRecord = record;
      },
    );

    await tester.tap(find.text('2026.03.15'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('jzt-date-picker-day-20260315')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('jzt-date-picker-day-20260325')),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ElevatedButton, '完成(11天)'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, '完成(11天)'));
    await tester.pumpAndSettle();

    await key.currentState!.submit();
    await tester.pumpAndSettle();

    expect(submittedRecord?.allocationCutoffDate, isNull);
    expect(submittedRecord?.displayEndDate, 20260325);
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
    await tapCalculatorEqualKey(tester);

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
    await tapCalculatorEqualKey(tester);

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
    await tapCalculatorEqualKey(tester);
    await closeCalculatorSheet(tester);

    await tester.tap(find.text('台班(租金)'));
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
      find.widgetWithText(TextField, '工时（小时，选填）'),
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
    expect(find.text('2026.03.15 - 2026.03.18'), findsOneWidget);

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

    await tester.tap(find.text('台班(租金)'));
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

  testWidgets('new rent range saves display end directly', (
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

    await tester.tap(find.text('台班(租金)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('选择日期'));
    await tester.pumpAndSettle();
    final defaultPickerMonth = visibleInitialPickerMonth(DateTime.now());
    final startDate = DateTime(
      defaultPickerMonth.year,
      defaultPickerMonth.month,
      2,
    );
    final endDate = DateTime(
      defaultPickerMonth.year,
      defaultPickerMonth.month,
      4,
    );
    await tester.tap(
      find.byKey(ValueKey('jzt-date-picker-day-${ymdFromDate(startDate)}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(ValueKey('jzt-date-picker-day-${ymdFromDate(endDate)}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '完成(3天)'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '联系人'), '新甲方');
    await tester.enterText(find.widgetWithText(TextField, '使用地址/工地'), '新工地');
    await tester.enterText(find.widgetWithText(TextField, '金额（元）'), '500');
    await key.currentState!.submit();
    await tester.pumpAndSettle();

    expect(submittedRecord?.type, TimingType.rent);
    expect(submittedRecord?.displayEndDate, ymdFromDate(endDate));
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

      await tester.tap(find.text('台班(租金)'));
      await tester.pumpAndSettle();
      await key.currentState!.submit();
      await tester.pumpAndSettle();

      expect(submitted.single.type, TimingType.rent);
      expect(submitted.single.allocationCutoffDate, isNull);
      expect(submitted.single.displayEndDate, 20260318);
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
    expect(submittedRecord?.allocationCutoffDate, 20260319);
    expect(submittedRecord?.displayEndDate, isNull);
  });
}

// 跟随选择器的真实滚动窗口（jztDatePickerFirstDate/LastDate），不再硬编码
// 2026-2027；以 DateTime.now() 调用时今天恒在窗口内，返回今天所在月。
DateTime visibleInitialPickerMonth(DateTime initialDate) {
  final day = DateTime(initialDate.year, initialDate.month, initialDate.day);
  if (day.isBefore(jztDatePickerFirstDate)) {
    return DateTime(jztDatePickerFirstDate.year, jztDatePickerFirstDate.month);
  }
  if (day.isAfter(jztDatePickerLastDate)) {
    return DateTime(jztDatePickerLastDate.year, jztDatePickerLastDate.month);
  }
  return DateTime(day.year, day.month);
}

int ymdFromDate(DateTime date) {
  return date.year * 10000 + date.month * 100 + date.day;
}

String formatDateForInput(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}.$month.$day';
}

Finder _findBoxColor(Color color) {
  return find.byWidgetPredicate((widget) {
    final decoration = widget is Container ? widget.decoration : null;
    return decoration is BoxDecoration && decoration.color == color;
  });
}

Finder _findBoxBorderColor(Color color) {
  return find.byWidgetPredicate((widget) {
    final decoration = widget is Container ? widget.decoration : null;
    final border = decoration is BoxDecoration ? decoration.border : null;
    return border is Border &&
        border.top.color == color &&
        border.right.color == color &&
        border.bottom.color == color &&
        border.left.color == color;
  });
}

Finder _findSegmentContainersWithBorder() {
  return find.byWidgetPredicate((widget) {
    final decoration = widget is Container ? widget.decoration : null;
    return decoration is BoxDecoration &&
        decoration.color == SheetColors.fieldBackground &&
        decoration.border != null;
  });
}
