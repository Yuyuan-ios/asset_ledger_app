import 'package:flutter/material.dart';

import '../../core/foundation/spacing.dart';
import '../../core/foundation/typography.dart';
import '../../data/models/account_payment.dart';
import '../../data/models/device.dart';
import '../../features/account/model/account_project_payment_display_vm.dart';
import '../../core/utils/format_utils.dart';
import '../../tokens/mapper/account_tokens.dart';

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
  final double remaining;

  final List<AccountPayment> payments;
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
  final void Function(AccountPayment p) onEditPayment;
  final void Function(AccountPayment p) onDeletePayment;
  final void Function(AccountProjectPaymentDisplayVM item)?
  onEditPaymentDisplayItem;
  final void Function(AccountProjectPaymentDisplayVM item)?
  onDeletePaymentDisplayItem;
  final void Function(ProjectAccountDetailRateRow row)? onEditRateRow;

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
    required this.remaining,
    required this.payments,
    required this.onBatchEditRate,
    required this.onEditDeviceRate,
    required this.onAddPayment,
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
  });

  @override
  Widget build(BuildContext context) {
    final received = (receivable - remaining).clamp(0.0, receivable);
    final ratio = receivable <= 0
        ? 0.0
        : (received / receivable).clamp(0.0, 1.0);
    final projectNameStyle = AppTypography.sectionTitle(
      context,
      fontSize: AccountTokens.projectDetailProjectNameSize,
      fontWeight: AccountTokens.projectDetailProjectNameWeight,
      height: 1,
      color: Colors.black,
    );
    final actionStyle = AppTypography.actionText(
      context,
      fontSize: AccountTokens.projectDetailActionSize,
      fontWeight: FontWeight.w400,
      color: AccountTokens.projectDetailActionColor,
    );
    final labelStyle = AppTypography.body(
      context,
      fontSize: AccountTokens.projectDetailLabelSize,
      fontWeight: FontWeight.w400,
      color: Colors.black,
    );
    final rowTextStyle = AppTypography.body(
      context,
      fontSize: AccountTokens.projectDetailRowTextSize,
      fontWeight: FontWeight.w400,
      color: Colors.black,
    );
    final progressTextStyle = AppTypography.body(
      context,
      fontSize: AccountTokens.projectDetailProgressTextSize,
      fontWeight: FontWeight.w400,
      color: Colors.black,
    );
    final sectionTitleStyle = AppTypography.body(
      context,
      fontSize: AccountTokens.projectDetailSectionTitleSize,
      fontWeight: AccountTokens.projectDetailSectionTitleWeight,
      color: Colors.black,
    );
    final emptyStyle = AppTypography.caption(
      context,
      color: Colors.grey.shade600,
    );
    final paymentTitleStyle = AppTypography.body(
      context,
      fontWeight: FontWeight.w700,
      color: Colors.black,
    );
    final paymentNoteStyle = AppTypography.caption(
      context,
      fontSize: 12,
      color: Colors.grey.shade600,
    );

    final visibleDetailRows =
        detailRows ?? _buildDeviceDetailRows(devices: devices);
    final visiblePaymentItems =
        paymentDisplayItems ?? _paymentItemsFromPayments(payments);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ───────────────── 顶部：项目名 + 日期 ─────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AccountTokens.projectDetailSectionHorizontalPadding,
            AccountTokens.projectDetailSectionTopPadding,
            AccountTokens.projectDetailSectionHorizontalPadding,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: projectNameStyle,
                ),
              ),
              SizedBox(
                width: AccountTokens.projectDetailBatchActionWidth,
                child: showBatchAction
                    ? Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: onBatchEditRate,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor:
                                AccountTokens.projectDetailActionColor,
                          ),
                          child: Text(batchActionText, style: actionStyle),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),

        const SizedBox(height: AccountTokens.projectDetailTopSectionGap),

        ...visibleDetailRows.asMap().entries.map((entry) {
          final row = entry.value;
          return SizedBox(
            height: AccountTokens.projectDetailRowHeight,
            child: Stack(
              children: [
                if (row.label.trim().isNotEmpty)
                  Positioned(
                    left: AccountTokens.projectDetailLabelLeft,
                    top: 0,
                    bottom: 0,
                    width: AccountTokens.projectDetailLabelWidth,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(row.label, style: labelStyle),
                    ),
                  ),
                Positioned(
                  left: AccountTokens.projectDetailDeviceLeft,
                  top: 0,
                  bottom: 0,
                  width: AccountTokens.projectDetailDeviceWidth,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      row.deviceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: rowTextStyle,
                    ),
                  ),
                ),
                Positioned(
                  left: AccountTokens.projectDetailHoursLeft,
                  top: 0,
                  bottom: 0,
                  width: AccountTokens.projectDetailHoursWidth,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      _hoursText(row.hours),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: rowTextStyle,
                    ),
                  ),
                ),
                Positioned(
                  left: AccountTokens.projectDetailAmountLeft,
                  top: 0,
                  bottom: 0,
                  width: AccountTokens.projectDetailAmountWidth,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      FormatUtils.money(row.rate),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: rowTextStyle,
                    ),
                  ),
                ),
                if (row.showEdit)
                  Positioned(
                    right: AccountTokens.projectDetailActionRightInset,
                    top: 0,
                    bottom: 0,
                    width: AccountTokens.projectDetailActionWidth,
                    child: Align(
                      alignment: Alignment.centerRight,
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
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor:
                              AccountTokens.projectDetailActionColor,
                        ),
                        child: Text('修改', style: actionStyle),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),

        const SizedBox(height: AccountTokens.projectDetailProgressTopGap),

        Padding(
          padding: const EdgeInsets.only(
            left: AccountTokens.projectDetailProgressLeftInset,
          ),
          child: Row(
            children: [
              Text(
                '${(ratio * 100).toStringAsFixed(1)}%实收',
                style: progressTextStyle,
              ),
              const Spacer(),
              Text(
                '余: ${FormatUtils.money(remaining)} / ${FormatUtils.money(receivable)}',
                style: progressTextStyle,
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpace.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(
            AccountTokens.projectDetailProgressRadius,
          ),
          child: SizedBox(
            height: AccountTokens.projectDetailProgressHeight,
            width: double.infinity,
            child: Stack(
              children: [
                Container(color: AccountTokens.projectCardProgressTrack),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(
                    color: AccountTokens.projectCardProgressFill,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AccountTokens.projectDetailDividerTopGap),
        const Divider(height: 1),
        const SizedBox(height: AccountTokens.projectDetailSectionTitleTopGap),

        // ───────────────── 收款记录 ─────────────────
        Padding(
          padding: const EdgeInsets.only(
            left: AccountTokens.projectDetailSectionHorizontalPadding,
          ),
          child: Text('收款记录', style: sectionTitleStyle),
        ),

        const SizedBox(height: AppSpace.sm),

        if (visiblePaymentItems.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.xxl),
            child: Center(child: Text('暂无收款记录', style: emptyStyle)),
          )
        else
          ...visiblePaymentItems.map((item) {
            final title =
                '${FormatUtils.date(item.ymd)}  —  ${FormatUtils.money(item.amount)}';
            final sourceLabel = item.sourceLabel.trim();
            final note = item.note;
            final rawPayment =
                item.type ==
                    AccountProjectPaymentDisplayType.normalMemberPayment
                ? _paymentByDisplayItem(item)
                : null;
            final canEditRawPayment =
                showPaymentActions &&
                showRawPaymentActions &&
                rawPayment != null;
            final canEditDisplayItem =
                showPaymentActions &&
                rawPayment == null &&
                item.type ==
                    AccountProjectPaymentDisplayType.mergeBatchPayment &&
                onEditPaymentDisplayItem != null;
            final canDeleteDisplayItem =
                showPaymentActions &&
                rawPayment == null &&
                item.type ==
                    AccountProjectPaymentDisplayType.mergeBatchPayment &&
                onDeletePaymentDisplayItem != null;
            final showEditButton = canEditRawPayment || canEditDisplayItem;
            final showDeleteButton = canEditRawPayment || canDeleteDisplayItem;

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: title, style: paymentTitleStyle),
                            if (sourceLabel.isNotEmpty)
                              TextSpan(
                                text: '  $sourceLabel',
                                style: paymentNoteStyle,
                              ),
                            if (note != null)
                              TextSpan(
                                text: '  备注:$note',
                                style: paymentNoteStyle,
                              ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (showEditButton)
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: rawPayment != null
                            ? () => onEditPayment(rawPayment)
                            : () => onEditPaymentDisplayItem?.call(item),
                      ),
                    if (showDeleteButton)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: rawPayment != null
                            ? () => onDeletePayment(rawPayment)
                            : () => onDeletePaymentDisplayItem?.call(item),
                      ),
                  ],
                ),
                const Divider(height: 1),
              ],
            );
          }),

        const SizedBox(height: AppSpace.md),

        if (showAddPayment)
          Center(
            child: TextButton.icon(
              onPressed: onAddPayment,
              icon: const Icon(Icons.add),
              label: const Text('新增收款'),
            ),
          ),

        const SizedBox(height: AppSpace.xxl),
      ],
    );
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

  String _hoursText(double h) {
    final rounded = h.toStringAsFixed(1);
    final normalized = rounded.endsWith('.0')
        ? rounded.substring(0, rounded.length - 2)
        : rounded;
    return '$normalized h';
  }
}
