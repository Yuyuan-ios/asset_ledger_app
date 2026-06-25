import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:asset_ledger/data/models/project_id.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/services/project_rate_snapshot_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProjectRateSnapshotPlanner', () {
    test(
      'plans only missing hour-record snapshots without overwriting rates',
      () {
        const projectId = 'project:alpha';
        const projectKey = 'Alice||Yard A';
        final legacyProjectId = ProjectId.legacyFromKey(projectKey);

        final snapshots = ProjectRateSnapshotPlanner.missingSnapshots(
          timingRecords: [
            _record(projectId: '', deviceId: 1),
            _record(projectId: '', deviceId: 1),
            _record(projectId: projectId, deviceId: 1),
            _record(projectId: projectId, deviceId: 1, isBreaking: true),
            _record(projectId: projectId, deviceId: 2, isBreaking: true),
            _record(projectId: projectId, deviceId: 2, type: TimingType.rent),
            _record(projectId: projectId, deviceId: 99),
          ],
          devices: [
            _device(id: 1, defaultRateFen: 12000, breakingRateFen: 18000),
            _device(id: 2, defaultRateFen: 22000),
          ],
          rates: [
            ProjectDeviceRate(
              projectKey: projectKey,
              deviceId: 1,
              rate: 0,
              rateFen: 99999,
            ),
            ProjectDeviceRate(
              projectId: projectId,
              projectKey: projectKey,
              deviceId: 1,
              rate: 0,
              rateFen: 88888,
            ),
          ],
        );

        expect(snapshots.map((rate) => rate.toMap()).toList(), [
          {
            'project_id': projectId,
            'project_key': projectKey,
            'device_id': 1,
            'is_breaking': 1,
            'rate_fen': 18000,
          },
          {
            'project_id': projectId,
            'project_key': projectKey,
            'device_id': 2,
            'is_breaking': 1,
            'rate_fen': 22000,
          },
        ]);
        expect(
          snapshots.any((rate) => rate.effectiveProjectId == legacyProjectId),
          isFalse,
        );
      },
    );

    test('uses project id before legacy key when checking existing rates', () {
      const projectId = 'project:alpha';
      const otherProjectId = 'project:beta';
      const projectKey = 'Alice||Yard A';

      final snapshots = ProjectRateSnapshotPlanner.missingSnapshots(
        timingRecords: [_record(projectId: projectId, deviceId: 1)],
        devices: [_device(id: 1, defaultRateFen: 12000)],
        rates: [
          ProjectDeviceRate(
            projectId: otherProjectId,
            projectKey: projectKey,
            deviceId: 1,
            rate: 0,
            rateFen: 99999,
          ),
        ],
      );

      expect(snapshots, hasLength(1));
      expect(snapshots.single.projectId, projectId);
      expect(snapshots.single.rateFen, 12000);
    });
  });
}

TimingRecord _record({
  required String projectId,
  required int deviceId,
  TimingType type = TimingType.hours,
  bool isBreaking = false,
}) {
  return TimingRecord(
    projectId: projectId,
    deviceId: deviceId,
    startDate: 20260625,
    contact: 'Alice',
    site: 'Yard A',
    type: type,
    startMeter: 0,
    endMeter: 1,
    hours: 1,
    income: 0,
    isBreaking: isBreaking,
  );
}

Device _device({
  required int id,
  required int defaultRateFen,
  int? breakingRateFen,
}) {
  return Device(
    id: id,
    name: 'Device $id',
    brand: 'sany',
    defaultUnitPrice: 0,
    defaultUnitPriceFen: defaultRateFen,
    breakingUnitPriceFen: breakingRateFen,
    baseMeterHours: 0,
  );
}
