import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/form_feedback.dart';
import '../../../core/utils/store_feedback.dart';
import '../../device/domain/services/device_label.dart';
import '../../device/domain/services/device_lookup.dart';
import '../../../core/errors/external_work_errors.dart';
import '../../account/state/account_store.dart';
import '../../../features/device/state/device_store.dart';
import '../../../features/fuel/state/fuel_store.dart';
import '../../../features/maintenance/state/maintenance_store.dart';
import '../application/controllers/timing_action_controller.dart';
import '../domain/entities/timing_entities.dart';
import '../domain/repositories/timing_calculation_history_repository.dart';
import '../../../features/timing/model/timing_chart_data.dart';
import '../../../features/timing/operations/save_timing_record_operation_command.dart';
import '../../../features/timing/state/timing_external_work_store.dart';
import '../../../features/timing/state/timing_store.dart';
import '../../../features/external_work/import_preview/use_cases/pick_external_work_share_file_use_case.dart';
import '../../../features/external_work/import_preview/view/external_work_import_preview_page.dart';
import '../../../features/timing/use_cases/delete_timing_record_with_impact_use_case.dart';
import '../../../features/timing/use_cases/save_timing_record_use_case.dart';
import '../../../features/timing/use_cases/save_timing_record_with_impact_use_case.dart';
import '../../account/state/project_rate_store.dart';
import '../../../patterns/timing/timing_home_pattern.dart';
import '../../../patterns/layout/bottom_sheet_shell_pattern.dart';
import '../../../components/feedback/app_toast.dart';
import '../../../components/feedback/app_confirm_dialog.dart';
import '../../../patterns/timing/timing_detail_content_pattern.dart';
import '../../../patterns/timing/external_work_records_pattern.dart';
import '../../../patterns/timing/external_work_link_sheet.dart';
import '../../../patterns/timing/card_main_chart_pattern.dart';
import '../../../patterns/timing/section_header_pattern.dart';
import '../../../patterns/device/device_picker_items_builder.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../device/application/device_meter_resolver.dart';
import '../../account/model/account_view_model.dart';
import '../../account/model/project_title_formatter.dart';

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
  var _recordsSection = TimingRecordsSection.recent;
  var _externalWorkLoadRequested = false;

  int get _maxChartYear => DateTime.now().year;

  int _defaultMonthForYear(int year) {
    final now = DateTime.now();
    return year < now.year ? 12 : now.month;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_externalWorkLoadRequested) return;
    _externalWorkLoadRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<TimingExternalWorkStore>().loadAll());
    });
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

  // 打开"关联到项目"底部弹窗：选择外协包 + 本地项目，确认后真实写库。
  Future<void> _openExternalWorkLinkSheet() async {
    final store = context.read<TimingExternalWorkStore>();
    final items = store.items;
    if (items.isEmpty) return;

    final candidates = _buildExternalWorkLinkCandidates();
    final packages = _buildExternalWorkLinkPackages(items, candidates);
    if (packages.isEmpty) return;

    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    await showAppBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return AppBottomSheetShell(
          title: l10n.timingExternalWorkLinkSheetTitle,
          scrollable: false,
          footerEnabled: false,
          contentPadding: EdgeInsets.zero,
          child: ExternalWorkLinkSheet(
            packages: packages,
            candidates: candidates,
            onCancel: () => Navigator.of(sheetContext).pop(),
            onConfirm: (package, candidate) {
              Navigator.of(sheetContext).pop();
              unawaited(_linkExternalWork(package, candidate));
            },
            onUnlink: (package) {
              Navigator.of(sheetContext).pop();
              unawaited(_unlinkExternalWork(package));
            },
          ),
        );
      },
    );
  }

  // 把外协记录按 importBatch 分组成"可选外协包"。保持 store.items 的顺序
  // （workDate desc）→ 各包按首次出现顺序排列；摘要随选择同步由弹窗负责。
  List<ExternalWorkLinkPackage> _buildExternalWorkLinkPackages(
    List<TimingExternalWorkRecordItem> items,
    List<ExternalWorkLinkCandidate> candidates,
  ) {
    final order = <String>[];
    final byBatch = <String, List<TimingExternalWorkRecordItem>>{};
    for (final item in items) {
      final batchId = item.record.importBatchId;
      final bucket = byBatch.putIfAbsent(batchId, () {
        order.add(batchId);
        return <TimingExternalWorkRecordItem>[];
      });
      bucket.add(item);
    }

    final packages = <ExternalWorkLinkPackage>[];
    for (final batchId in order) {
      final batchItems = byBatch[batchId]!;
      packages.add(
        _buildExternalWorkLinkPackage(batchId, batchItems, candidates),
      );
    }
    return packages;
  }

  ExternalWorkLinkPackage _buildExternalWorkLinkPackage(
    String batchId,
    List<TimingExternalWorkRecordItem> batchItems,
    List<ExternalWorkLinkCandidate> candidates,
  ) {
    final l10n = AppLocalizations.of(context);
    final sourceName = batchItems.first.displayName;
    final siteSummary = externalWorkLinkSiteSummary(
      batchItems.map((item) => item.record.siteSnapshot),
      separator: l10n.timingExternalWorkSiteSummarySeparator,
    );
    final optionTitle = ProjectTitleFormatter.project(
      contact: sourceName,
      site: siteSummary,
    );

    final equipment = (batchItems.first.record.equipmentBrand ?? '').trim();
    final totalHoursMilli = batchItems.fold<int>(
      0,
      (sum, item) => sum + item.record.hoursMilli,
    );
    final summaryDetail = [
      if (equipment.isNotEmpty) equipment,
      l10n.timingExternalWorkPackageRecordCount(batchItems.length),
      '${(totalHoursMilli / 1000).toStringAsFixed(1)}h',
    ].join(' · ');

    // 已关联态：仅读现有 linkedProjectId（本阶段不写）。
    final linkedProjectId = batchItems
        .map((item) => item.record.linkedProjectId?.trim() ?? '')
        .firstWhere((id) => id.isNotEmpty, orElse: () => '');
    String? linkedTitle;
    if (linkedProjectId.isNotEmpty) {
      for (final candidate in candidates) {
        if (candidate.projectId == linkedProjectId) {
          linkedTitle = candidate.title;
          break;
        }
      }
      linkedTitle ??= l10n.timingExternalWorkDefaultLinkedProjectTitle;
    }

    return ExternalWorkLinkPackage(
      batchId: batchId,
      optionTitle: optionTitle,
      summaryDetail: summaryDetail,
      linkedProjectTitle: linkedTitle,
    );
  }

  List<ExternalWorkLinkCandidate> _buildExternalWorkLinkCandidates() {
    // 候选只取未合并的真实项目，保证 linkedProjectId 始终指向真实 projects.id
    // （合并 VM 的 id 为 merge:groupId，会触发外键拒绝）。
    final computed = _computeNormalAccountProjects();
    final settled = context.read<AccountStore>().settledProjectIds;
    return [
      for (final AccountProjectVM project in computed)
        ExternalWorkLinkCandidate(
          projectId: project.effectiveProjectId,
          title: project.displayName,
          settled: settled.contains(project.effectiveProjectId),
        ),
    ];
  }

  List<AccountProjectVM> _computeNormalAccountProjects() {
    final accountStore = context.read<AccountStore>();
    final timingStore = context.read<TimingStore>();
    final deviceStore = context.read<DeviceStore>();
    final rateStore = context.read<ProjectRateStore>();
    // payments 不影响项目身份/结清判定与应收口径，传空即可。
    final computed = accountStore.compute(
      timingRecords: timingStore.records,
      devices: deviceStore.allDevices,
      rates: rateStore.rates,
      payments: const [],
      activeMergeGroups: const [],
    );
    return computed.projects;
  }

  // 确认关联：已结清项目先二次确认，再走"关联 + 撤销结清"原子事务；
  // 普通未结清项目直接写 linkedProjectId。两条路径都只在真正写入成功后提示成功。
  Future<void> _linkExternalWork(
    ExternalWorkLinkPackage package,
    ExternalWorkLinkCandidate candidate,
  ) async {
    final l10n = AppLocalizations.of(context);
    final store = context.read<TimingExternalWorkStore>();
    if (candidate.settled) {
      final confirmed = await showAppConfirmDialog(
        context: context,
        title: l10n.timingExternalWorkSettledConfirmTitle,
        content: l10n.timingExternalWorkSettledConfirmContent,
        confirmText: l10n.timingExternalWorkContinueAction,
      );
      if (!confirmed || !mounted) return;
      final accountStore = context.read<AccountStore>();
      final ok = await _runExternalWorkWrite(
        action: () => store.linkSettledBatchToProject(
          package.batchId,
          candidate.projectId,
        ),
        successMessage: l10n.timingExternalWorkLinkSettledSuccess,
        failureMessage: l10n.timingExternalWorkLinkFailure,
      );
      // 关联+撤销结清已原子提交；刷新账户聚合让结清状态/总应收重新计算。
      if (ok && mounted) await accountStore.loadAll();
      return;
    }
    await _runExternalWorkWrite(
      action: () =>
          store.linkBatchToProject(package.batchId, candidate.projectId),
      successMessage: l10n.timingExternalWorkLinkSuccess,
      failureMessage: l10n.timingExternalWorkLinkFailure,
    );
  }

  Future<void> _unlinkExternalWork(ExternalWorkLinkPackage package) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: l10n.timingExternalWorkUnlinkConfirmTitle,
      content: l10n.timingExternalWorkUnlinkConfirmContent,
      confirmText: l10n.timingExternalWorkContinueAction,
    );
    if (!confirmed || !mounted) return;
    final store = context.read<TimingExternalWorkStore>();
    await _runExternalWorkWrite(
      action: () => store.unlinkBatch(package.batchId),
      successMessage: l10n.timingExternalWorkUnlinkSuccess,
      failureMessage: l10n.timingExternalWorkUnlinkFailure,
    );
  }

  /// 统一执行外协关联/解除写库：成功 toast 只在真正写入成功后出现；
  /// batch 已不存在（0 行）给出明确提示；其它失败给通用重试提示。
  Future<bool> _runExternalWorkWrite({
    required Future<void> Function() action,
    required String successMessage,
    required String failureMessage,
  }) async {
    try {
      await action();
    } on ExternalWorkBatchUnavailableException catch (error) {
      if (mounted) _toast(error.message);
      return false;
    } catch (_) {
      if (mounted) _toast(failureMessage);
      return false;
    }
    if (mounted) _toast(successMessage);
    return true;
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
      _toast(AppLocalizations.of(context).timingEntryHistoryLoadFailure);
      return const <TimingCalculationHistory>[];
    }
  }

  Future<void> _retryLoad() async {
    final timingStore = context.read<TimingStore>();
    final deviceStore = context.read<DeviceStore>();
    final fuelStore = context.read<FuelStore>();
    final maintenanceStore = context.read<MaintenanceStore>();
    final accountStore = context.read<AccountStore>();
    final externalWorkStore = context.read<TimingExternalWorkStore>();
    await Future.wait([
      timingStore.loadAll(),
      deviceStore.loadAll(),
      fuelStore.loadAll(),
      maintenanceStore.loadAll(),
      accountStore.loadAll(),
      externalWorkStore.loadAll(),
    ]);
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
    final l10n = AppLocalizations.of(context);

    final editorContext = buildDeviceEditorContext(
      activeDevices: deviceStore.activeDevices,
      allDevices: deviceStore.allDevices,
      currentMeterResolver: deviceCurrentMeterResolver(timingStore.records),
      selectedId: editing?.deviceId,
    );

    await openEditorSheet<void>(
      context: context,
      title: editing == null
          ? l10n.timingEntryCreateSheetTitle
          : l10n.timingEntryEditSheetTitle,
      useSafeArea: false,
      cancelText: editing == null
          ? l10n.timingEntryCancelAction
          : l10n.timingEntryDeleteRecordAction,
      cancelForegroundColor: editing == null ? null : Colors.red.shade600,
      onCancel: editing == null
          ? null
          : (sheetContext) => _deleteEditingRecord(sheetContext, editing),
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
          // 当前码表计算通过 TimingActionController 包装的 currentMeter
          // 入口拿到（C2：让 pattern 不再直接依赖 data/services）。
          resolveCurrentMeter: (deviceId) {
            final device = editorContext.deviceById[deviceId];
            return actionController.currentMeter(
              records: timingStore.records,
              deviceId: deviceId,
              baseMeterHours: device?.baseMeterHours ?? 0,
            );
          },
          onToast: _toast,
          onSubmit: (record, calculationHistories) async {
            // 唯一的保存入口：事务化 SaveTimingRecordWithImpactUseCase。
            // Provider 必须由 TimingSaveProviders 注入；缺失即生产配置错误，
            // 直接由 context.read 抛 ProviderNotFoundException 走 fail-fast，
            // 不再静默回落到旧两步保存 + UI retry 兜底路径（已删除）。
            final saveUseCase = actionController.createSaveUseCase(
              timingStore: timingStore,
              withImpact: context.read<SaveTimingRecordWithImpactUseCase>(),
              command: context.read<SaveTimingRecordOperationCommand>(),
            );
            SaveTimingRecordResult result;
            try {
              result = await saveUseCase.execute(
                editing: editing,
                record: record,
                calculationHistories: calculationHistories,
              );
            } catch (error) {
              if (!mounted) return;
              final message = _saveFailureMessage(error, timingStore);
              final form = formKey.currentState;
              if (form != null && form.mounted) {
                form.showSubmitFailure(message);
              } else {
                _toast(message);
              }
              return;
            }
            if (!mounted) return;

            final feedback = storeActionFeedback(timingStore, action: '保存');
            if (!feedback.isSuccess) {
              final form = formKey.currentState;
              if (form != null && form.mounted) {
                form.showSubmitFailure(feedback.message);
              } else {
                _toast(feedback.message);
              }
              return;
            }
            // 事务化路径已完成所有级联：UI 不再依赖 pending retry。
            final impact = result.impact;
            final toastMessage = impact.userMessage ?? feedback.message;
            if (!mounted) return;
            _toast(toastMessage);
            if (!sheetContext.mounted) return;
            Navigator.of(sheetContext).pop();
          },
        );
      },
    );
  }

  String _saveFailureMessage(Object error, TimingStore timingStore) {
    if (error is SaveTimingRecordOperationException) {
      return formValidationMessage(_friendlySaveFailureReason(error.message));
    }
    final feedback = storeActionFeedback(timingStore, action: '保存');
    return feedback.isSuccess
        ? AppLocalizations.of(context).timingEntrySaveFailure
        : feedback.message;
  }

  String _friendlySaveFailureReason(String message) {
    final trimmed = message.trim();
    // 校验器内部以“分摊截止日期”措辞抛出；UI 统一为“结束日”语义。
    // “结束日不能晚于下一条同设备记录日期”已是面向用户文案，原样透传。
    if (trimmed == '分摊截止日期必须晚于计时日期') {
      return '结束日不能早于开始日';
    }
    return trimmed;
  }

  void _deleteEditingRecord(BuildContext sheetContext, TimingRecord editing) {
    unawaited(_runDeleteWithImpact(sheetContext, editing));
  }

  // 删除前先做项目影响分析：有收款的最后一条计时直接阻止；其它情况按影响
  // 合并成一个确认提示，确认后在单事务内删除并联动清理（撤销结清 / 解除合并 /
  // 解除外协），再刷新计时、账户、外协三处聚合，避免合并弹窗残留历史成员。
  Future<void> _runDeleteWithImpact(
    BuildContext sheetContext,
    TimingRecord editing,
  ) async {
    final recordId = editing.id;
    if (recordId == null) return;
    final deleteUseCase = context.read<DeleteTimingRecordWithImpactUseCase>();

    TimingRecordDeleteImpact impact;
    try {
      impact = await deleteUseCase.analyzeImpact(recordId);
    } catch (_) {
      if (mounted) {
        _toast(AppLocalizations.of(context).timingEntryDeletePrecheckFailure);
      }
      return;
    }
    if (!mounted) return;

    if (impact.isBlockedByPayments) {
      if (!sheetContext.mounted) return;
      await _showDeleteBlockedDialog(
        sheetContext,
        const TimingDeleteBlockedByPaymentsException().message,
      );
      return;
    }

    final confirmed = await showAppConfirmDialog(
      context: context,
      title: AppLocalizations.of(context).timingEntryDeleteConfirmTitle,
      content: _deleteConfirmContent(impact),
      cancelText: AppLocalizations.of(context).timingEntryCancelAction,
      confirmText: AppLocalizations.of(context).timingEntryDeleteConfirmAction,
      confirmDestructive: true,
    );
    if (!confirmed || !mounted) return;

    TimingRecordDeleteOutcome outcome;
    try {
      outcome = await deleteUseCase.executeDeleteWithImpact(recordId);
    } on TimingDeleteBlockedByPaymentsException catch (error) {
      if (!mounted || !sheetContext.mounted) return;
      await _showDeleteBlockedDialog(sheetContext, error.message);
      return;
    } catch (_) {
      if (mounted) {
        _toast(AppLocalizations.of(context).timingEntryDeleteFailure);
      }
      return;
    }
    if (!mounted) return;

    await _reloadAfterDelete();
    if (!mounted) return;
    _toast(_deleteSuccessMessage(outcome));
    if (!sheetContext.mounted) return;
    Navigator.of(sheetContext).pop();
  }

  Future<void> _showDeleteBlockedDialog(
    BuildContext sheetContext,
    String message,
  ) async {
    if (!mounted || !sheetContext.mounted) return;
    await showAppAlertDialog(
      context: sheetContext,
      title: AppLocalizations.of(sheetContext).timingEntryDeleteBlockedTitle,
      message: message,
      confirmText: AppLocalizations.of(
        sheetContext,
      ).timingEntryDeleteBlockedConfirm,
    );
  }

  String _deleteConfirmContent(TimingRecordDeleteImpact impact) {
    final l10n = AppLocalizations.of(context);
    final parts = <String>[];
    if (impact.requiresSettlementRevoke) {
      parts.add(l10n.timingEntryDeleteSettledConfirmContent);
    }
    if (impact.hasLastRecordCascade) {
      parts.add(l10n.timingEntryDeleteLastRecordConfirmContent);
    }
    if (parts.isEmpty) {
      return l10n.timingEntryDeleteDefaultConfirmContent;
    }
    return parts.join('\n\n');
  }

  String _deleteSuccessMessage(TimingRecordDeleteOutcome outcome) {
    final l10n = AppLocalizations.of(context);
    if (!outcome.hasCascade) return l10n.timingEntryDeleted;
    final parts = <String>[];
    if (outcome.settlementRevoked) {
      parts.add(l10n.timingEntrySettlementRevoked);
    }
    if (outcome.mergeGroupDissolved) {
      parts.add(l10n.timingEntryMergeDissolved);
    } else if (outcome.mergeMemberRemoved) {
      parts.add(l10n.timingEntryMergeMemberRemoved);
    }
    if (outcome.externalWorkUnlinked) {
      parts.add(l10n.timingEntryExternalWorkUnlinked);
    }
    if (parts.isEmpty) return l10n.timingEntryDeleted;
    return l10n.timingEntryDeleteCascadeSuccess(
      parts.join(l10n.timingEntryDeleteCascadeSeparator),
    );
  }

  Future<void> _reloadAfterDelete() async {
    final timingStore = context.read<TimingStore>();
    final accountStore = context.read<AccountStore>();
    final externalWorkStore = context.read<TimingExternalWorkStore>();
    await Future.wait([
      timingStore.loadAll(),
      accountStore.loadAll(),
      externalWorkStore.loadAll(),
    ]);
  }

  Future<void> _openExternalWorkDetail(
    TimingExternalWorkRecordItem item,
  ) async {
    final detailItems = _externalWorkDetailItems(item);
    final detailPackage = _buildExternalWorkLinkPackage(
      item.record.importBatchId,
      detailItems,
      _buildExternalWorkLinkCandidates(),
    );
    await showAppBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return AppBottomSheetShell(
          title: '外协项目详情',
          scrollable: true,
          onCancel: () => _deleteExternalWorkRecord(sheetContext, item),
          onConfirm: () => Navigator.of(sheetContext).pop(),
          cancelText: '删除分享包',
          cancelForegroundColor: Colors.red.shade600,
          confirmText: '确定',
          contentPadding: EdgeInsets.zero,
          child: ExternalWorkRecordDetailContent(
            item: item,
            packageItems: detailItems,
            onLinkProject: () {
              Navigator.of(sheetContext).pop();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                unawaited(_openExternalWorkLinkSheet());
              });
            },
            onUnlinkProject: () {
              Navigator.of(sheetContext).pop();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                unawaited(_unlinkExternalWork(detailPackage));
              });
            },
          ),
        );
      },
    );
  }

  List<TimingExternalWorkRecordItem> _externalWorkDetailItems(
    TimingExternalWorkRecordItem item,
  ) {
    final batchId = item.record.importBatchId.trim();
    if (batchId.isEmpty) return [item];

    final items =
        context
            .read<TimingExternalWorkStore>()
            .items
            .where((entry) {
              return entry.record.importBatchId.trim() == batchId;
            })
            .toList(growable: false)
          ..sort((a, b) {
            final byDate = a.record.workDate.compareTo(b.record.workDate);
            if (byDate != 0) return byDate;
            return a.record.createdAt.compareTo(b.record.createdAt);
          });
    return items.isEmpty ? [item] : items;
  }

  void _deleteExternalWorkRecord(
    BuildContext sheetContext,
    TimingExternalWorkRecordItem item,
  ) {
    () async {
      final store = context.read<TimingExternalWorkStore>();
      final batchId = item.record.importBatchId;
      final batchRecordCount = store.items
          .where((candidate) => candidate.record.importBatchId == batchId)
          .length;
      final confirmed = await showAppConfirmDialog(
        context: context,
        title: '删除分享包',
        content: '这将删除该分享包导入的全部 $batchRecordCount 条外协记录，删除后不可恢复。',
        confirmText: '删除',
        confirmDestructive: true,
      );
      if (!confirmed || !mounted) return;

      await store.deleteByBatchId(batchId);
      if (!mounted) return;
      final feedback = storeActionFeedback(store, action: '删除');
      _toast(feedback.message);
      if (!feedback.isSuccess || !sheetContext.mounted) return;
      Navigator.of(sheetContext).pop();
    }();
  }

  // 阶段6：选择 .jzt 文件 → 读取文本 → 进入现有外协导入预览。
  // 不解析 envelope（交给现有 parser/duplicate checker/importer）。

  Future<void> _openImportExternalWorkShare() async {
    final result = await context
        .read<PickExternalWorkShareFileUseCase>()
        .pick();
    if (!mounted) return;
    switch (result) {
      case PickShareFileCancelled():
        return;
      case PickShareFileError(:final message):
        _toast(message);
      case PickShareFileContent(:final content):
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                ExternalWorkImportPreviewPage(initialContent: content),
          ),
        );
        if (!mounted) return;
        unawaited(context.read<TimingExternalWorkStore>().loadAll());
    }
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
    final externalWorkStore = context.watch<TimingExternalWorkStore>();

    final loading =
        timingStore.loading ||
        deviceStore.loading ||
        fuelStore.loading ||
        maintenanceStore.loading ||
        accountStore.loading ||
        externalWorkStore.loading;
    final error = firstStoreErrorMessage([
      timingStore,
      deviceStore,
      fuelStore,
      maintenanceStore,
      accountStore,
      externalWorkStore,
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
      recordsSection: _recordsSection,
      onRecordsSectionChanged: (section) {
        setState(() => _recordsSection = section);
      },
      records: timingStore.records,
      externalWorkItems: externalWorkStore.items,
      deviceById: deviceById,
      deviceIndexById: deviceIndexById,
      onTapRecord: (r) => _openTimingEditor(editing: r),
      onTapExternalWorkRecord: _openExternalWorkDetail,
      onImportExternalWork: _openImportExternalWorkShare,
      onLinkExternalWork: _openExternalWorkLinkSheet,
      loading: loading,
      error: error,
      onRetry: () => _retryLoad(),
    );
  }
}
