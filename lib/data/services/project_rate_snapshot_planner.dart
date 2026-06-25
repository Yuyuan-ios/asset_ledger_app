import '../models/device.dart';
import '../models/project_device_rate.dart';
import '../models/timing_record.dart';

/// Plans missing project-level unit-price snapshots.
///
/// Project prices are project-scoped facts. Device defaults are only the seed
/// value used when a project/device/mode is first materialized.
class ProjectRateSnapshotPlanner {
  const ProjectRateSnapshotPlanner._();

  static List<ProjectDeviceRate> missingSnapshots({
    required List<TimingRecord> timingRecords,
    required List<Device> devices,
    required List<ProjectDeviceRate> rates,
  }) {
    if (timingRecords.isEmpty || devices.isEmpty) return const [];

    final devicesById = <int, Device>{
      for (final device in devices)
        if (device.id != null) device.id!: device,
    };
    final existing = <_RateKey>{
      for (final rate in rates)
        _RateKey(
          projectId: rate.effectiveProjectId,
          deviceId: rate.deviceId,
          isBreaking: rate.isBreaking,
        ),
    };
    final planned = <_RateKey>{};
    final snapshots = <ProjectDeviceRate>[];

    for (final record in timingRecords) {
      if (record.type != TimingType.hours) continue;
      final projectId = record.effectiveProjectId.trim();
      if (projectId.isEmpty) continue;
      final device = devicesById[record.deviceId];
      if (device == null) continue;

      final key = _RateKey(
        projectId: projectId,
        deviceId: record.deviceId,
        isBreaking: record.isBreaking,
      );
      if (existing.contains(key) || !planned.add(key)) continue;

      final rateFen = record.isBreaking
          ? (device.breakingUnitPriceFen ?? device.defaultUnitPriceFen)
          : device.defaultUnitPriceFen;
      snapshots.add(
        ProjectDeviceRate(
          projectId: projectId,
          projectKey: record.legacyProjectKey,
          deviceId: record.deviceId,
          isBreaking: record.isBreaking,
          rate: 0,
          rateFen: rateFen,
        ),
      );
    }

    return snapshots;
  }
}

class _RateKey {
  const _RateKey({
    required this.projectId,
    required this.deviceId,
    required this.isBreaking,
  });

  final String projectId;
  final int deviceId;
  final bool isBreaking;

  @override
  bool operator ==(Object other) {
    return other is _RateKey &&
        other.projectId == projectId &&
        other.deviceId == deviceId &&
        other.isBreaking == isBreaking;
  }

  @override
  int get hashCode => Object.hash(projectId, deviceId, isBreaking);
}
