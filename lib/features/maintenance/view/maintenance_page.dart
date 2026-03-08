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
import '../../../core/foundation/spacing.dart';
import '../../../core/foundation/typography.dart';

import '../../../data/models/maintenance_record.dart';

import '../../../core/utils/format_utils.dart';
import '../../../core/utils/store_feedback.dart';
import '../../../components/feedback/app_confirm_dialog.dart';
import '../../../tokens/mapper/core_tokens.dart';
import '../../../tokens/mapper/fuel_tokens.dart';
import '../../../tokens/mapper/timing_tokens.dart';

import '../../../patterns/fuel/fuel_home_pattern.dart';
import '../../../patterns/fuel/fuel_summary_card_pattern.dart';
import '../../../patterns/layout/bottom_sheet_shell_pattern.dart';
import '../../../patterns/maintenance/maintenance_detail_content_pattern.dart';
import '../../../patterns/timing/records_title_pattern.dart';
import '../../../patterns/timing/section_header_pattern.dart';
import '../../../components/feedback/app_toast.dart';
import '../../../components/feedback/app_records_empty_hint.dart';

import '../../../features/device/state/device_store.dart';
import '../../../features/maintenance/state/maintenance_store.dart';
import '../../timing/state/timing_store.dart';
import '../../../patterns/device/device_picker_items_builder.dart';

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
    final editorContext = buildDeviceEditorContext(
      activeDevices: deviceStore.activeDevices,
      allDevices: deviceStore.allDevices,
      records: timingStore.records,
      selectedId: editing?.deviceId,
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
      title: editing == null ? '新建维保' : '编辑维保',
      useSafeArea: true,
      dividerToContentGap: 8,
      onConfirm: () => formKey.currentState?.submit(),
      childBuilder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: MaintenanceDetailContent(
            key: formKey,
            editing: editing,
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
                action: '保存',
              );
              _toast(feedback.message);
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

    final ok = await showAppConfirmDialog(
      context: context,
      title: '确认删除？',
      content:
          '日期：${FormatUtils.date(r.ymd)}\n'
          '事项：${r.item}\n'
          '金额：${FormatUtils.money(r.amount)}\n\n'
          '⚠️ 删除后不可恢复',
      confirmText: '删除',
    );

    return ok == true;
  }

  Future<void> _delete(MaintenanceRecord r) async {
    if (r.id == null) return;
    final store = context.read<MaintenanceStore>();

    await store.deleteById(r.id!);

    if (!mounted) return;

    final feedback = storeActionFeedback(store, action: '删除');
    _toast(feedback.message);
  }

  // =====================================================================
  // ============================== 九、UI：统计卡（按设备 + 公共 + 合计） ==============================
  // =====================================================================

  Widget _buildSummaryCard() {
    final store = context.watch<MaintenanceStore>();
    final deviceStore = context.watch<DeviceStore>();
    final titleStyle = AppTypography.body(
      context,
      fontSize: 14,
      fontWeight: FontWeight.w800,
      color: Colors.black,
    );
    final nameStyle = AppTypography.body(
      context,
      fontSize: 13,
      color: Colors.black,
    );
    final valueStyle = AppTypography.caption(
      context,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: Colors.black,
    );
    final totalLabelStyle = AppTypography.body(
      context,
      fontSize: 13,
      fontWeight: FontWeight.w800,
      color: Colors.black,
    );
    final totalStyle = AppTypography.caption(
      context,
      fontSize: 12,
      fontWeight: FontWeight.w900,
      color: Colors.black,
    );
    final emptyStyle = AppTypography.bodySecondary(
      context,
      color: TimingColors.textSecondary,
    );

    // 口径：当年（你 Store.currentYearSummary 的口径）
    final nowYmd = FormatUtils.ymdFromDate(DateTime.now());

    // 约定：map key = deviceId(int) 或 null(公共)
    final map = store.currentYearSummary(nowYmd: nowYmd);

    if (map.isEmpty) {
      return FuelSummaryCard(
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('当年维保费：暂无数据', style: emptyStyle),
        ),
      );
    }

    final publicTotal = map[null] ?? 0.0;

    final deviceIds = map.keys.whereType<int>().toList()..sort();
    double allTotal = publicTotal;
    for (final id in deviceIds) {
      allTotal += (map[id] ?? 0.0);
    }

    return FuelSummaryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('当年维保费用（按设备 & 公共）', style: titleStyle),
          const SizedBox(height: 10),

          // 设备分摊
          for (final id in deviceIds)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      deviceStore.tryFindById(id)?.name ?? '设备$id（已停用/不存在）',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: nameStyle,
                    ),
                  ),
                  Text(FormatUtils.money(map[id] ?? 0.0), style: valueStyle),
                ],
              ),
            ),

          // 公共支出
          if (publicTotal > 0) ...[
            const SizedBox(height: 4),
            const Divider(height: 1, thickness: 1, color: TimingColors.divider),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: Text('公共支出', style: nameStyle)),
                Text(FormatUtils.money(publicTotal), style: valueStyle),
              ],
            ),
          ],

          const Divider(height: 16, color: TimingColors.divider),

          // 合计
          Row(
            children: [
              Expanded(child: Text('合计', style: totalLabelStyle)),
              Text(FormatUtils.money(allTotal), style: totalStyle),
            ],
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // ============================== 十、UI：列表（最近记录） ==============================
  // =====================================================================

  Widget _buildList() {
    final store = context.watch<MaintenanceStore>();
    final deviceStore = context.watch<DeviceStore>();
    final rowTitleStyle = AppTypography.body(
      context,
      fontSize: TimingTokens.recordTitleFontSize,
      height: TimingTokens.recordTitleLineHeight,
      color: AppColors.textPrimary,
    );
    final rowSubtitleStyle = AppTypography.body(
      context,
      fontSize: TimingTokens.recordSubTitleFontSize,
      height: 1,
      color: AppColors.textPrimary,
    );
    final rowValueStyle = AppTypography.body(
      context,
      fontSize: TimingTokens.recordValueFontSize,
      height: 1,
      color: AppColors.textPrimary,
    );
    final rowAmountStyle = AppTypography.body(
      context,
      fontSize: TimingTokens.recordValueFontSize,
      fontWeight: FontWeight.w700,
      height: 1,
      color: AppColors.textPrimary,
    );

    final records = store.records;
    if (records.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpace.xxl),
        child: const AppRecentRecordsEmptyState(),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: records.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, thickness: 1, color: TimingColors.divider),
      itemBuilder: (context, index) {
        final r = records[index];
        final isPublic = (r.deviceId == null);

        String deviceName;

        if (isPublic) {
          deviceName = '公共支出';
        } else {
          final device = deviceStore.tryFindById(r.deviceId!);
          if (device == null) {
            deviceName = '设备#${r.deviceId}（已停用/不存在）';
          } else {
            deviceName = device.name;
          }
        }

        final title = deviceName;
        final dateText = FormatUtils.date(r.ymd);

        final subtitle = (r.note == null || r.note!.trim().isEmpty)
            ? r.item
            : '${r.item} · ${r.note!.trim()}';

        final content = Material(
          color: SheetColors.background,
          child: InkWell(
            onTap: () => _openMaintenanceEditor(editing: r),
            child: SizedBox(
              height: TimingTokens.recordRowHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  TimingTokens.recordRowPaddingLeft,
                  0,
                  TimingTokens.recordRowPaddingRight,
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: rowTitleStyle,
                          ),
                          const SizedBox(
                            height: TimingTokens.recordSubTitleTopGap,
                          ),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: rowSubtitleStyle,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: TimingTokens.recordValueLeftGap),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(dateText, style: rowValueStyle),
                        const SizedBox(
                          height: TimingTokens.recordValueBottomGap,
                        ),
                        Text(
                          FormatUtils.money(r.amount),
                          style: rowAmountStyle,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        return Dismissible(
          key: ValueKey(
            'maintenance-${r.id ?? '${r.ymd}-${r.deviceId}-${r.item}-${r.amount}'}',
          ),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red.shade500,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          confirmDismiss: (_) => _confirmDelete(r),
          onDismissed: (_) {
            _delete(r);
          },
          child: content,
        );
      },
    );
  }

  // =====================================================================
  // ============================== 十一、build：统计 + 列表 ==============================
  // =====================================================================

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MaintenanceStore>();
    final deviceStore = context.watch<DeviceStore>();

    final loading = store.loading || deviceStore.loading;
    final err = firstStoreErrorMessage([store, deviceStore], action: '读取');

    final recordsSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RecordsTitle(count: store.records.length),
        const SizedBox(height: FuelTokens.recordsTitleTopGap),
        _buildList(),
      ],
    );

    return FuelHomePattern(
      header: SectionHeader(title: '维保', onAdd: () => _openMaintenanceEditor()),
      summary: _buildSummaryCard(),
      filter: const SizedBox.shrink(),
      records: recordsSection,
      loading: loading,
      hasFilter: false,
      error: err,
      onRetry: _retryLoad,
    );
  }
}
