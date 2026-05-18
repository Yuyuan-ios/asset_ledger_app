import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:asset_ledger/data/models/device_maps.dart';
import 'package:asset_ledger/data/services/device_label.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/utils/store_feedback.dart';
import '../../../data/models/timing_record.dart';
import '../../../data/models/device.dart';
import '../../../data/models/fuel_log.dart';
import '../../../data/models/maintenance_record.dart';
import '../../../data/models/project_device_rate.dart';
import '../../../data/services/account_project_merge_service.dart';
import '../../../data/services/project_resolver.dart';
import '../../../data/services/timing_monthly_expense_service.dart';
import '../../../data/services/timing_monthly_income_service.dart';
import '../../../data/services/timing_service.dart';
import '../../../data/services/timing_suggest_service.dart';
import '../../../features/device/state/device_store.dart';
import '../../../features/fuel/state/fuel_store.dart';
import '../../../features/maintenance/state/maintenance_store.dart';
import 'package:asset_ledger/data/models/timing_calculation_history.dart';
import 'package:asset_ledger/data/repositories/timing_calculation_history_repository.dart';
import '../../../features/timing/model/timing_chart_data.dart';
import '../../../features/timing/state/timing_store.dart';
import '../../../features/timing/use_cases/compute_timing_chart_finance_use_case.dart';
import '../../../features/timing/use_cases/save_timing_record_use_case.dart';
import '../../../features/timing/use_cases/timing_preview_income_use_case.dart';
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

  /// 计时图表目标月正式策略：
  /// - 显式传入 [TimingPage.initialTargetMonth]：严格按传入值统计；
  /// - 未显式传入：以“当前自然月”为下限，再扩展到目标年份内三类数据
  ///   (Timing/Fuel/Maintenance) 的最大月份，避免某一类数据被提前截断。
  int _resolveEffectiveTargetMonth({
    required List<TimingRecord> records,
    required List<FuelLog> fuelLogs,
    required List<MaintenanceRecord> maintenanceRecords,
  }) {
    // 显式传入目标月时，保持调用方语义，不做自动扩展。
    if (widget.initialTargetMonth != null) {
      return _targetMonth;
    }

    var maxMonth = _targetMonth;
    for (final record in records) {
      final date = FormatUtils.dateFromYmd(record.startDate);
      if (date.year == _targetYear && date.month > maxMonth) {
        maxMonth = date.month;
      }
    }
    for (final fuel in fuelLogs) {
      final date = FormatUtils.dateFromYmd(fuel.date);
      if (date.year == _targetYear && date.month > maxMonth) {
        maxMonth = date.month;
      }
    }
    for (final maintenance in maintenanceRecords) {
      final date = FormatUtils.dateFromYmd(maintenance.ymd);
      if (date.year == _targetYear && date.month > maxMonth) {
        maxMonth = date.month;
      }
    }
    return maxMonth;
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
  }) {
    // Page 只负责组装图表输入数据；收入口径与分摊规则由 service 统一承载，
    // Pattern 层只渲染，不参与业务计算。
    const monthLabels = [
      '1月',
      '2月',
      '3月',
      '4月',
      '5月',
      '6月',
      '7月',
      '8月',
      '9月',
      '10月',
      '11月',
      '12月',
    ];
    const maxBarHeight = 150.0;

    final effectiveTargetMonth = _resolveEffectiveTargetMonth(
      records: records,
      fuelLogs: fuelLogs,
      maintenanceRecords: maintenanceRecords,
    );
    // 柱图仍使用原有月度动态收入分布，只把图例中的总收入文案切换为
    // 账户页总应收 - 计时页支出，避免改变历史柱形视觉。
    final monthlyIncome =
        TimingMonthlyIncomeService.computeMonthlyIncomeRealtime(
          records: records,
          devices: devices,
          rates: rates,
          targetYear: _targetYear,
          targetMonth: effectiveTargetMonth,
        );
    final maxIncome = monthlyIncome.fold<double>(0.0, (acc, value) {
      return value > acc ? value : acc;
    });
    final incomeBars = maxIncome <= 0
        ? List<double>.filled(12, 0.0)
        : monthlyIncome
              .map((income) => (income / maxIncome) * maxBarHeight)
              .toList();

    final expenseStats = TimingMonthlyExpenseService.computeMonthlyExpense(
      fuelLogs: fuelLogs,
      maintenanceRecords: maintenanceRecords,
      targetYear: _targetYear,
      targetMonth: effectiveTargetMonth,
    );
    final finance = const ComputeTimingChartFinanceUseCase().execute(
      timingRecords: records,
      devices: devices,
      rates: rates,
      expenseStats: expenseStats,
    );

    final expenseBars = maxIncome <= 0
        ? List<double>.filled(12, 0.0)
        : expenseStats.monthlyTotal.map((expense) {
            final height = (expense / maxIncome) * maxBarHeight;
            return height.clamp(0.0, maxBarHeight).toDouble();
          }).toList();

    return TimingChartData(
      year: _targetYear,
      targetMonth: effectiveTargetMonth,
      monthLabels: monthLabels,
      incomeBars: incomeBars,
      expenseBars: expenseBars,
      totalIncomeText: FormatUtils.money(finance.displayIncome),
      totalExpenseText: FormatUtils.money(expenseStats.totalExpense),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    AppToast.show(context, msg);
  }

  TimingCalculationHistoryRepository get _calculationHistoryRepository =>
      widget.calculationHistoryRepository ??
      SqfliteTimingCalculationHistoryRepository();

  Future<List<TimingCalculationHistory>> _loadExistingCalculationHistories(
    TimingRecord? editing,
  ) async {
    if (editing == null || editing.type != TimingType.hours) {
      return const <TimingCalculationHistory>[];
    }

    final recordId = editing.id;
    if (recordId == null) return const <TimingCalculationHistory>[];

    try {
      return await _calculationHistoryRepository.findByTimingRecordId(recordId);
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
    await Future.wait([
      timingStore.loadAll(),
      deviceStore.loadAll(),
      fuelStore.loadAll(),
      maintenanceStore.loadAll(),
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
    final previewIncomeUseCase = TimingPreviewIncomeUseCase(
      projectResolver: context.read<ProjectResolver>(),
    );
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
              TimingSuggestService.contactSuggestions(
                timingStore.records,
                query,
              ),
          siteSuggestions: (query) =>
              TimingSuggestService.siteSuggestions(timingStore.records, query),
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
                final lower = TimingService.lowerBound(
                  records: timingStore.records,
                  deviceId: deviceId,
                  startDate: startDate,
                  excludeId: excludeId,
                );
                if (endMeter < lower) {
                  return '结束码表($endMeter) < 下界($lower)';
                }
                final upper = TimingService.upperBound(
                  records: timingStore.records,
                  deviceId: deviceId,
                  startDate: startDate,
                  excludeId: excludeId,
                );
                if (upper != double.infinity && endMeter > upper) {
                  return '结束码表($endMeter) > 上界($upper)';
                }
                return null;
              },
          onToast: _toast,
          onSubmit: (record, calculationHistories) async {
            final saveUseCase = SaveTimingRecordUseCase(
              timingStore: timingStore,
              mergeDissolve: AccountMergeDissolveAdapter(
                context.read<AccountProjectMergeService>(),
              ),
              projectResolver: context.read<ProjectResolver>(),
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

    final loading =
        timingStore.loading ||
        deviceStore.loading ||
        fuelStore.loading ||
        maintenanceStore.loading;
    final error = firstStoreErrorMessage([
      timingStore,
      deviceStore,
      fuelStore,
      maintenanceStore,
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
