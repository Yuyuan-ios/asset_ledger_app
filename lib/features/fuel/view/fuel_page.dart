import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../components/feedback/store_action_feedback_l10n.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/utils/store_feedback.dart';
import '../../../core/foundation/typography.dart';
import '../../account/state/account_payment_store.dart';
import '../../account/state/account_store.dart';
import '../../account/state/project_rate_store.dart';
import '../domain/entities/fuel_entities.dart';
import '../domain/services/fuel_suggestions.dart';
import '../../../features/device/state/device_store.dart';
import '../../device/view/lifecycle_payback_card.dart';
import '../../../features/fuel/state/fuel_store.dart';
import '../../../tokens/mapper/fuel_tokens.dart';
import '../../../tokens/mapper/summary_card_tokens.dart';
import '../../timing/state/timing_store.dart';
import '../../../patterns/timing/section_header_pattern.dart';
import '../../../patterns/layout/bottom_sheet_shell_pattern.dart';
import '../../../components/feedback/app_toast.dart';
import '../../../components/feedback/app_confirm_dialog.dart';
import '../../../components/avatars/app_device_avatar.dart';
import '../../../patterns/fuel/fuel_detail_content_pattern.dart';
import '../../../patterns/fuel/fuel_efficiency_summary_pattern.dart';
import '../../../patterns/fuel/fuel_sliver_home_pattern.dart';
import '../../../patterns/fuel/fuel_summary_card_pattern.dart';
import '../../../patterns/fuel/fuel_supplier_filter_pattern.dart';
import '../../../patterns/device/device_picker_items_builder.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../device/application/device_editor_initial_device_resolver.dart';
import '../../device/application/device_meter_resolver.dart';
import 'fuel_page_view_data.dart';

class FuelPage extends StatefulWidget {
  const FuelPage({super.key});

  @override
  State<FuelPage> createState() => _FuelPageState();
}

class _FuelPageState extends State<FuelPage> {
  final _supplierFilterCtrl = TextEditingController();
  String _supplierFilter = '';

  @override
  void dispose() {
    _supplierFilterCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    AppToast.show(context, msg);
  }

  Future<void> _retryLoad() async {
    final fuelStore = context.read<FuelStore>();
    final deviceStore = context.read<DeviceStore>();
    final timingStore = context.read<TimingStore>();
    final paymentStore = context.read<AccountPaymentStore>();
    final rateStore = context.read<ProjectRateStore>();
    final accountStore = context.read<AccountStore>();
    await Future.wait([
      fuelStore.loadAll(),
      deviceStore.loadAll(),
      timingStore.loadAll(),
      paymentStore.loadAll(),
      rateStore.loadAll(),
      accountStore.loadAll(),
    ]);
  }

  Future<void> _openFuelEditor({FuelLog? editing}) async {
    final deviceStore = context.read<DeviceStore>();
    final timingStore = context.read<TimingStore>();
    final fuelStore = context.read<FuelStore>();
    final formKey = GlobalKey<FuelDetailContentState>();
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

    await openEditorSheet<void>(
      context: context,
      title: editing == null
          ? l10n.fuelCreateSheetTitle
          : l10n.fuelEditSheetTitle,
      cancelText: l10n.fuelCancelAction,
      confirmText: l10n.fuelConfirmAction,
      onConfirm: () => formKey.currentState?.submit(),
      childBuilder: (ctx) {
        void sheetToast(String msg) {
          if (!ctx.mounted) return;
          AppToast.show(ctx, msg);
        }

        return FuelDetailContent(
          key: formKey,
          editing: editing,
          logs: fuelStore.logs,
          activeDevices: deviceStore.activeDevices,
          deviceById: editorContext.deviceById,
          deviceItems: editorContext.deviceItems,
          supplierSuggestions: (q) => FuelSuggestions.supplierSuggestions(
            fuelStore.logs,
            q,
            limit: 9999,
          ),
          onToast: sheetToast,
          onSubmit: (log) async {
            if (log.id == null) {
              await fuelStore.insert(log);
            } else {
              await fuelStore.update(log);
            }

            if (!mounted || !ctx.mounted) return;
            final feedback = storeActionFeedback(
              fuelStore,
              action: StoreActionKind.save,
            );
            final message = localizeStoreActionFeedback(
              AppLocalizations.of(ctx),
              feedback,
            );
            if (!feedback.isSuccess) {
              sheetToast(message);
              return;
            }
            _toast(message);
            if (!ctx.mounted) return;
            Navigator.of(ctx).pop();
          },
        );
      },
    );
  }

  Future<bool> _confirmDelete(FuelLog log) async {
    if (log.id == null) return false;
    final l10n = AppLocalizations.of(context);
    final ok = await showAppConfirmDialog(
      context: context,
      title: l10n.fuelDeleteConfirmTitle,
      content: l10n.fuelDeleteConfirmContent,
      cancelText: l10n.fuelCancelAction,
      confirmText: l10n.fuelDeleteConfirmAction,
    );
    return ok == true;
  }

  Future<bool> _delete(FuelLog log) async {
    if (log.id == null) return false;
    if (!mounted) return false;

    final store = context.read<FuelStore>();
    await store.deleteById(log.id!);

    if (!mounted) return false;
    final feedback = storeActionFeedback(store, action: StoreActionKind.delete);
    _toast(localizeStoreActionFeedback(AppLocalizations.of(context), feedback));
    if (!feedback.isSuccess) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fuelStore = context.watch<FuelStore>();
    final deviceStore = context.watch<DeviceStore>();
    final timingStore = context.watch<TimingStore>();
    final paymentStore = context.watch<AccountPaymentStore>();
    final rateStore = context.watch<ProjectRateStore>();
    final accountStore = context.watch<AccountStore>();
    final viewData = buildFuelPageViewData(
      fuelStore: fuelStore,
      deviceStore: deviceStore,
      timingStore: timingStore,
      paymentStore: paymentStore,
      rateStore: rateStore,
      accountStore: accountStore,
      supplierFilter: _supplierFilter,
      inactiveDeviceIndexLabel: l10n.deviceInactiveIndexLabel,
    );
    final summaryLabelStyle = AppTypography.body(
      context,
      fontSize: SummaryCardTokens.totalLabelFontSize,
      fontWeight: FontWeight.w800,
      color: Colors.black,
    );
    final summaryValueStyle = AppTypography.body(
      context,
      fontSize: SummaryCardTokens.totalValueFontSize,
      fontWeight: FontWeight.w800,
      color: Colors.black,
    );

    final summary = FuelSummaryCard(
      height: FuelTokens.efficiencyCardHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: FuelEfficiencySummary(
              byDevice: viewData.byDevice,
              deviceNameOf: (id) {
                return viewData.deviceDisplayNameById[id] ??
                    l10n.fuelInactiveDeviceFallbackName(id);
              },
              businessSegmentDividerBuilder: (id) {
                final result = viewData.lifecyclePaybackByDeviceId[id];
                if (result == null || result.isCostUnset) return null;
                return DeviceLifecycleSegmentDivider(
                  key: ValueKey('fuel-efficiency-business-segment-divider-$id'),
                  barKey: ValueKey(
                    'fuel-efficiency-business-segment-divider-bar-$id',
                  ),
                  result: result,
                );
              },
            ),
          ),
          const SizedBox(height: FuelTokens.summaryInnerGap),
          Row(
            children: [
              Text(viewData.yearSummaryTitle, style: summaryLabelStyle),
              const SizedBox(width: FuelTokens.summaryTotalValueLeftGap),
              Expanded(
                child: Text(
                  '${FormatUtils.liters(viewData.yearSummary.liters)} L / ${FormatUtils.money(viewData.yearSummary.cost)}',
                  textAlign: TextAlign.right,
                  style: summaryValueStyle,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final filter = FuelSupplierFilter(
      controller: _supplierFilterCtrl,
      suggestionsBuilder: (query) =>
          FuelSuggestions.supplierSuggestions(fuelStore.logs, query),
      onChanged: (v) => setState(() => _supplierFilter = v.trim()),
      onSelected: (v) {
        _supplierFilterCtrl.text = v;
        setState(() => _supplierFilter = v.trim());
      },
    );

    return FuelSliverHomePattern(
      header: SectionHeader(
        title: l10n.fuelPageTitle,
        onAdd: () => _openFuelEditor(),
      ),
      summary: summary,
      filter: filter,
      logs: viewData.filteredLogs,
      leadingBuilder: (log) {
        final d = deviceStore.tryFindById(log.deviceId);
        if (d == null) {
          return const SizedBox(
            width: 45,
            height: 45,
            child: CircleAvatar(radius: 22.5, child: Text('?')),
          );
        }
        return SizedBox(
          width: 45,
          height: 45,
          child: DeviceAvatar(
            brand: d.brand,
            customAvatarPath: d.customAvatarPath,
            radius: 22.5,
          ),
        );
      },
      titleBuilder: (log) => log.supplier,
      subtitleBuilder: (log) => viewData.deviceIndexById[log.deviceId] ?? '?',
      onTap: (log) => _openFuelEditor(editing: log),
      onConfirmDelete: _confirmDelete,
      onDelete: _delete,
      loading: viewData.loading,
      error: viewData.error == null
          ? null
          : localizeStoreActionFeedback(
              AppLocalizations.of(context),
              viewData.error!,
            ),
      onRetry: () => _retryLoad(),
    );
  }
}
