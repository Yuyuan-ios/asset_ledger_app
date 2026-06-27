import 'package:flutter/material.dart';

import '../../components/avatars/linked_external_work_badge.dart';
import '../../components/buttons/app_brand_outline_action_button.dart';
import '../../components/layout/name_site_inline_text.dart';
import '../../core/foundation/spacing.dart';
import '../../core/foundation/typography.dart';
import '../../core/utils/format_utils.dart';
import '../../data/models/account_payment.dart';
import '../../data/models/device.dart';
import '../../data/models/project_write_off.dart';
import '../../features/account/domain/services/external_work_detail_rows.dart';
import '../../features/account/model/account_project_payment_display_vm.dart';
import '../../features/account/model/project_title_formatter.dart';
import '../../features/account/presentation/widgets/project_account_detail/project_account_settlement_pill.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../tokens/mapper/account_tokens.dart';
import '../../tokens/mapper/color_tokens.dart';
import '../../tokens/mapper/radius_tokens.dart';
import '../layout/record_card_surface.dart';

part '../../features/account/presentation/widgets/project_account_detail/project_account_detail_sections.dart';
part '../../features/account/presentation/widgets/project_account_detail/project_account_detail_payment_sections.dart';

const _addPaymentPillBackground = AccountTokens.projectCardProgressFill;
const _addPaymentPillBorder = AppColors.textPrimary;
const _addPaymentPillText = SheetColors.actionOn;
const _projectActionPillBackground = AppColors.brand;
const _projectActionPillBorder = AppColors.brand;
const _projectActionPillText = SheetColors.actionOn;
const _paymentEditActionBackground = AppColors.brandOutlineActionPressed;
const _paymentEditActionIcon = AppColors.brand;
const _paymentDeleteActionBackground = Color(0xFFF9D1AD);
const _paymentDeleteActionIcon = AppColors.brand;
const _moneyEpsilon = 0.000001;

class ProjectAccountDetailRateRow {
  final String projectId;
  final String projectKey;
  final String label;
  final int deviceId;
  final String deviceLabel;
  final double hours;
  final double rate;
  final bool showEdit;
  final bool isBreaking;

  const ProjectAccountDetailRateRow({
    this.projectId = '',
    required this.projectKey,
    required this.label,
    required this.deviceId,
    required this.deviceLabel,
    required this.hours,
    required this.rate,
    required this.showEdit,
    required this.isBreaking,
  });
}

/// 项目账户详情内容（仅内容，不含 BottomSheet Shell）
///
/// 职责：
///
/// - 展示项目基础信息
/// - 逐设备单价 + 修改入口
/// - 收款记录列表
/// - 新增 / 编辑 / 删除收款
///
/// 不负责：
///
/// - BottomSheet
/// - Store
/// - 数据计算
///
class ProjectAccountDetailContent extends StatelessWidget {
  final String title; // 项目名
  final int minYmd;

  final List<Device> devices;
  final Map<int, double> deviceRates; // deviceId -> 当前普通单价
  final Map<int, double> breakingDeviceRates; // deviceId -> 当前破碎单价
  final Map<int, double> normalHoursByDevice; // deviceId -> 非破碎总工时
  final Map<int, double> breakingHoursByDevice; // deviceId -> 破碎总工时

  final double receivable;
  final double writeOff;
  final double remaining;
  final bool? isProjectSettled;
  final bool hasUniqueWriteOffForRevoke;
  final bool hasLinkedExternalWork;

  final List<AccountPayment> payments;
  final List<ProjectWriteOff> writeOffs;
  final List<AccountProjectPaymentDisplayVM>? paymentDisplayItems;
  final List<ProjectAccountDetailRateRow>? detailRows;
  final List<AccountProjectExternalWorkDetailRow> externalWorkRows;
  final bool showBatchAction;
  final String batchActionText;
  final bool showPaymentActions;
  final bool showRawPaymentActions;
  final bool showAddPayment;
  final bool canEditRates;

  /// 回调
  final VoidCallback onBatchEditRate;

  /// ✅ 改为：传 deviceId（int），避免上层/下层签名不一致导致红线
  final void Function(int deviceId, bool isBreaking) onEditDeviceRate;

  final VoidCallback onAddPayment;
  final VoidCallback? onSettleProject;
  final void Function(AccountPayment p) onEditPayment;
  final void Function(AccountPayment p) onDeletePayment;
  final void Function(AccountProjectPaymentDisplayVM item)?
  onEditPaymentDisplayItem;
  final void Function(AccountProjectPaymentDisplayVM item)?
  onDeletePaymentDisplayItem;
  final void Function(ProjectAccountDetailRateRow row)? onEditRateRow;
  final void Function(ProjectWriteOff item)? onDeleteWriteOff;
  final VoidCallback? onRevokeWriteOff;

  const ProjectAccountDetailContent({
    super.key,
    required this.title,
    required this.minYmd,
    required this.devices,
    required this.deviceRates,
    required this.breakingDeviceRates,
    required this.normalHoursByDevice,
    required this.breakingHoursByDevice,
    required this.receivable,
    this.writeOff = 0,
    required this.remaining,
    this.isProjectSettled,
    this.hasUniqueWriteOffForRevoke = false,
    this.hasLinkedExternalWork = false,
    required this.payments,
    this.writeOffs = const [],
    required this.onBatchEditRate,
    required this.onEditDeviceRate,
    required this.onAddPayment,
    this.onSettleProject,
    required this.onEditPayment,
    required this.onDeletePayment,
    this.onEditPaymentDisplayItem,
    this.onDeletePaymentDisplayItem,
    this.paymentDisplayItems,
    this.detailRows,
    this.externalWorkRows = const [],
    this.showBatchAction = true,
    this.batchActionText = '',
    this.showPaymentActions = true,
    this.showRawPaymentActions = true,
    this.showAddPayment = true,
    this.canEditRates = true,
    this.onEditRateRow,
    this.onDeleteWriteOff,
    this.onRevokeWriteOff,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final received = (receivable - remaining - writeOff).clamp(0.0, receivable);
    final ratio = receivable <= 0
        ? 0.0
        : (received / receivable).clamp(0.0, 1.0);
    final projectNameStyle = AppTypography.sectionTitle(
      context,
      fontSize: AccountTokens.projectCardTitleFontSize,
      fontWeight: FontWeight.w600,
      height: 1,
      color: SheetColors.textPrimary,
    );
    final actionStyle = AppTypography.actionText(
      context,
      fontSize: AccountTokens.projectDetailActionSize,
      fontWeight: FontWeight.w400,
      color: AccountTokens.projectDetailActionColor,
    );
    final resolvedActionStyle =
        actionStyle ?? DefaultTextStyle.of(context).style;
    final siteStyle = AppTypography.body(
      context,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1,
      color: SheetColors.textPrimary,
    );
    final rowTextStyle = AppTypography.body(
      context,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      height: 1,
      color: SheetColors.textPrimary,
    );
    final rowMetricStyle = AppTypography.body(
      context,
      fontSize: 15,
      fontWeight: FontWeight.w500,
      height: 1,
      color: SheetColors.textPrimary,
    );
    final progressTextStyle = AppTypography.body(
      context,
      fontSize: AccountTokens.projectCardStatusFontSize,
      fontWeight: FontWeight.w400,
      height: 1,
      color: SheetColors.textPrimary,
    );
    final progressAmountStyle = AppTypography.body(
      context,
      fontSize: 18,
      fontWeight: FontWeight.w700,
      height: 1,
      color: SheetColors.textPrimary,
    );
    final progressMetaStyle = AppTypography.body(
      context,
      fontSize: AccountTokens.projectCardStatusFontSize,
      fontWeight: FontWeight.w400,
      height: 1,
      color: SheetColors.textPrimary,
    );
    final sectionTitleStyle = AppTypography.body(
      context,
      fontSize: 18,
      fontWeight: FontWeight.w700,
      height: 1,
      color: SheetColors.textPrimary,
    );
    final emptyStyle = AppTypography.caption(
      context,
      color: Colors.grey.shade600,
    );
    final paymentDateStyle = AppTypography.body(
      context,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      height: 1,
      color: SheetColors.textPrimary,
    );
    final paymentRemarkStyle = AppTypography.caption(
      context,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1,
      color: SheetColors.hint,
    );
    final paymentAmountStyle = AppTypography.body(
      context,
      fontSize: 18,
      fontWeight: FontWeight.w700,
      height: 1,
      color: SheetColors.textPrimary,
    );
    final paymentTagStyle = AppTypography.caption(
      context,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      height: 1,
      color: TimingColors.chartIncome,
    );
    final visibleDetailRows =
        detailRows ?? _buildDeviceDetailRows(devices: devices, l10n: l10n);
    final visiblePaymentItems =
        paymentDisplayItems ?? _paymentItemsFromPayments(payments);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProjectCard(
          l10n: l10n,
          rows: visibleDetailRows,
          externalWorkRows: externalWorkRows,
          isMergedProject: detailRows != null,
          projectNameStyle: projectNameStyle,
          siteStyle: siteStyle,
          rowTextStyle: rowTextStyle,
          rowMetricStyle: rowMetricStyle,
          actionStyle: resolvedActionStyle,
        ),

        const SizedBox(height: AccountTokens.projectCardBottomMargin),

        _buildProgressCard(
          context: context,
          ratio: ratio,
          received: received,
          progressTextStyle: progressTextStyle,
          progressAmountStyle: progressAmountStyle,
          progressMetaStyle: progressMetaStyle,
        ),

        const SizedBox(height: AppSpace.md),

        // ───────────────── 收款记录 ─────────────────
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AccountTokens.projectDetailSectionHorizontalPadding,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.accountPaymentsTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: sectionTitleStyle,
                ),
              ),
              if (showAddPayment) const SizedBox(width: 12),
              if (showAddPayment)
                _buildAddPaymentPillButton(
                  actionStyle: resolvedActionStyle,
                  l10n: l10n,
                ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        if (visiblePaymentItems.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.xxl),
            child: Center(
              child: Text(l10n.accountNoPayments, style: emptyStyle),
            ),
          )
        else
          ...visiblePaymentItems.map(
            (item) => _buildPaymentCard(
              l10n: l10n,
              item: item,
              dateStyle: paymentDateStyle,
              remarkStyle: paymentRemarkStyle,
              amountStyle: paymentAmountStyle,
              tagStyle: paymentTagStyle,
            ),
          ),

        SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 16),
      ],
    );
  }
}
