import 'package:flutter/material.dart';

import '../../data/models/account_payment.dart';
import '../../data/models/device.dart';
import '../../data/models/project_device_rate.dart';
import '../../data/models/project_key.dart';
import '../../data/models/timing_record.dart';
import '../../features/account/state/account_store.dart';
import '../../tokens/mapper/core_tokens.dart';
import 'project_account_detail_content_pattern.dart';

typedef AccountOpenBatchRateEditor =
    Future<void> Function(
      AccountProjectVM project,
      List<Device> devices,
      List<ProjectDeviceRate> rates,
    );

typedef AccountOpenSingleRateEditor =
    Future<void> Function(
      AccountProjectVM project,
      int deviceId,
      bool isBreaking,
      List<Device> devices,
      List<ProjectDeviceRate> rates,
    );

typedef AccountOpenPaymentEditor =
    Future<void> Function({
      required AccountProjectVM project,
      required List<AccountPayment> allPayments,
      AccountPayment? editing,
    });

typedef AccountDeletePayment = Future<void> Function(AccountPayment payment);

class AccountProjectDetailSheet extends StatelessWidget {
  const AccountProjectDetailSheet({
    super.key,
    required this.projectKey,
    required this.timingRecords,
    required this.allDevices,
    required this.allPayments,
    required this.allRates,
    required this.computed,
    required this.onBatchEditRate,
    required this.onEditDeviceRate,
    required this.onAddPayment,
    required this.onEditPayment,
    required this.onDeletePayment,
  });

  final String projectKey;
  final List<TimingRecord> timingRecords;
  final List<Device> allDevices;
  final List<AccountPayment> allPayments;
  final List<ProjectDeviceRate> allRates;
  final AccountComputed computed;
  final AccountOpenBatchRateEditor onBatchEditRate;
  final AccountOpenSingleRateEditor onEditDeviceRate;
  final AccountOpenPaymentEditor onAddPayment;
  final AccountOpenPaymentEditor onEditPayment;
  final AccountDeletePayment onDeletePayment;

  @override
  Widget build(BuildContext context) {
    final hit = computed.projects
        .where((project) => project.projectKey == projectKey)
        .toList();

    if (hit.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(SpaceTokens.pagePadding),
        child: Text('项目不存在或已被清理'),
      );
    }

    final project = hit.first;
    final usedDevices = allDevices
        .where(
          (device) =>
              device.id != null && project.deviceIds.contains(device.id!),
        )
        .toList();

    final normalHoursByDevice = <int, double>{};
    final breakingHoursByDevice = <int, double>{};
    for (final record in timingRecords) {
      if (record.type != TimingType.hours) continue;
      final key = ProjectKey.buildKey(
        contact: record.contact.trim(),
        site: record.site.trim(),
      );
      if (key != project.projectKey) continue;
      final target = record.isBreaking
          ? breakingHoursByDevice
          : normalHoursByDevice;
      target[record.deviceId] = (target[record.deviceId] ?? 0.0) + record.hours;
    }

    final deviceRates = <int, double>{};
    final breakingDeviceRates = <int, double>{};
    for (final rate in allRates) {
      if (rate.projectKey != project.projectKey) continue;
      if (rate.isBreaking) {
        breakingDeviceRates[rate.deviceId] = rate.rate;
      } else {
        deviceRates[rate.deviceId] = rate.rate;
      }
    }

    return ProjectAccountDetailContent(
      title: project.displayName,
      minYmd: project.minYmd,
      devices: usedDevices,
      deviceRates: deviceRates,
      breakingDeviceRates: breakingDeviceRates,
      normalHoursByDevice: normalHoursByDevice,
      breakingHoursByDevice: breakingHoursByDevice,
      receivable: project.receivable,
      remaining: project.remaining,
      payments: project.payments,
      onBatchEditRate: () => onBatchEditRate(project, allDevices, allRates),
      onEditDeviceRate: (deviceId, isBreaking) =>
          onEditDeviceRate(project, deviceId, isBreaking, allDevices, allRates),
      onAddPayment: () =>
          onAddPayment(project: project, allPayments: allPayments),
      onEditPayment: (payment) => onEditPayment(
        project: project,
        allPayments: allPayments,
        editing: payment,
      ),
      onDeletePayment: onDeletePayment,
    );
  }
}
