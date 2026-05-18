import 'package:flutter/material.dart';

import '../../core/foundation/spacing.dart';
import '../../core/foundation/typography.dart';
import '../../data/models/account_payment.dart';
import '../../data/models/device.dart';
import '../../data/models/project_write_off.dart';
import '../../features/account/presentation/widgets/project_account_detail/project_account_settlement_pill.dart';
import '../../features/account/model/account_project_payment_display_vm.dart';
import '../../core/utils/format_utils.dart';
import '../../tokens/mapper/account_tokens.dart';
import '../../tokens/mapper/color_tokens.dart';

const _addPaymentPillBackground = Color(0xFFEAF7F5);
const _addPaymentPillBorder = Color(0xFF8AD5CC);
const _addPaymentPillText = Color(0xFF147C73);
const _projectActionPillBackground = Color(0xFFF5F2EE);
const _projectActionPillBorder = Color(0xFFD8C8B8);
const _projectActionPillText = Color(0xFF7A5A3A);
const _moneyEpsilon = 0.000001;

class ProjectAccountDetailRateRow {
  final String projectKey;
  final String label;
  final int deviceId;
  final String deviceLabel;
  final double hours;
  final double rate;
  final bool showEdit;
  final bool isBreaking;

  const ProjectAccountDetailRateRow({
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

  final List<AccountPayment> payments;
  final List<ProjectWriteOff> writeOffs;
  final List<AccountProjectPaymentDisplayVM>? paymentDisplayItems;
  final List<ProjectAccountDetailRateRow>? detailRows;
  final bool showBatchAction;
  final String batchActionText;
  final bool showPaymentActions;
  final bool showRawPaymentActions;
  final bool showAddPayment;

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
    this.showBatchAction = true,
    this.batchActionText = '批量修改',
    this.showPaymentActions = true,
    this.showRawPaymentActions = true,
    this.showAddPayment = true,
    this.onEditRateRow,
    this.onDeleteWriteOff,
  });

  @override
  Widget build(BuildContext context) {
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
    final writeOffReasonStyle = AppTypography.body(
      context,
      fontSize: 15,
      fontWeight: FontWeight.w500,
      height: 1,
      color: SheetColors.textPrimary,
    );

    final visibleDetailRows =
        detailRows ?? _buildDeviceDetailRows(devices: devices);
    final visiblePaymentItems =
        paymentDisplayItems ?? _paymentItemsFromPayments(payments);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProjectCard(
          rows: visibleDetailRows,
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

        if (writeOffs.isNotEmpty) ...[
          _buildWriteOffSection(
            sectionTitleStyle: sectionTitleStyle,
            dateStyle: paymentDateStyle,
            amountStyle: paymentAmountStyle,
            reasonStyle: writeOffReasonStyle,
            remarkStyle: paymentRemarkStyle,
          ),
          const SizedBox(height: AppSpace.md),
        ],

        // ───────────────── 收款记录 ─────────────────
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AccountTokens.projectDetailSectionHorizontalPadding,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '收款记录',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: sectionTitleStyle,
                ),
              ),
              if (showAddPayment) const SizedBox(width: 12),
              if (showAddPayment)
                _buildAddPaymentPillButton(actionStyle: resolvedActionStyle),
            ],
          ),
        ),

        const SizedBox(height: 6),

        if (visiblePaymentItems.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.xxl),
            child: Center(child: Text('暂无收款记录', style: emptyStyle)),
          )
        else
          ...visiblePaymentItems.map(
            (item) => _buildPaymentCard(
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

  Widget _buildProjectCard({
    required List<ProjectAccountDetailRateRow> rows,
    required bool isMergedProject,
    required TextStyle? projectNameStyle,
    required TextStyle? siteStyle,
    required TextStyle? rowTextStyle,
    required TextStyle? rowMetricStyle,
    required TextStyle actionStyle,
  }) {
    final children = <Widget>[];
    var lastSiteLabel = _fallbackSiteLabel();
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      final rawLabel = row.label.trim();
      if (rawLabel.isNotEmpty && rawLabel != '设备单价') {
        lastSiteLabel = rawLabel;
      }
      final siteRowLabel = _siteRowLabel(
        isMergedProject: isMergedProject,
        projectTitle: title,
        siteName: lastSiteLabel,
      );

      children.add(
        _buildProjectDetailRow(
          row: row,
          siteLabel: siteRowLabel ?? '',
          showSiteRow: siteRowLabel != null,
          showDivider: index != rows.length - 1,
          siteStyle: siteStyle,
          rowTextStyle: rowTextStyle,
          rowMetricStyle: rowMetricStyle,
          actionStyle: actionStyle,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AccountTokens.projectDetailSectionHorizontalPadding,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AccountTokens.projectCardPaddingHorizontal,
          vertical: AccountTokens.projectCardPaddingTop,
        ),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: projectNameStyle,
                  ),
                ),
                if (showBatchAction) ...[
                  const SizedBox(width: AppSpace.sm),
                  _buildProjectActionPill(actionStyle: actionStyle),
                ],
              ],
            ),
            if (children.isNotEmpty) ...[
              const SizedBox(height: AccountTokens.projectCardSectionGap),
              ...children,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProjectDetailRow({
    required ProjectAccountDetailRateRow row,
    required String siteLabel,
    required bool showSiteRow,
    required bool showDivider,
    required TextStyle? siteStyle,
    required TextStyle? rowTextStyle,
    required TextStyle? rowMetricStyle,
    required TextStyle actionStyle,
  }) {
    final editButton = row.showEdit
        ? SizedBox(
            width: 48,
            height: 36,
            child: TextButton(
              onPressed: () {
                final editRow = onEditRateRow;
                if (editRow != null) {
                  editRow(row);
                  return;
                }
                onEditDeviceRate(row.deviceId, row.isBreaking);
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(48, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: AccountTokens.projectDetailActionColor,
              ),
              child: Text(
                '修改',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: actionStyle,
              ),
            ),
          )
        : const SizedBox(width: 48, height: 36);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showSiteRow) ...[
          Row(
            children: [
              Icon(
                siteLabel == '设备'
                    ? Icons.settings_outlined
                    : Icons.location_on_outlined,
                size: 18,
                color: AccountTokens.projectDetailActionColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  siteLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: siteStyle,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                row.deviceLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: rowTextStyle,
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            SizedBox(
              width: 58,
              child: Text(
                _hoursText(row.hours),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                textAlign: TextAlign.right,
                style: rowMetricStyle,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 62,
              child: Text(
                FormatUtils.money(row.rate),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                textAlign: TextAlign.right,
                style: rowMetricStyle,
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            editButton,
          ],
        ),
        if (showDivider) ...[
          const SizedBox(height: 6),
          const Divider(height: 1, color: TimingColors.cardBorder),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _buildAddPaymentPillButton({required TextStyle actionStyle}) {
    final pillStyle = actionStyle.copyWith(
      color: _addPaymentPillText,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );

    return InkWell(
      onTap: onAddPayment,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _addPaymentPillBackground,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _addPaymentPillBorder),
        ),
        child: Text(
          '+ 新增收款',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: pillStyle,
        ),
      ),
    );
  }

  Widget _buildProjectActionPill({required TextStyle actionStyle}) {
    final pillStyle = actionStyle.copyWith(
      color: _projectActionPillText,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );

    return InkWell(
      onTap: onBatchEditRate,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _projectActionPillBackground,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _projectActionPillBorder),
        ),
        child: Text(
          batchActionText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: pillStyle,
        ),
      ),
    );
  }

  Widget _buildPaymentSourceBadge({
    required String sourceLabel,
    required TextStyle? tagStyle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F5E8),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        sourceLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: tagStyle,
      ),
    );
  }

  Widget _buildProgressCard({
    required BuildContext context,
    required double ratio,
    required double received,
    required TextStyle? progressTextStyle,
    required TextStyle? progressAmountStyle,
    required TextStyle? progressMetaStyle,
  }) {
    final rawRemaining = remaining.abs() <= _moneyEpsilon ? 0.0 : remaining;
    final displayRemaining = rawRemaining < 0 ? 0.0 : rawRemaining;
    final hasProjectTotal = receivable > _moneyEpsilon;
    final canSettle =
        hasProjectTotal &&
        displayRemaining > _moneyEpsilon &&
        onSettleProject != null;
    final isSettled = hasProjectTotal && displayRemaining <= _moneyEpsilon;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AccountTokens.projectDetailSectionHorizontalPadding,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AccountTokens.projectCardPaddingHorizontal,
          vertical: AccountTokens.projectCardPaddingTop,
        ),
        decoration: _cardDecoration(),
        child: Column(
          children: [
            SizedBox(
              height: AccountTokens.projectCardProgressHeight,
              width: double.infinity,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Stack(
                  children: [
                    Container(
                      height: AccountTokens.projectCardProgressFillHeight,
                      decoration: BoxDecoration(
                        color: AccountTokens.projectCardProgressTrack,
                        borderRadius: BorderRadius.circular(
                          AccountTokens.projectCardProgressRadius,
                        ),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: ratio,
                      child: Container(
                        height: AccountTokens.projectCardProgressFillHeight,
                        decoration: BoxDecoration(
                          color: AccountTokens.projectCardProgressFill,
                          borderRadius: BorderRadius.circular(
                            AccountTokens.projectCardProgressRadius,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '已收 ${(ratio * 100).toStringAsFixed(1)}%',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: progressTextStyle,
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Text(
                    '待收 ${FormatUtils.money(displayRemaining)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    textAlign: TextAlign.right,
                    style: progressTextStyle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.xs),
            Row(
              children: [
                Expanded(
                  child: Text(
                    FormatUtils.money(received),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: progressAmountStyle,
                  ),
                ),
                if (canSettle || isSettled) ...[
                  const SizedBox(width: AppSpace.sm),
                  ProjectAccountSettlementPill(
                    enabled: canSettle,
                    onTap: onSettleProject,
                  ),
                ],
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Text(
                    '项目总额 ${FormatUtils.money(receivable)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    textAlign: TextAlign.right,
                    style: progressMetaStyle,
                  ),
                ),
              ],
            ),
            if (writeOff > _moneyEpsilon) ...[
              const SizedBox(height: AppSpace.xs),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '已核销 ${FormatUtils.money(writeOff)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  textAlign: TextAlign.right,
                  style: progressMetaStyle?.copyWith(
                    color: SheetColors.hint,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWriteOffSection({
    required TextStyle? sectionTitleStyle,
    required TextStyle? dateStyle,
    required TextStyle? amountStyle,
    required TextStyle? reasonStyle,
    required TextStyle? remarkStyle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AccountTokens.projectDetailSectionHorizontalPadding,
          ),
          child: Text(
            '核销记录',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: sectionTitleStyle,
          ),
        ),
        const SizedBox(height: 6),
        ...writeOffs.map(
          (item) => _buildWriteOffCard(
            item: item,
            dateStyle: dateStyle,
            amountStyle: amountStyle,
            reasonStyle: reasonStyle,
            remarkStyle: remarkStyle,
          ),
        ),
      ],
    );
  }

  Widget _buildWriteOffCard({
    required ProjectWriteOff item,
    required TextStyle? dateStyle,
    required TextStyle? amountStyle,
    required TextStyle? reasonStyle,
    required TextStyle? remarkStyle,
  }) {
    final note = item.note?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.only(
        left: AccountTokens.projectDetailSectionHorizontalPadding,
        right: AccountTokens.projectDetailSectionHorizontalPadding,
        bottom: AccountTokens.projectCardBottomMargin,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AccountTokens.projectCardPaddingHorizontal,
          vertical: 9,
        ),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatWriteOffDate(item.writeOffDate),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: dateStyle,
                  ),
                ),
                Text(FormatUtils.money(item.amount), style: amountStyle),
                if (onDeleteWriteOff != null) ...[
                  const SizedBox(width: AppSpace.xs),
                  IconButton(
                    tooltip: '删除核销记录',
                    onPressed: () => onDeleteWriteOff?.call(item),
                    icon: Icon(
                      Icons.delete_outline,
                      size: 21,
                      color: AccountTokens.projectDetailActionColor,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpace.xs),
            Row(
              children: [
                Text(_writeOffReasonLabel(item.reason), style: reasonStyle),
                if (note.isNotEmpty) ...[
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Text(
                      '备注：$note',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: remarkStyle,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard({
    required AccountProjectPaymentDisplayVM item,
    required TextStyle? dateStyle,
    required TextStyle? remarkStyle,
    required TextStyle? amountStyle,
    required TextStyle? tagStyle,
  }) {
    final dateText = FormatUtils.date(item.ymd);
    final amountText = FormatUtils.money(item.amount);
    final sourceLabel = item.sourceLabel.trim();
    final remarkText = item.note?.trim() ?? '';
    final rawPayment =
        item.type == AccountProjectPaymentDisplayType.normalMemberPayment
        ? _paymentByDisplayItem(item)
        : null;
    final canEditRawPayment =
        showPaymentActions && showRawPaymentActions && rawPayment != null;
    final canEditDisplayItem =
        showPaymentActions &&
        rawPayment == null &&
        item.type == AccountProjectPaymentDisplayType.mergeBatchPayment &&
        onEditPaymentDisplayItem != null;
    final canDeleteDisplayItem =
        showPaymentActions &&
        rawPayment == null &&
        item.type == AccountProjectPaymentDisplayType.mergeBatchPayment &&
        onDeletePaymentDisplayItem != null;
    final showEditButton = canEditRawPayment || canEditDisplayItem;
    final showDeleteButton = canEditRawPayment || canDeleteDisplayItem;

    return Padding(
      padding: const EdgeInsets.only(
        left: AccountTokens.projectDetailSectionHorizontalPadding,
        right: AccountTokens.projectDetailSectionHorizontalPadding,
        bottom: AccountTokens.projectCardBottomMargin,
      ),
      child: Container(
        height: 66,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: _cardDecoration(),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AccountTokens.projectCardPaddingHorizontal,
                  7,
                  AppSpace.sm,
                  7,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 92),
                          child: Text(
                            dateText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: dateStyle,
                          ),
                        ),
                        if (sourceLabel.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Flexible(
                            child: _buildPaymentSourceBadge(
                              sourceLabel: sourceLabel,
                              tagStyle: tagStyle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            amountText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: amountStyle,
                          ),
                        ),
                        if (remarkText.isNotEmpty) ...[
                          const SizedBox(width: AppSpace.md),
                          Expanded(
                            child: Text(
                              '备注：$remarkText',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                              style: remarkStyle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (showEditButton)
              _buildPaymentAction(
                icon: Icons.edit_outlined,
                backgroundColor: const Color(0xFFFFF7F0),
                onPressed: rawPayment != null
                    ? () => onEditPayment(rawPayment)
                    : () => onEditPaymentDisplayItem?.call(item),
              ),
            if (showDeleteButton)
              _buildPaymentAction(
                icon: Icons.delete_outline,
                backgroundColor: const Color(0xFFFFF0E6),
                onPressed: rawPayment != null
                    ? () => onDeletePayment(rawPayment)
                    : () => onDeletePaymentDisplayItem?.call(item),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentAction({
    required IconData icon,
    required Color backgroundColor,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 52,
      height: double.infinity,
      child: ColoredBox(
        color: backgroundColor,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(
            icon,
            size: 21,
            color: AccountTokens.projectDetailActionColor,
          ),
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: SheetColors.background,
      border: Border.all(
        color: AccountTokens.projectCardBorderColor,
        width: AccountTokens.projectCardBorderWidth,
      ),
      borderRadius: BorderRadius.circular(AccountTokens.projectCardRadius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(
            alpha: AccountTokens.projectCardShadowOpacity,
          ),
          blurRadius: AccountTokens.projectCardShadowBlur,
          offset: const Offset(
            AccountTokens.projectCardShadowOffsetX,
            AccountTokens.projectCardShadowOffsetY,
          ),
        ),
      ],
    );
  }

  String _fallbackSiteLabel() {
    final parts = title.split('+');
    if (parts.length >= 2) {
      final site = parts.last.trim();
      if (site.isNotEmpty) return site;
    }
    return '';
  }

  String? _siteRowLabel({
    required bool isMergedProject,
    required String projectTitle,
    required String siteName,
  }) {
    final normalizedSite = siteName.trim();
    if (normalizedSite.isEmpty) return null;

    if (isMergedProject) return normalizedSite;

    final normalizedTitle = projectTitle.trim();
    if (normalizedTitle.contains(normalizedSite)) return '设备';

    return normalizedSite;
  }

  List<ProjectAccountDetailRateRow> _buildDeviceDetailRows({
    required List<Device> devices,
  }) {
    final rows = <ProjectAccountDetailRateRow>[];
    for (final d in devices) {
      final id = d.id;
      if (id == null) continue;

      final rate = deviceRates[id] ?? d.defaultUnitPrice;
      final breakingRate =
          breakingDeviceRates[id] ?? d.breakingUnitPrice ?? d.defaultUnitPrice;
      final normalHours = normalHoursByDevice[id] ?? 0.0;
      final breakingHours = breakingHoursByDevice[id] ?? 0.0;

      // 普通模式：默认展示；若仅有破碎工时，则隐藏普通行，避免重复信息。
      if (normalHours > 0 || breakingHours <= 0) {
        rows.add(
          ProjectAccountDetailRateRow(
            projectKey: '',
            label: rows.isEmpty ? '设备单价' : '',
            deviceId: id,
            deviceLabel: d.name,
            hours: normalHours,
            rate: rate,
            showEdit: true,
            isBreaking: false,
          ),
        );
      }

      if (breakingHours > 0) {
        rows.add(
          ProjectAccountDetailRateRow(
            projectKey: '',
            label: rows.isEmpty ? '设备单价' : '',
            deviceId: id,
            deviceLabel: '${d.name} · 破碎',
            hours: breakingHours,
            rate: breakingRate,
            showEdit: true,
            isBreaking: true,
          ),
        );
      }
    }
    return rows;
  }

  List<AccountProjectPaymentDisplayVM> _paymentItemsFromPayments(
    List<AccountPayment> payments,
  ) {
    return payments.map((payment) {
      final note = payment.note?.trim();
      return AccountProjectPaymentDisplayVM(
        id:
            payment.id?.toString() ??
            'payment:${payment.projectKey}:${payment.ymd}',
        type: AccountProjectPaymentDisplayType.normalMemberPayment,
        ymd: payment.ymd,
        amount: payment.amount,
        note: note == null || note.isEmpty ? null : note,
        sourceLabel: '',
        relatedProjectKey: payment.projectKey,
        sortCreatedAt: payment.createdAt,
        sortId: payment.id,
      );
    }).toList();
  }

  AccountPayment? _paymentByDisplayItem(AccountProjectPaymentDisplayVM item) {
    for (final payment in payments) {
      final id = payment.id;
      if (id != null && item.id == id.toString()) return payment;
    }
    return null;
  }

  String _formatWriteOffDate(String value) {
    final normalized = value
        .trim()
        .replaceAll('-', '')
        .replaceAll('.', '')
        .replaceAll('/', '');
    final ymd = int.tryParse(normalized);
    if (ymd == null || normalized.length != 8) return value;
    return FormatUtils.date(ymd);
  }

  String _writeOffReasonLabel(String value) {
    switch (ProjectWriteOffReasonX.fromDbValue(value)) {
      case ProjectWriteOffReason.rounding:
        return '抹零';
      case ProjectWriteOffReason.qualityDeduction:
        return '质量扣款';
      case ProjectWriteOffReason.underpaid:
        return '客户少付';
      case ProjectWriteOffReason.badDebt:
        return '坏账核销';
      case ProjectWriteOffReason.settlement:
        return '协商结清';
      case ProjectWriteOffReason.offset:
        return '抵账';
      case ProjectWriteOffReason.other:
        return '其他';
    }
  }

  String _hoursText(double h) {
    final rounded = h.toStringAsFixed(1);
    final normalized = rounded.endsWith('.0')
        ? rounded.substring(0, rounded.length - 2)
        : rounded;
    return '$normalized h';
  }
}
