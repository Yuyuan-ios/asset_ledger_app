import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProjectDeviceRate', () {
    test('toMap uses the persisted composite key fields', () {
      const rate = ProjectDeviceRate(
        projectKey: 'Alice||Yard A',
        deviceId: 2,
        rate: 150.5,
      );

      expect(rate.toMap(), {
        'project_key': 'Alice||Yard A',
        'device_id': 2,
        'is_breaking': 0,
        'rate': 150.5,
      });
    });

    test('fromMap falls back to empty and zero values', () {
      final rebuilt = ProjectDeviceRate.fromMap({
        'rate': 90,
      });

      expect(rebuilt.projectKey, '');
      expect(rebuilt.deviceId, 0);
      expect(rebuilt.rate, 90);
    });
  });
}
