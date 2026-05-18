import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/store_feedback.dart';
import '../../device/domain/services/device_label.dart';
import '../../device/domain/services/device_lookup.dart';
import '../../account/state/account_store.dart';
import '../../../features/device/state/device_store.dart';
import '../../../features/fuel/state/fuel_store.dart';
import '../../../features/maintenance/state/maintenance_store.dart';
import '../application/controllers/timing_action_controller.dart';
import '../domain/entities/timing_entities.dart';
import '../domain/repositories/timing_calculation_history_repository.dart';
import '../../../features/timing/model/timing_chart_data.dart';
import '../../../features/timing/state/timing_store.dart';
import '../../../features/timing/use_cases/save_timing_record_use_case.dart';
import '../../../features/timing/use_cases/timing_merge_dissolve_port.dart';
import '../../account/state/project_rate_store.dart';
import '../../../patterns/timing/timing_home_pattern.dart';
import '../../../patterns/layout/bottom_sheet_shell_pattern.dart';
import '../../../components/feedback/app_toast.dart';
import '../../../components/feedback/app_confirm_dialog.dart';
import '../../../patterns/timing/timing_detail_content_pattern.dart';
import '../../../patterns/timing/card_main_chart_pattern.dart';
import '../../../patterns/timing/records_title_pattern.dart';
import '../../../patterns/timing/section_header_pattern.dart';
import '../../../patterns/device/device_picker_items_builder.dart';

class TimingPage extends StatefulWidget {
  const TimingPage({
    super.key,
    this.initialTargetYear,
    this.initialTargetMonth,
    this.calculationHistoryRepository,
  });

  final int? initialTargetYear;
  final int? initialTargetMonth;
  final TimingCalculationHistoryRepository? calculationHistoryRepository;

  @override
  State<TimingPage> createState() => _TimingPageState();
}

class _TimingPageState extends State<TimingPage> {
  static const int _minChartYear = 2025;

  late int _targetYear;
  late int _targetMonth;

  int get _maxChartYear => DateTime.now().year;

  int _defaultMonthForYear(int year) {
    final now = DateTime.now();
    return year < now.year ? 12 : now.month;
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // 初始值只负责提供默认统计起点；最终用于图表计算的月份会经过
    // _resolveEffectiveTargetMonth 的正式策略处理。
    _targetYear = widget.initialTargetYear ?? now.year;
    _targetMonth =
        (widget.initialTargetMonth ?? _defaultMonthForYear(_targetYear)).clamp(
          1,
          12,
        );
  }

  TimingChartData _buildChartData({
    required List<TimingRecord> records,
    required List<Device> devices,
    required List<ProjectDeviceRate> rates,
    required List<FuelLog> fuelLogs,
    required List<MaintenanceRecord> maintenanceRecords,
    required List<ProjectWriteOff> projectWriteOffs,
  }) {
    return context.read<TimingActionController>().buildChartData(
      targetYear: _targetYear,
      targetMonth: _targetMonth,
      hasExplicitTargetMonth: widget.initialTargetMonth != null,
      records: records,
      devices: devices,
      rates: rates,
      fuelLogs: fuelLogs,
      maintenanceRecords: maintenanceRecords,
      projectWriteOffs: projectWriteOffs,
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    AppToast.show(context, msg);
  }

  TimingActionController _actionController() {
    final controller = context.read<TimingActionController>();
    final repository = widget.calculationHistoryRepository;
    return repository == null
        ? controller
        : controller.copyWith(calculationHistoryRepository: repository);
  }

  Future<List<TimingCalculationHistory>> _loadExistingCalculationHistories(
    TimingRecord? editing,
  ) async {
    if (editing == null || editing.type != TimingType.hours) {
      return const <TimingCalculationHistory>[];
    }

    final recordId = editing.id;
    if (recordId == null) return const <TimingCalculationHistory>[];

    try {
      return await _actionController().loadExistingCalculationHistories(
        editing,
      );
    } catch (_) {
      _toast('工时计算历史加载失败，仍可继续编辑');
      return const <TimingCalculationHistory>[];
    }
  }

  Future<void> _retryLoad() async {
    final timingStore = context.read<TimingStore>();
    final deviceStore = context.read<DeviceStore>();
    final fuelStore = context.read<FuelStore>();
    final maintenanceStore = context.read<MaintenanceStore>();
    final accountStore = context.read<AccountStore>();
    await Future.wait([
      timingStore.loadAll(),
      deviceStore.loadAll(),
      fuelStore.loadAll(),
      maintenanceStore.loadAll(),
      accountStore.loadAll(),
    ]);
  }

  Future<bool> _retryPendingMergeDissolve({
    required SaveTimingRecordUseCase useCase,
    required PendingTimingMergeDissolve pending,
  }) async {
    final shouldRetry = await showAppConfirmDialog(
      context: context,
      title: '合并项目未解除',
      content: '计时记录已保存，但联系人或地址变化后的合并项目尚未解除。请重试解除后再关闭。',
      cancelText: '留在编辑',
      confirmText: '重试解除',
    );
    if (!mounted) return false;
    if (!shouldRetry) {
      _toast('合并项目尚未解除，可再次点击“确定”重试。');
      return false;
    }

    try {
      final dissolved = await useCase.retryMergeDissolve(pending);
      if (!mounted) return false;
      if (dissolved) {
        _toast('记录已移动到其他项目，系统已自动解除相关合并项目。');
      } else {
        _toast('合并项目已无需解除。');
      }
      return true;
    } catch (_) {
      if (!mounted) return false;
      _toast('自动解除合并仍失败，请再次重试。');
      return false;
    }
  }

  Future<void> _openTimingEditor({TimingRecord? editing}) async {
    final deviceStore = context.read<DeviceStore>();
    final timingStore = context.read<TimingStore>();
    final rateStore = context.read<ProjectRateStore>();
    final formKey = GlobalKey<TimingDetailContentState>();
    final actionController = _actionController();
    final previewIncomeUseCase = actionController.createPreviewIncomeUseCase();
    final existingCalculationHistories =
        await _loadExistingCalculationHistories(editing);
    if (!mounted) return;

    final editorContext = buildDeviceEditorContext(
      activeDevices: deviceStore.activeDevices,
      allDevices: deviceStore.allDevices,
      records: timingStore.records,
      selectedId: editing?.deviceId,
    );

    await openEditorSheet<void>(
      context: context,
      title: editing == null ? '新建计时' : '编辑计时',
      useSafeArea: false,
      onConfirm: () => formKey.currentState?.submit(),
      childBuilder: (sheetContext) {
        return TimingDetailContent(
          key: formKey,
          editing: editing,
          records: timingStore.records,
          activeDevices: deviceStore.activeDevices,
          allDevices: deviceStore.allDevices,
          deviceById: editorContext.deviceById,
          deviceItems: editorContext.deviceItems,
          projectRates: rateStore.rates,
          existingCalculationHistories: existingCalculationHistories,
          contactSuggestions: (query) =>
              actionController.contactSuggestions(timingStore.records, query),
          siteSuggestions: (query) =>
              actionController.siteSuggestions(timingStore.records, query),
          resolveIncome:
              ({
                required int deviceId,
                required String contact,
                required String site,
                required bool isBreaking,
                required double hours,
              }) {
                return previewIncomeUseCase.execute(
                  editing: editing,
                  deviceId: deviceId,
                  contact: contact,
                  site: site,
                  isBreaking: isBreaking,
                  hours: hours,
                  devices: deviceStore.allDevices,
                  rates: rateStore.rates,
                );
              },
          validateMeterBounds:
              ({
                required int deviceId,
                required int startDate,
                required double endMeter,
                int? excludeId,
              }) {
                return actionController.validateMeterBounds(
                  records: timingStore.records,
                  deviceId: deviceId,
                  startDate: startDate,
                  endMeter: endMeter,
                  excludeId: excludeId,
                );
              },
          onToast: _toast,
          onSubmit: (record, calculationHistories) async {
            final saveUseCase = actionController.createSaveUseCase(
              timingStore: timingStore,
              mergeDissolve: context.read<TimingMergeDissolvePort>(),
            );
            SaveTimingRecordResult result;
            try {
              result = await saveUseCase.execute(
                editing: editing,
                record: record,
                calculationHistories: calculationHistories,
              );
            } catch (_) {
              if (!mounted) return;
              final feedback = storeActionFeedback(timingStore, action: '保存');
              _toast(feedback.message);
              return;
            }
            if (!mounted) return;

            final feedback = storeActionFeedback(timingStore, action: '保存');
            if (!feedback.isSuccess) {
              _toast(feedback.message);
              return;
            }
            String? toastMessage = feedback.message;
            final pending = result.pendingMergeDissolve;
            if (pending != null) {
              _toast('项目已保存，但自动解除合并失败，请重试解除。');
              final resolved = await _retryPendingMergeDissolve(
                useCase: saveUseCase,
                pending: pending,
              );
              if (!mounted) return;
              if (!resolved) {
                return;
              }
              toastMessage = null;
            } else if (result.mergeDissolved) {
              toastMessage = '记录已移动到其他项目，系统已自动解除相关合并项目。';
            }
            if (!mounted) return;
            if (toastMessage != null) {
              _toast(toastMessage);
            }
            if (!sheetContext.mounted) return;
            Navigator.of(sheetContext).pop();
          },
        );
      },
    );
  }

  Future<bool> _confirmDeleteRecord(TimingRecord record) async {
    if (record.id == null) return false;

    return showAppConfirmDialog(
      context: context,
      title: '删除记录',
      contentWidget: const _TimingDeleteConfirmContent(),
      confirmText: '删除',
    );
  }

  Future<bool> _confirmDeleteRecords(List<TimingRecord> records) async {
    final count = records.where((record) => record.id != null).length;
    if (count == 0) return false;

    return showAppConfirmDialog(
      context: context,
      title: '删除记录',
      contentWidget: _TimingDeleteConfirmContent(recordCount: count),
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

  Future<bool> _deleteRecords(List<TimingRecord> records) async {
    final ids = records.map((record) => record.id).whereType<int>().toSet();
    if (ids.isEmpty) return false;
    if (!mounted) return false;

    final store = context.read<TimingStore>();
    await store.deleteByIds(ids);
    if (!mounted) return false;
    final feedback = storeActionFeedback(store, action: '删除');
    _toast(feedback.message);
    if (!feedback.isSuccess) {
      return false;
    }
    return true;
  }

  void _moveTargetYear(int delta) {
    final next = _targetYear + delta;
    if (next < _minChartYear || next > _maxChartYear) {
      return;
    }
    setState(() {
      _targetYear = next;
      _targetMonth = _defaultMonthForYear(next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final timingStore = context.watch<TimingStore>();
    final deviceStore = context.watch<DeviceStore>();
    final fuelStore = context.watch<FuelStore>();
    final maintenanceStore = context.watch<MaintenanceStore>();
    final accountStore = context.watch<AccountStore>();

    final loading =
        timingStore.loading ||
        deviceStore.loading ||
        fuelStore.loading ||
        maintenanceStore.loading ||
        accountStore.loading;
    final error = firstStoreErrorMessage([
      timingStore,
      deviceStore,
      fuelStore,
      maintenanceStore,
      accountStore,
    ], action: '读取');
    final deviceById = buildDeviceByIdMap(deviceStore.allDevices);
    final deviceIndexById = DeviceLabel.indexMapById(deviceStore.allDevices);
    final rateStore = context.watch<ProjectRateStore>();
    final chartData = _buildChartData(
      records: timingStore.records,
      devices: deviceStore.allDevices,
      rates: rateStore.rates,
      fuelLogs: fuelStore.logs,
      maintenanceRecords: maintenanceStore.records,
      projectWriteOffs: accountStore.writeOffs,
    );
    final canGoPrevYear = _targetYear > _minChartYear;
    final canGoNextYear = _targetYear < _maxChartYear;

    return TimingHomePattern(
      header: SectionHeader(onAdd: () => _openTimingEditor()),
      chart: CardMainChart(
        data: chartData,
        canGoPrevYear: canGoPrevYear,
        canGoNextYear: canGoNextYear,
        onPrevYear: () => _moveTargetYear(-1),
        onNextYear: () => _moveTargetYear(1),
      ),
      recordsTitle: RecordsTitle(count: timingStore.records.length),
      records: timingStore.records,
      deviceById: deviceById,
      deviceIndexById: deviceIndexById,
      onTapRecord: (r) => _openTimingEditor(editing: r),
      onConfirmDeleteRecord: _confirmDeleteRecord,
      onDeleteRecord: _deleteRecord,
      onConfirmDeleteRecords: _confirmDeleteRecords,
      onDeleteRecords: _deleteRecords,
      loading: loading,
      error: error,
      onRetry: () => _retryLoad(),
    );
  }
}

class _TimingDeleteConfirmContent extends StatelessWidget {
  const _TimingDeleteConfirmContent({this.recordCount});

  final int? recordCount;

  bool get _isGroupDelete => recordCount != null;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style;
    final dangerStyle = style.copyWith(
      color: Colors.red.shade600,
      fontWeight: FontWeight.w700,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('⚠️  删除此记录将产生以下影响：'),
        const SizedBox(height: 16),
        if (_isGroupDelete) ...[
          _DeleteImpactLine(
            children: [
              const TextSpan(text: '计时页：这将删除'),
              TextSpan(text: '$recordCount', style: dangerStyle),
              const TextSpan(text: '条记录，无法恢复'),
            ],
          ),
          const SizedBox(height: 14),
        ],
        const _DeleteImpactLine(
          children: [TextSpan(text: '燃油页：工时模式下对应的燃油效率数据')],
        ),
        const SizedBox(height: 14),
        const _DeleteImpactLine(children: [TextSpan(text: '账户页：对应项目的统计数据')]),
        const SizedBox(height: 22),
        Text(_isGroupDelete ? '确定删除这组记录吗？' : '确定删除这条记录吗？'),
      ],
    );
  }
}

class _DeleteImpactLine extends StatelessWidget {
  const _DeleteImpactLine({required this.children});

  final List<InlineSpan> children;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('•', style: style),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(style: style, children: children),
          ),
        ),
      ],
    );
  }
}
