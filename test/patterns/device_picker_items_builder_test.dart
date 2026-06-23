import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/l10n/gen/app_localizations_en.dart';
import 'package:asset_ledger/l10n/gen/app_localizations_zh.dart';
import 'package:asset_ledger/patterns/device/device_picker_items_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'buildDevicePickerItems localizes Chinese labels without copy drift',
    () {
      final items = buildDevicePickerItems(
        l10n: AppLocalizationsZh(),
        activeDevices: [_device(id: 1, name: 'SANY 1#')],
        allDevices: [_device(id: 1, name: 'SANY 1#')],
        currentMeterResolver: _meter,
      );

      expect(items.single.label, 'SANY 1#（码表 123.4 h）');
    },
  );

  test('buildDevicePickerItems localizes inactive and unknown labels', () {
    final items = buildDevicePickerItems(
      l10n: AppLocalizationsEn(),
      activeDevices: const [],
      allDevices: [_device(id: 2, name: 'CAT 2#', isActive: false)],
      currentMeterResolver: _meter,
      selectedId: 2,
    );

    expect(items.single.label, 'CAT 2# (inactive · meter 123.4 h)');

    final missing = buildDevicePickerItems(
      l10n: AppLocalizationsEn(),
      activeDevices: const [],
      allDevices: const [],
      currentMeterResolver: _meter,
      selectedId: 9,
    );
    expect(missing.single.label, 'Unknown device (inactive)');
  });
}

Device _device({required int id, required String name, bool isActive = true}) {
  return Device(
    id: id,
    name: name,
    brand: 'SANY',
    defaultUnitPrice: 100,
    baseMeterHours: 0,
    isActive: isActive,
  );
}

double _meter({required int deviceId, required double baseMeterHours}) => 123.4;
