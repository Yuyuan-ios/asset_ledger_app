import '../../../core/money/amount_policy.dart';
import '../../../data/models/device.dart';
import '../../../data/models/project_device_rate.dart';
import '../../../data/models/timing_record.dart';
import '../../../data/services/account_service.dart';
import '../../../data/services/project_resolver.dart';

class TimingPreviewIncomeUseCase {
  const TimingPreviewIncomeUseCase({required ProjectResolver projectResolver})
    : _projectResolver = projectResolver;

  final ProjectResolver _projectResolver;

  Future<double> execute({
    required TimingRecord? editing,
    required int deviceId,
    required String contact,
    required String site,
    required bool isBreaking,
    required double hours,
    required List<Device> devices,
    required List<ProjectDeviceRate> rates,
  }) async {
    final projectId =
        editing?.effectiveProjectId ??
        await _projectResolver.resolveExistingActiveProjectId(
          contact: contact,
          site: site,
        );
    final effectiveRate = AccountService.buildEffectiveRateMap(
      projectId: projectId ?? '',
      devices: devices,
      rates: rates,
      isBreaking: isBreaking,
    );
    final rate = effectiveRate[deviceId] ?? 0.0;
    return AmountPolicy.calculateAmount(
      hours: WorkHours.fromHours(hours),
      unitPrice: UnitPrice.fromYuanPerHour(rate),
    ).yuan;
  }
}
