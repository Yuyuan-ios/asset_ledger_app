import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/patterns/device/device_picker_pattern.dart';
import 'package:asset_ledger/patterns/timing/timing_detail_content_pattern.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpTimingDetail(
    WidgetTester tester, {
    TimingRecord? editing,
    required List<Device> devices,
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
            editing: editing,
            records: const [],
            activeDevices: devices.where((device) => device.isActive).toList(),
            allDevices: devices,
            deviceById: deviceById,
            deviceItems: deviceItems,
            projectRates: const <ProjectDeviceRate>[],
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
            onSubmit: (_) async {},
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
      final editing = TimingRecord(
        id: 7,
        deviceId: 1,
        startDate: 20260315,
        contact: '何小波',
        site: 'A工地',
        type: TimingType.hours,
        startMeter: 10,
        endMeter: 12,
        hours: 2,
        income: 300,
        isBreaking: true,
      );

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
}
