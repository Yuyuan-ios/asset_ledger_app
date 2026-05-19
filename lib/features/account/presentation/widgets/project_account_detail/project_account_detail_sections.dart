part of '../../../../../patterns/account/project_account_detail_content_pattern.dart';

extension ProjectAccountDetailContentSections on ProjectAccountDetailContent {
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
    final canRevokeWriteOff =
        isSettled &&
        writeOff > _moneyEpsilon &&
        writeOffs.isNotEmpty &&
        onDeleteWriteOff != null;
    final settlementPillLabel = canRevokeWriteOff
        ? '撤销'
        : canSettle
        ? '结清'
        : '已结清';
    final settlementPillEnabled = canSettle || canRevokeWriteOff;
    final settlementPillTap = canRevokeWriteOff
        ? () => onDeleteWriteOff?.call(writeOffs.first)
        : onSettleProject;
    final settledSummary = writeOff > _moneyEpsilon
        ? '项目总额 ${FormatUtils.money(receivable)} 核销(减免) ${FormatUtils.money(writeOff)}'
        : '项目总额${FormatUtils.money(receivable)}';

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
            if (isSettled) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      settledSummary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: progressTextStyle,
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Text(
                    '已结清',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    textAlign: TextAlign.right,
                    style: progressTextStyle,
                  ),
                ],
              ),
              if (onSettleProject != null || onDeleteWriteOff != null) ...[
                const SizedBox(height: AppSpace.xs),
                Align(
                  alignment: Alignment.centerRight,
                  child: ProjectAccountSettlementPill(
                    label: settlementPillLabel,
                    enabled: settlementPillEnabled,
                    onTap: settlementPillTap,
                  ),
                ),
              ],
            ] else ...[
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
                  if (canSettle) ...[
                    const SizedBox(width: AppSpace.sm),
                    ProjectAccountSettlementPill(
                      label: settlementPillLabel,
                      enabled: settlementPillEnabled,
                      onTap: settlementPillTap,
                    ),
                  ],
                  const SizedBox(width: AppSpace.sm),
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
            ],
          ],
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
