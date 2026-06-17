import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/features/device/domain/services/device_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('indexMapById replaces inactive device index with inactive label', () {
    final devices = [
      Device(
        id: 1,
        name: 'SANY 1#',
        brand: 'SANY',
        defaultUnitPrice: 100,
        baseMeterHours: 0,
        isActive: false,
      ),
      Device(
        id: 2,
        name: 'HITACHI 1#',
        brand: 'HITACHI',
        defaultUnitPrice: 120,
        baseMeterHours: 0,
      ),
    ];

    expect(DeviceLabel.indexMapById(devices), {1: '1#', 2: '1#'});
    expect(DeviceLabel.indexMapById(devices, inactiveLabel: '已停用'), {
      1: '已停用',
      2: '1#',
    });
  });

  test('replaceIndexLabel keeps brand while replacing the numbered suffix', () {
    expect(DeviceLabel.replaceIndexLabel('SANY 1#', '已停用'), 'SANY 已停用');
    expect(DeviceLabel.replaceIndexLabel('SANY', '已停用'), 'SANY 已停用');
  });

  test('displayName preserves active names and marks inactive devices', () {
    final inactive = Device(
      id: 1,
      name: 'SANY 1#',
      brand: 'SANY',
      defaultUnitPrice: 100,
      baseMeterHours: 0,
      isActive: false,
    );
    final active = Device(
      id: 2,
      name: 'HITACHI 1#',
      brand: 'HITACHI',
      defaultUnitPrice: 120,
      baseMeterHours: 0,
    );

    expect(DeviceLabel.displayName(inactive, inactiveLabel: '已停用'), 'SANY 已停用');
    expect(DeviceLabel.displayName(active, inactiveLabel: '已停用'), 'HITACHI 1#');
    expect(
      DeviceLabel.displayNameMapById([inactive, active], inactiveLabel: '已停用'),
      {1: 'SANY 已停用', 2: 'HITACHI 1#'},
    );
  });
}
