import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/device_label.dart';
import '../../../core/utils/format_utils.dart';
import '../../../data/models/device.dart';
import '../../../data/models/fuel_log.dart';
import '../../../data/models/timing_record.dart';
import '../../../data/services/timing_service.dart';
import '../../../features/device/state/device_controller.dart';
import '../../../features/fuel/state/fuel_controller.dart';
import '../../../patterns/fuel/fuel_home_pattern.dart';
import '../../../tokens/mapper/core_tokens.dart';
import '../../../tokens/mapper/fuel_tokens.dart';
import '../../timing/state/timing_controller.dart';
import '../../../patterns/timing/section_header_pattern.dart';
import '../../../patterns/layout/bottom_sheet_shell_pattern.dart';
import '../../../components/feedback/app_confirm_dialog.dart';
import '../../../components/avatars/app_device_avatar.dart';
import '../../../patterns/fuel/fuel_detail_content_pattern.dart';
import '../../../patterns/fuel/fuel_efficiency_summary_pattern.dart';
import '../../../patterns/fuel/fuel_recent_records_pattern.dart';
import '../../../patterns/fuel/fuel_summary_card_pattern.dart';
import '../../../patterns/fuel/fuel_supplier_filter_pattern.dart';
import '../../../patterns/device/device_picker_pattern.dart';

class FuelPage extends StatefulWidget {
  const FuelPage({super.key});

  @override
  State<FuelPage> createState() => _FuelPageState();
}

class _FuelPageState extends State<FuelPage> {
  final _supplierFilterCtrl = TextEditingController();
  String _supplierFilter = '';

  List<DevicePickerItemVm> _buildDevicePickerItems({
    required List<Device> activeDevices,
    required List<Device> allDevices,
    required List<TimingRecord> records,
    int? selectedId,
  }) {
    final items = <DevicePickerItemVm>[];
    final activeIds = <int>{};

    for (final d in activeDevices) {
      final id = d.id;
      if (id == null) continue;
      activeIds.add(id);
      final meter = TimingService.currentMeter(
        records,
        id,
        baseMeterHours: d.baseMeterHours,
      );
      final meterText = FormatUtils.meter(meter);
      items.add(
        DevicePickerItemVm(
          id: id,
          label: '${d.name}（码表 $meterText h）',
          enabled: true,
        ),
      );
    }

    if (selectedId != null && !activeIds.contains(selectedId)) {
      final selected = allDevices.firstWhere(
        (d) => d.id == selectedId,
        orElse: () => const Device(
          id: -1,
          name: '未知设备',
          brand: '',
          defaultUnitPrice: 0,
          baseMeterHours: 0,
          isActive: false,
        ),
      );
      final labelId = selected.id ?? selectedId;
      if (labelId >= 0) {
        final meter = TimingService.currentMeter(
          records,
          labelId,
          baseMeterHours: selected.baseMeterHours,
        );
        final meterText = FormatUtils.meter(meter);
        items.insert(
          0,
          DevicePickerItemVm(
            id: labelId,
            label: '${selected.name}（已停用 · 码表 $meterText h）',
            enabled: false,
          ),
        );
      } else {
        items.insert(
          0,
          DevicePickerItemVm(
            id: selectedId,
            label: '未知设备（已停用）',
            enabled: false,
          ),
        );
      }
    }

    return items;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final deviceStore = context.read<DeviceStore>();
      final timingStore = context.read<TimingStore>();
      final fuelStore = context.read<FuelStore>();
      await deviceStore.loadAll();
      await timingStore.loadAll();
      await fuelStore.loadAll();
    });
  }

  @override
  void dispose() {
    _supplierFilterCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: AppDurations.snackBar),
    );
  }

  Future<void> _openFuelEditor({FuelLog? editing}) async {
    final deviceStore = context.read<DeviceStore>();
    final timingStore = context.read<TimingStore>();
    final fuelStore = context.read<FuelStore>();
    final deviceById = <int, Device>{};
    for (final d in deviceStore.allDevices) {
      final id = d.id;
      if (id == null) continue;
      deviceById[id] = d;
    }
    final deviceItems = _buildDevicePickerItems(
      activeDevices: deviceStore.activeDevices,
      allDevices: deviceStore.allDevices,
      records: timingStore.records,
      selectedId: editing?.deviceId,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return AppBottomSheetShell(
          title: editing == null ? '新增燃油' : '编辑燃油',
          scrollable: false,
          child: FuelDetailContent(
            editing: editing,
            logs: fuelStore.logs,
            activeDevices: deviceStore.activeDevices,
            deviceById: deviceById,
            deviceItems: deviceItems,
            supplierSuggestions: (q) => fuelStore.supplierSuggestions(
              q,
              limit: 9999,
            ),
            onCancel: () => Navigator.of(ctx).pop(),
            onToast: _toast,
            onSubmit: (log) async {
              if (log.id == null) {
                await fuelStore.insert(log);
              } else {
                await fuelStore.update(log);
              }

              if (!mounted) return;
              if (fuelStore.error != null) {
                _toast('保存失败：${fuelStore.error}');
                return;
              }

              _toast('已保存');
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
            },
          ),
        );
      },
    );
  }

  Future<bool> _confirmDelete(FuelLog log) async {
    if (log.id == null) return false;
    final ok = await showAppConfirmDialog(
      context: context,
      title: '确认删除？',
      content: '删除后不可恢复。',
      confirmText: '删除',
    );
    return ok == true;
  }

  Future<bool> _delete(FuelLog log) async {
    if (log.id == null) return false;
    if (!mounted) return false;

    final store = context.read<FuelStore>();
    await store.deleteById(log.id!);

    if (!mounted) return false;
    if (store.error != null) {
      _toast('删除失败：${store.error}');
      return false;
    } else {
      _toast('已删除');
      return true;
    }
  }

  List<FuelLog> _filteredLogs(List<FuelLog> logs) {
    if (_supplierFilter.isEmpty) return logs;
    return logs.where((e) => e.supplier.contains(_supplierFilter)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final fuelStore = context.watch<FuelStore>();
    final deviceStore = context.watch<DeviceStore>();
    final timingStore = context.watch<TimingStore>();

    final loading =
        fuelStore.loading || deviceStore.loading || timingStore.loading;
    final err = fuelStore.error ?? deviceStore.error ?? timingStore.error;

    final nowYmd = FormatUtils.ymdFromDate(DateTime.now());
    final supplier = _supplierFilter.trim().isEmpty
        ? null
        : _supplierFilter.trim();
    final yearSummary = fuelStore.currentYearSummary(
      nowYmd: nowYmd,
      supplier: supplier,
    );
    final yearSummaryTitle = supplier == null ? '本年度总消耗' : '本年度（$supplier）';

    final byDevice = fuelStore.efficiencyByDeviceAllTime(timingStore.records);
    final filteredLogs = _filteredLogs(fuelStore.logs);
    final deviceIndexById = DeviceLabel.indexMapById(deviceStore.allDevices);

    final summary = FuelSummaryCard(
      height: FuelTokens.efficiencyCardHeight,
      child: Padding(
        padding: const EdgeInsets.all(FuelTokens.summaryInnerPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FuelEfficiencySummary(
                byDevice: byDevice,
                deviceNameOf: (id) {
                  final d = deviceStore.findById(id);
                  return d?.name ?? '设备$id（已停用/不存在）';
                },
              ),
            ),
            const SizedBox(height: FuelTokens.summaryInnerGap),
            Row(
              children: [
                Text(
                  yearSummaryTitle,
                  style: const TextStyle(
                    fontSize: FuelTokens.summaryTotalLabelSize,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: FuelTokens.summaryTotalValueLeftGap),
                Expanded(
                  child: Text(
                    '${FormatUtils.liters(yearSummary.liters)} L / ${FormatUtils.money(yearSummary.cost)}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: FuelTokens.summaryTotalValueSize,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    final filter = FuelSupplierFilter(
      controller: _supplierFilterCtrl,
      suggestionsBuilder: fuelStore.supplierSuggestions,
      onChanged: (v) => setState(() => _supplierFilter = v.trim()),
      onSelected: (v) {
        _supplierFilterCtrl.text = v;
        setState(() => _supplierFilter = v.trim());
      },
    );

    final records = FuelRecentRecordsSection(
      logs: filteredLogs,
      leadingBuilder: (log) {
        final d = deviceStore.findById(log.deviceId);
        if (d == null) {
          return const CircleAvatar(radius: 18, child: Text('?'));
        }
        return DeviceAvatar(
          brand: d.brand,
          customAvatarPath: d.customAvatarPath,
        );
      },
      titleBuilder: (log) => log.supplier,
      subtitleBuilder: (log) => deviceIndexById[log.deviceId] ?? '?',
      onTap: (log) => _openFuelEditor(editing: log),
      onConfirmDelete: _confirmDelete,
      onDelete: _delete,
    );

    return FuelHomePattern(
      header: SectionHeader(title: '燃油', onAdd: () => _openFuelEditor()),
      summary: summary,
      filter: filter,
      records: records,
      loading: loading,
      error: err,
    );
  }
}
