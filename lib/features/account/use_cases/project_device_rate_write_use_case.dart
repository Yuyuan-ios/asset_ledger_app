import '../../../data/models/project_device_rate.dart';

abstract class ProjectDeviceRateWriteUseCase {
  Future<void> upsert(ProjectDeviceRate rate);

  Future<int> delete(
    String projectKey,
    int deviceId, {
    String? projectId,
    bool isBreaking = false,
  });
}
