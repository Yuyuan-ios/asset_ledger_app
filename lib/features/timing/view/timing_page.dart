import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/device_label.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/utils/store_feedback.dart';
import '../../../data/models/device.dart';
import '../../../data/models/timing_record.dart';
import '../../../data/services/timing_suggest_service.dart';
import '../../../data/services/timing_service.dart';
import '../../../features/device/state/device_store.dart';
import '../../../features/timing/state/timing_store.dart';
import '../../../patterns/timing/timing_home_pattern.dart';
import '../../../patterns/layout/bottom_sheet_shell_pattern.dart';
import '../../../components/feedback/app_toast.dart';
import '../../../components/feedback/app_confirm_dialog.dart';
import '../../../patterns/timing/timing_detail_content_pattern.dart';
import '../../../patterns/timing/card_main_chart_pattern.dart';
import '../../../patterns/timing/records_title_pattern.dart';
import '../../../patterns/timing/section_header_pattern.dart';
import '../../../patterns/timing/recent_records_pattern.dart';
import '../../../patterns/device/device_picker_pattern.dart';

class TimingPage extends StatefulWidget {
  const TimingPage({super.key});

  @override
  State<TimingPage> createState() => _TimingPageState();
}

class _TimingPageState extends State<TimingPage> {
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

  void _toast(String msg) {
    if (!mounted) return;
    AppToast.show(context, msg);
  }

  Future<void> _retryLoad() async {
    final timingStore = context.read<TimingStore>();
    final deviceStore = context.read<DeviceStore>();
    await Future.wait([
      timingStore.loadAll(),
      deviceStore.loadAll(),
    ]);
  }

  Future<void> _openTimingEditor({TimingRecord? editing}) async {
    final deviceStore = context.read<DeviceStore>();
    final timingStore = context.read<TimingStore>();
    final formKey = GlobalKey<TimingDetailContentState>();
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
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return AppBottomSheetShell(
          title: editing == null ? '新建计时' : '编辑计时',
          scrollable: false,
          contentPadding: EdgeInsets.zero,
          onCancel: () => Navigator.of(context).pop(),
          onConfirm: () => formKey.currentState?.submit(),
          child: TimingDetailContent(
            key: formKey,
            editing: editing,
            records: timingStore.records,
            activeDevices: deviceStore.activeDevices,
            deviceById: deviceById,
            deviceItems: deviceItems,
            contactSuggestions:
                (query) => TimingSuggestService.contactSuggestions(
                  timingStore.records,
                  query,
                ),
            siteSuggestions:
                (query) =>
                    TimingSuggestService.siteSuggestions(timingStore.records, query),
            onToast: _toast,
            onSubmit: (record) async {
              await timingStore.save(record);
              if (!mounted) return;

              final feedback = storeActionFeedback(timingStore, action: '保存');
              _toast(feedback.message);
              if (!feedback.isSuccess) {
                return;
              }
              Navigator.of(context).pop();
            },
          ),
        );
      },
    );
  }

  Future<bool> _confirmDeleteRecord(TimingRecord record) async {
    if (record.id == null) return false;

    return showAppConfirmDialog(
      context: context,
      title: '删除记录',
      content:
          '⚠️ 删除此记录将产生以下影响：\n\n'
          '• 燃油页：工时模式下对应的燃油效率数据\n\n'
          '• 账户页：对应项目的统计数据\n\n'
          '确定删除这条记录吗？',
      confirmText: '删除',
    );
  }

  Future<bool> _deleteRecord(TimingRecord record) async {
    if (record.id == null) return false;
    if (!mounted) return false;

    final store = context.read<TimingStore>();
    await store.deleteById(record.id!);
    if (!mounted) return false;
    final feedback = storeActionFeedback(store, action: '删除');
    _toast(feedback.message);
    if (!feedback.isSuccess) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final timingStore = context.watch<TimingStore>();
    final deviceStore = context.watch<DeviceStore>();

    final loading = timingStore.loading || deviceStore.loading;
    final error = firstStoreErrorMessage(
      [timingStore, deviceStore],
      action: '读取',
    );
    final deviceById = <int, Device>{};
    for (final d in deviceStore.allDevices) {
      final id = d.id;
      if (id == null) continue;
      deviceById[id] = d;
    }
    final deviceIndexById = DeviceLabel.indexMapById(deviceStore.allDevices);

    return TimingHomePattern(
      header: SectionHeader(onAdd: () => _openTimingEditor()),
      chart: const CardMainChart(),
      recordsTitle: RecordsTitle(count: timingStore.records.length),
      records: SectionRecentRecords(
        records: timingStore.records,
        deviceById: deviceById,
        deviceIndexById: deviceIndexById,
        onTapRecord: (r) => _openTimingEditor(editing: r),
        onConfirmDeleteRecord: _confirmDeleteRecord,
        onDeleteRecord: _deleteRecord,
      ),
      loading: loading,
      error: error,
      onRetry: () => _retryLoad(),
    );
  }
}
