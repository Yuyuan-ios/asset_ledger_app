// ==============================================================================
// 📁 文件：account_page.dart
// 账户管理页（工程化版本 / 三联弹窗收口版）
//
// 核心职责：
// 1) 聚合 Timing / Device / Rate / Payment 数据 -> 计算项目应收/实收/剩余。
// 2) 展示财务总览 + 项目列表。
// 3) 提供：项目筛选、单价编辑（批量/单台）、项目详情、收款记录 CRUD。
// 4) 所有数据写入通过 Provider/Store；UI 层仅负责 open + apply。
// ==============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/controllers/account_action_controller.dart';
import '../domain/entities/account_entities.dart';
import '../domain/entities/project_settlement_result.dart';
import '../domain/services/external_work_receivable.dart';
import '../../../features/account/model/account_project_payment_display_vm.dart';
import '../../../features/account/model/account_view_model.dart';

// ------------------------------ UI / Utils ------------------------------
import '../../../core/utils/format_utils.dart';
import '../../../components/feedback/store_action_feedback_l10n.dart';
import '../../../core/utils/interaction_feedback.dart';
import '../../../core/utils/store_feedback.dart';
import '../../../patterns/layout/bottom_sheet_shell_pattern.dart';
import '../../../tokens/mapper/account_tokens.dart';
import '../../../patterns/account/account_project_detail_sheet_pattern.dart';
import '../../../patterns/account/external_work_detail_sheet_pattern.dart';
import '../use_cases/project_share_export_use_case.dart';
import '../../../features/reports/use_cases/export_timing_worklog_excel_use_case.dart';
import 'dialogs/project_share_export_dialog.dart';
import '../../../components/feedback/app_toast.dart';
import '../../../components/feedback/app_confirm_dialog.dart';
import '../../../l10n/gen/app_localizations.dart';

// ------------------------------ Stores ------------------------------
import '../../../features/account/state/account_payment_store.dart';
import '../../../features/account/state/account_filter_store.dart';
import '../../../features/account/state/account_store.dart';
import '../../../features/device/state/device_store.dart';
import '../../../features/fuel/state/fuel_store.dart';
import '../../../features/maintenance/state/maintenance_store.dart';
import '../../../features/account/state/project_rate_store.dart';
import '../../../features/timing/state/timing_external_work_store.dart';
import '../../../features/timing/state/timing_store.dart';
import 'actions/account_rate_edit_actions.dart';
import 'account_page_view_data.dart';
import 'dialogs/account_payment_editor_dialog.dart';
import 'dialogs/account_dissolve_merge_confirm_dialog.dart';
import 'dialogs/account_project_merge_sheet.dart';
import 'dialogs/account_project_merge_sheet_data.dart';
import 'dialogs/account_project_filter_sheet.dart';
import 'dialogs/project_settlement_dialog.dart';
import 'widgets/account_page_content.dart';
import 'widgets/account_project_area_header.dart';

part 'dialogs/account_payment_dialogs.dart';
part 'dialogs/account_project_sheet_actions.dart';

// =====================================================================
// ============================== 页面入口 ==============================
// =====================================================================

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

// =====================================================================
// ============================== State：只做 UI 与交互 ==============================
// =====================================================================

enum _AccountProjectAreaSection { projects, externalWork }

class _AccountPageState extends State<AccountPage>
    with
        SingleTickerProviderStateMixin,
        _AccountPagePaymentDialogs,
        _AccountPageProjectSheetActions {
  bool _isCompactProjectList = false;
  var _externalWorkLoadRequested = false;
  var _projectAreaSection = _AccountProjectAreaSection.projects;

  late final TabController _projectAreaTabController;

  @override
  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _projectAreaTabController = TabController(length: 2, vsync: this);
    _projectAreaTabController.addListener(_handleProjectAreaTabChanged);
  }

  @override
  void dispose() {
    _projectAreaTabController.removeListener(_handleProjectAreaTabChanged);
    _projectAreaTabController.dispose();
    super.dispose();
  }

  void _handleProjectAreaTabChanged() {
    final nextSection =
        _AccountProjectAreaSection.values[_projectAreaTabController.index];
    if (nextSection == _projectAreaSection) return;
    setState(() => _projectAreaSection = nextSection);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_externalWorkLoadRequested) return;
    _externalWorkLoadRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final externalWorkStore = context.read<TimingExternalWorkStore?>();
      if (externalWorkStore == null) return;
      unawaited(externalWorkStore.loadAll());
    });
  }

  // -------------------------------------------------------------------
  // 通用：提示消息（SnackBar）
  // -------------------------------------------------------------------
  @override
  void _toast(String msg) {
    if (!mounted) return;
    AppToast.show(context, msg);
  }

  Future<void> _retryLoad() async {
    final timingStore = context.read<TimingStore>();
    final deviceStore = context.read<DeviceStore>();
    final paymentStore = context.read<AccountPaymentStore>();
    final rateStore = context.read<ProjectRateStore>();
    final accountStore = context.read<AccountStore>();
    final externalWorkStore = context.read<TimingExternalWorkStore?>();
    await Future.wait([
      timingStore.loadAll(),
      deviceStore.loadAll(),
      paymentStore.loadAll(),
      rateStore.loadAll(),
      accountStore.loadAll(),
      if (externalWorkStore != null) externalWorkStore.loadAll(),
    ]);
  }

  Widget _buildProjectAreaHeader(AccountPageViewData viewData) {
    final isExternalWork =
        _projectAreaSection == _AccountProjectAreaSection.externalWork;
    return AccountProjectAreaHeader(
      isExternalWork: isExternalWork,
      projectCount: isExternalWork
          ? viewData.filteredExternalWorkProjects.length
          : viewData.filteredProjects.length,
      externalWorkTitle: _l10n.accountExternalProjectsTitle,
      isCompactProjectList: _isCompactProjectList,
      hasActiveFilter: viewData.hasActiveFilter,
      onToggleCompactProjectList: () {
        setState(() {
          _isCompactProjectList = !_isCompactProjectList;
        });
      },
      onOpenMerge: _openMergeSheet,
      onOpenFilter: () =>
          _openProjectFilterSheet(suggestions: viewData.projectSuggestions),
      onClearFilter: () =>
          _applyProjectFilterResult(const AccountProjectFilterResult.clear()),
    );
  }

  // =====================================================================
  // ============================== H) 页面 build ==============================
  // =====================================================================
  @override
  Widget build(BuildContext context) {
    final timingStore = context.watch<TimingStore>();
    final deviceStore = context.watch<DeviceStore>();
    final paymentStore = context.watch<AccountPaymentStore>();
    final rateStore = context.watch<ProjectRateStore>();
    final accountStore = context.watch<AccountStore>();
    final filterStore = context.watch<AccountFilterStore>();
    final externalWorkStore = context.watch<TimingExternalWorkStore?>();
    final fuelStore = context.watch<FuelStore?>();
    final maintenanceStore = context.watch<MaintenanceStore?>();

    final viewData = buildAccountPageViewData(
      timingStore: timingStore,
      deviceStore: deviceStore,
      paymentStore: paymentStore,
      rateStore: rateStore,
      accountStore: accountStore,
      filterStore: filterStore,
      externalWorkStore: externalWorkStore,
      fuelStore: fuelStore,
      maintenanceStore: maintenanceStore,
    );

    return AccountPageContent(
      viewData: viewData,
      isCompactProjectList: _isCompactProjectList,
      projectAreaTabController: _projectAreaTabController,
      onRetryLoad: _retryLoad,
      projectAreaHeaderBuilder: _buildProjectAreaHeader,
      onOpenProjectDetail: _openProjectDetail,
      onExportProjectTimingWorklog: _exportProjectTimingWorklog,
      canExportProjectTimingWorklog: _hasProjectTimingWorklog,
      onOpenExternalWorkDetail: _openExternalWorkDetail,
    );
  }
}
