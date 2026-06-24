// ==============================================================================
// 📁 文件说明：维保页面 (maintenance_page.dart)
//
// 目标改造：
// 1) 维保页只负责“统计 + 列表”整页展示（不承载表单）
// 2) 右上角提供「+ 新建」按钮，使用 AppBottomSheetShell 弹出底部弹窗
// 3) 新建/编辑表单下沉到 MaintenanceDetailContent（与 Fuel/Timing/Account 统一）
// ==============================================================================

// =====================================================================
// ============================== 一、导入依赖库 ==============================
// =====================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/foundation/typography.dart';

import '../domain/entities/maintenance_entities.dart';

import '../../../core/utils/format_utils.dart';
import '../../../core/utils/store_feedback.dart';
import '../../../components/feedback/app_confirm_dialog.dart';
import '../../../components/feedback/store_action_feedback_l10n.dart';
import '../../../tokens/mapper/core_tokens.dart';
import '../../../tokens/mapper/account_tokens.dart';
import '../../../tokens/mapper/summary_card_tokens.dart';

import '../../../patterns/fuel/fuel_summary_card_pattern.dart';
import '../../../patterns/layout/bottom_sheet_shell_pattern.dart';
import '../../../patterns/maintenance/maintenance_detail_content_pattern.dart';
import '../../../patterns/maintenance/maintenance_sliver_home_pattern.dart';
import '../../../patterns/timing/records_title_pattern.dart';
import '../../../patterns/timing/section_header_pattern.dart';
import '../../../components/feedback/app_toast.dart';
import '../../../l10n/gen/app_localizations.dart';

import '../../../features/device/state/device_store.dart';
import '../../../features/maintenance/state/maintenance_store.dart';
import '../../timing/state/timing_store.dart';
import '../../../patterns/device/device_picker_items_builder.dart';
import '../../device/application/device_editor_initial_device_resolver.dart';
import '../../device/application/device_meter_resolver.dart';
import 'maintenance_page_view_data.dart';
import 'maintenance_records_section.dart';

// =====================================================================
// ============================== 二、页面入口 ==============================
// =====================================================================

class MaintenancePage extends StatefulWidget {
  const MaintenancePage({super.key});

  @override
  State<MaintenancePage> createState() => _MaintenancePageState();
}

// =====================================================================
// ============================== 四、State：仅做页面级交互 ==============================
// =====================================================================

class _MaintenancePageState extends State<MaintenancePage> {
  // =====================================================================
  // ============================== 五、通用 toast ==============================
  // =====================================================================

  void _toast(String msg) {
    if (!mounted) return;
    AppToast.show(context, msg);
  }

  Future<void> _retryLoad() async {
    final store = context.read<MaintenanceStore>();
    final deviceStore = context.read<DeviceStore>();
    await Future.wait([store.loadAll(), deviceStore.loadAll()]);
  }

  // =====================================================================
  // ============================== 六、BottomSheet：新建/编辑 ==============================
  // =====================================================================

  Future<void> _openMaintenanceEditor({MaintenanceRecord? editing}) async {
    final deviceStore = context.read<DeviceStore>();
    final timingStore = context.read<TimingStore>();
    final maintenanceStore = context.read<MaintenanceStore>();
    final formKey = GlobalKey<MaintenanceDetailContentState>();
    final l10n = AppLocalizations.of(context);
    final initialDeviceContext = resolveDeviceEditorInitialDeviceContext(
      isEditing: editing != null,
      editingDeviceId: editing?.deviceId,
      timingRecords: timingStore.records,
      activeDevices: deviceStore.activeDevices,
    );
    final editorContext = buildDeviceEditorContext(
      l10n: l10n,
      activeDevices: deviceStore.activeDevices,
      allDevices: deviceStore.allDevices,
      currentMeterResolver: deviceCurrentMeterResolver(timingStore.records),
      selectedId: initialDeviceContext.deviceId,
    );
    List<String> itemSuggestions(String query) {
      final normalized = query.trim();
      final seen = <String>{};
      final results = <String>[];

      for (final record in maintenanceStore.records) {
        final item = record.item.trim();
        if (item.isEmpty) continue;
        if (normalized.isNotEmpty && !item.contains(normalized)) continue;
        if (!seen.add(item)) continue;
        results.add(item);
      }

      return results;
    }

    await openEditorSheet<void>(
      context: context,
      title: editing == null
          ? l10n.maintenanceCreateSheetTitle
          : l10n.maintenanceEditSheetTitle,
      useSafeArea: true,
      dividerToContentGap: 8,
      cancelText: l10n.maintenanceCancelAction,
      confirmText: l10n.maintenanceConfirmAction,
      onConfirm: () => formKey.currentState?.submit(),
      childBuilder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: MaintenanceDetailContent(
            key: formKey,
            editing: editing,
            initialDeviceId: initialDeviceContext.deviceId,
            deviceById: editorContext.deviceById,
            deviceItems: editorContext.deviceItems,
            itemSuggestions: itemSuggestions,

            // 取消：Page 负责 pop
            onCancel: () => Navigator.of(ctx).pop(),

            // toast：统一走 Page
            onToast: _toast,

            // ✅ 保存：Page 负责落库 + toast + pop（与 Account/Fuel/Timing 统一）
            onSubmit: (record) async {
              await maintenanceStore.save(record);

              if (!mounted) return;

              final feedback = storeActionFeedback(
                maintenanceStore,
                action: StoreActionKind.save,
              );
              _toast(
                localizeStoreActionFeedback(
                  AppLocalizations.of(context),
                  feedback,
                ),
              );
              if (!feedback.isSuccess) {
                return;
              }
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
            },
          ),
        );
      },
    );
  }

  // =====================================================================
  // ============================== 八、删除：确认 + Store.deleteById ==============================
  // =====================================================================

  Future<bool> _confirmDelete(MaintenanceRecord r) async {
    if (r.id == null) return false;
    final l10n = AppLocalizations.of(context);

    final ok = await showAppConfirmDialog(
      context: context,
      title: l10n.maintenanceDeleteConfirmTitle,
      content:
          '${l10n.maintenanceDeleteConfirmDateLine(FormatUtils.date(r.ymd))}\n'
          '${l10n.maintenanceDeleteConfirmItemLine(r.item)}\n'
          '${l10n.maintenanceDeleteConfirmAmountLine(FormatUtils.money(r.effectiveAmount))}\n\n'
          '${l10n.maintenanceDeleteConfirmWarning}',
      cancelText: l10n.maintenanceCancelAction,
      confirmText: l10n.maintenanceDeleteConfirmAction,
    );

    return ok == true;
  }

  Future<void> _delete(MaintenanceRecord r) async {
    if (r.id == null) return;
    final store = context.read<MaintenanceStore>();

    await store.deleteById(r.id!);

    if (!mounted) return;

    final feedback =
        storeActionFeedback(store, action: StoreActionKind.delete);
    _toast(
      localizeStoreActionFeedback(AppLocalizations.of(context), feedback),
    );
  }

  // =====================================================================
  // ============================== 九、UI：统计卡（按设备 + 公共 + 合计） ==============================
  // =====================================================================

  Widget _buildSummaryCard(MaintenanceSummaryViewData summary) {
    final l10n = AppLocalizations.of(context);
    final titleStyle = AppTypography.body(
      context,
      fontSize: SummaryCardTokens.titleFontSize,
      fontWeight: FontWeight.w800,
      color: Colors.black,
    );
    final nameStyle = AppTypography.body(
      context,
      fontSize: SummaryCardTokens.rowLabelFontSize,
      color: Colors.black,
    );
    final valueStyle = AppTypography.caption(
      context,
      fontSize: SummaryCardTokens.rowValueFontSize,
      fontWeight: FontWeight.w700,
      color: Colors.black,
    );
    final totalLabelStyle = AppTypography.body(
      context,
      fontSize: SummaryCardTokens.totalLabelFontSize,
      fontWeight: FontWeight.w800,
      color: Colors.black,
    );
    final totalStyle = AppTypography.caption(
      context,
      fontSize: SummaryCardTokens.totalValueFontSize,
      fontWeight: FontWeight.w900,
      color: Colors.black,
    );
    final emptyStyle = AppTypography.bodySecondary(
      context,
      color: TimingColors.textSecondary,
    );

    Widget buildDeviceSummaryRow({
      required MaintenanceDeviceSummaryVM deviceSummary,
      required Color markerColor,
    }) {
      return Padding(
        padding: const EdgeInsets.only(
          left: SummaryCardTokens.rowLeftInset,
          bottom: SummaryCardTokens.rowBottomGap,
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: markerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      deviceSummary.deviceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: nameStyle,
                    ),
                  ),
                ],
              ),
            ),
            Text(FormatUtils.money(deviceSummary.amount), style: valueStyle),
          ],
        ),
      );
    }

    if (!summary.hasData) {
      return FuelSummaryCard(
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(l10n.maintenanceSummaryEmpty, style: emptyStyle),
        ),
      );
    }

    return FuelSummaryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.maintenanceSummaryTitle, style: titleStyle),
          const SizedBox(height: SummaryCardTokens.titleToContentGap),

          // 设备分摊
          for (var i = 0; i < summary.deviceSummaries.length; i++)
            buildDeviceSummaryRow(
              deviceSummary: summary.deviceSummaries[i],
              markerColor:
                  AccountTokens.overviewChartPalette[i %
                      AccountTokens.overviewChartPalette.length],
            ),

          // 公共支出
          if (summary.publicTotal > 0) ...[
            const SizedBox(height: 4),
            const Divider(height: 1, thickness: 1, color: TimingColors.divider),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.maintenancePublicExpenseLabel,
                    style: nameStyle,
                  ),
                ),
                Text(FormatUtils.money(summary.publicTotal), style: valueStyle),
              ],
            ),
          ],

          const Divider(height: 16, color: TimingColors.divider),

          // 合计
          Row(
            children: [
              Expanded(
                child: Text(l10n.maintenanceTotalLabel, style: totalLabelStyle),
              ),
              Text(FormatUtils.money(summary.allTotal), style: totalStyle),
            ],
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // ============================== 十一、build：统计 + 列表 ==============================
  // =====================================================================

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final store = context.watch<MaintenanceStore>();
    final deviceStore = context.watch<DeviceStore>();
    final viewData = buildMaintenancePageViewData(
      maintenanceStore: store,
      deviceStore: deviceStore,
      inactiveDeviceIndexLabel: l10n.deviceInactiveIndexLabel,
    );

    final recordsContent = MaintenanceRecordsContent(
      rows: viewData.rows,
      onEdit: (record) => _openMaintenanceEditor(editing: record),
      onConfirmDelete: _confirmDelete,
      onDelete: _delete,
    );

    return MaintenanceSliverHomePattern(
      header: SectionHeader(
        title: l10n.maintenancePageTitle,
        onAdd: () => _openMaintenanceEditor(),
      ),
      summary: _buildSummaryCard(viewData.summary),
      recordsTitle: RecordsTitle(
        count: viewData.rows.length,
        title: l10n.commonRecentRecordsCount(viewData.rows.length),
      ),
      records: recordsContent,
      loading: viewData.loading,
      error: viewData.error,
      onRetry: _retryLoad,
    );
  }
}
