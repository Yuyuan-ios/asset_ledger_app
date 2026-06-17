import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/features/device/application/device_editor_initial_device_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveDeviceEditorInitialDeviceContext', () {
    test('new record uses the latest active timing device context', () {
      final context = resolveDeviceEditorInitialDeviceContext(
        isEditing: false,
        editingDeviceId: null,
        timingRecords: [
          _timingRecord(id: 1, deviceId: 1, contact: '最近联系人', site: '最近工地'),
          _timingRecord(id: 2, deviceId: 2, contact: '旧联系人', site: '旧工地'),
        ],
        activeDevices: [_device(id: 1), _device(id: 2)],
      );

      expect(context.deviceId, 1);
      expect(context.sourceTimingRecord?.contact, '最近联系人');
      expect(context.sourceTimingRecord?.site, '最近工地');
    });

    test('new record skips inactive latest timing device context', () {
      final inactive = _device(id: 1, isActive: false);
      final active = _device(id: 2);

      final context = resolveDeviceEditorInitialDeviceContext(
        isEditing: false,
        editingDeviceId: null,
        timingRecords: [
          _timingRecord(
            id: 1,
            deviceId: inactive.id!,
            contact: '停用联系人',
            site: '停用工地',
          ),
          _timingRecord(
            id: 2,
            deviceId: active.id!,
            contact: '在用联系人',
            site: '在用工地',
          ),
        ],
        activeDevices: [active],
      );

      expect(context.deviceId, active.id);
      expect(context.sourceTimingRecord?.contact, '在用联系人');
      expect(context.sourceTimingRecord?.site, '在用工地');
    });

    test('editing record keeps its historical inactive device', () {
      final context = resolveDeviceEditorInitialDeviceContext(
        isEditing: true,
        editingDeviceId: 1,
        timingRecords: [_timingRecord(id: 1, deviceId: 2)],
        activeDevices: [_device(id: 2)],
      );

      expect(context.deviceId, 1);
      expect(context.sourceTimingRecord, isNull);
    });

    test('editing record can keep null device id', () {
      final context = resolveDeviceEditorInitialDeviceContext(
        isEditing: true,
        editingDeviceId: null,
        timingRecords: [_timingRecord(id: 1, deviceId: 2)],
        activeDevices: [_device(id: 2)],
      );

      expect(context.deviceId, isNull);
      expect(context.sourceTimingRecord, isNull);
    });

    test(
      'new record returns empty context when no timing record uses active devices',
      () {
        final context = resolveDeviceEditorInitialDeviceContext(
          isEditing: false,
          editingDeviceId: null,
          timingRecords: [_timingRecord(id: 1, deviceId: 1)],
          activeDevices: [_device(id: 2)],
        );

        expect(context.deviceId, isNull);
        expect(context.sourceTimingRecord, isNull);
      },
    );

    test('device id wrapper delegates to the context resolver', () {
      final selected = resolveDeviceEditorInitialDeviceId(
        isEditing: false,
        editingDeviceId: null,
        timingRecords: [_timingRecord(id: 1, deviceId: 1)],
        activeDevices: [_device(id: 1)],
      );

      expect(selected, 1);
    });
  });
}

Device _device({required int id, bool isActive = true}) {
  return Device(
    id: id,
    name: 'SANY $id#',
    brand: 'SANY',
    defaultUnitPrice: 100,
    baseMeterHours: 0,
    isActive: isActive,
  );
}

TimingRecord _timingRecord({
  required int id,
  required int deviceId,
  String contact = '李洋',
  String site = '万达',
}) {
  return TimingRecord(
    id: id,
    deviceId: deviceId,
    startDate: 20260617,
    contact: contact,
    site: site,
    type: TimingType.hours,
    startMeter: 0,
    endMeter: 1,
    hours: 1,
    income: 100,
  );
}
