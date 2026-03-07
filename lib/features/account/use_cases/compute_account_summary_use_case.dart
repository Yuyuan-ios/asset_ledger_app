import '../../../data/models/account_payment.dart';
import '../../../data/models/device.dart';
import '../../../data/models/project_device_rate.dart';
import '../../../data/models/timing_record.dart';
import '../../../data/services/account_service.dart';
import '../state/account_store.dart';

class ComputeAccountSummaryUseCase {
  const ComputeAccountSummaryUseCase();

  AccountComputed execute({
    required List<TimingRecord> timingRecords,
    required List<Device> devices,
    required List<ProjectDeviceRate> rates,
    required List<AccountPayment> payments,
  }) {
    final projects = AccountService.buildProjects(timingRecords: timingRecords);
    final receivableByDevice = AccountService.calcReceivableByDevice(
      timingRecords: timingRecords,
      devices: devices,
      rates: rates,
    );

    final keys = projects.keys.toList()
      ..sort((a, b) => projects[b]!.minYmd.compareTo(projects[a]!.minYmd));

    final items = <AccountProjectVM>[];
    double totalReceivable = 0.0;
    double totalReceived = 0.0;

    for (final key in keys) {
      final agg = projects[key]!;

      final money = AccountService.calcMoney(
        agg: agg,
        devices: devices,
        rates: rates,
        payments: payments,
      );

      totalReceivable += money.receivable;
      totalReceived += money.received;

      final rateInfo = AccountService.calcRateInfo(
        agg: agg,
        devices: devices,
        rates: rates,
      );

      items.add(
        AccountProjectVM(
          projectKey: agg.projectKey,
          displayName: agg.pk.displayName,
          minYmd: agg.minYmd,
          deviceIds: agg.deviceIds,
          hoursByDevice: agg.hoursByDevice,
          rentIncomeTotal: agg.rentIncomeTotal,
          minRate: rateInfo.minRate,
          isMultiDevice: rateInfo.isMultiDevice,
          isMultiMode: rateInfo.isMultiMode,
          receivable: money.receivable,
          received: money.received,
          remaining: money.remaining,
          ratio: money.ratio,
          payments:
              payments.where((payment) => payment.projectKey == agg.projectKey).toList()
                ..sort((a, b) => b.ymd.compareTo(a.ymd)),
        ),
      );
    }

    final remaining = totalReceivable - totalReceived;
    final ratio = (totalReceivable <= 0.0000001)
        ? null
        : (totalReceived / totalReceivable);

    final deviceById = <int, Device>{};
    for (final device in devices) {
      final id = device.id;
      if (id == null) continue;
      deviceById[id] = device;
    }

    final deviceReceivables =
        receivableByDevice.entries
            .where((entry) => entry.value > 0)
            .map((entry) {
              final device =
                  deviceById[entry.key] ??
                  Device(
                    id: entry.key,
                    name: '设备#${entry.key}',
                    brand: '',
                    defaultUnitPrice: 0,
                    baseMeterHours: 0,
                    isActive: false,
                  );
              return AccountDeviceReceivable(
                deviceId: entry.key,
                name: device.name,
                amount: entry.value,
              );
            })
            .toList()
          ..sort((a, b) {
            final byLength = a.name.length.compareTo(b.name.length);
            if (byLength != 0) return byLength;
            return a.name.compareTo(b.name);
          });

    return AccountComputed(
      projects: items,
      totalReceivable: totalReceivable,
      totalReceived: totalReceived,
      totalRemaining: remaining,
      totalRatio: ratio,
      deviceReceivables: deviceReceivables,
    );
  }
}
