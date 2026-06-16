import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:asset_ledger/data/models/project_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProjectDeviceRate', () {
    test('toMap uses fen-only persisted composite key fields', () {
      final rate = ProjectDeviceRate(
        projectKey: 'Alice||Yard A',
        deviceId: 2,
        rate: 150.5,
      );

      expect(rate.toMap(), {
        'project_id': ProjectId.legacyFromKey('Alice||Yard A'),
        'project_key': 'Alice||Yard A',
        'device_id': 2,
        'is_breaking': 0,
        'rate_fen': 15050,
      });
    });

    test('fromMap requires rate_fen and derives yuan rate from fen', () {
      final rebuilt = ProjectDeviceRate.fromMap({'rate_fen': 9001});

      expect(rebuilt.projectKey, '');
      expect(rebuilt.projectId, '');
      expect(rebuilt.deviceId, 0);
      expect(rebuilt.rateFen, 9001);
      expect(rebuilt.rate, 90.01);
    });

    test('fromMap rejects legacy rows without rate_fen', () {
      expect(
        () => ProjectDeviceRate.fromMap({'rate': 90}),
        throwsA(isA<StateError>()),
      );
    });
  });
}
