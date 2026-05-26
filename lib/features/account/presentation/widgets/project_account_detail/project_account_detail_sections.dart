part of '../../../../../patterns/account/project_account_detail_content_pattern.dart';

extension ProjectAccountDetailContentSections on ProjectAccountDetailContent {
  Widget _buildProjectCard({
    required List<ProjectAccountDetailRateRow> rows,
    required List<AccountProjectExternalWorkDetailRow> externalWorkRows,
    required bool isMergedProject,
    required TextStyle? projectNameStyle,
    required TextStyle? siteStyle,
    required TextStyle? rowTextStyle,
    required TextStyle? rowMetricStyle,
    required TextStyle actionStyle,
  }) {
    final children = <Widget>[];
    var lastSiteLabel = _fallbackSiteLabel();
    var hasShownLocalDeviceHeader = false;
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      final rawLabel = row.label.trim();
      final isNewSiteBlock = rawLabel.isNotEmpty && rawLabel != '设备单价';
      if (isNewSiteBlock) {
        lastSiteLabel = rawLabel;
      }

      // 合并项目：每个新地址块都要重新出现 "📍 地址  ⚙ 本地设备" 标题。
      // 普通项目：标题只在首行展示一次。
      final showHeader = isMergedProject
          ? isNewSiteBlock
          : !hasShownLocalDeviceHeader;
      final headerSite = _headerSiteName(
        isMergedProject: isMergedProject,
        projectTitle: title,
        siteName: lastSiteLabel,
      );

      final isLastLocalRow = index == rows.length - 1;
      children.add(
        _buildProjectDetailRow(
          row: row,
          headerSiteName: headerSite,
          showHeader: showHeader,
          showDivider: !isLastLocalRow,
          siteStyle: siteStyle,
          rowTextStyle: rowTextStyle,
          rowMetricStyle: rowMetricStyle,
          actionStyle: actionStyle,
        ),
      );

      if (showHeader) {
        hasShownLocalDeviceHeader = true;
      }
    }

    for (var index = 0; index < externalWorkRows.length; index++) {
      final externalRow = externalWorkRows[index];
      // 本地设备和外协设备之间永远画一条分隔线；多个外协包之间也画。
      final needsTopDivider = index == 0 ? rows.isNotEmpty : true;
      children.add(
        _buildExternalWorkSection(
          row: externalRow,
          showTopDivider: needsTopDivider,
          siteStyle: siteStyle,
          rowTextStyle: rowTextStyle,
          rowMetricStyle: rowMetricStyle,
        ),
      );
    }

    final titleParts = _splitTitleParts(title);

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
                  child: Row(
                    children: [
                      Flexible(
                        fit: FlexFit.loose,
                        child: NameSiteInlineText(
                          name: titleParts.$1,
                          site: titleParts.$2,
                          nameStyle: projectNameStyle,
                          siteStyle: projectNameStyle,
                          separatorStyle: projectNameStyle,
                        ),
                      ),
                      if (hasLinkedExternalWork) ...[
                        const SizedBox(width: 6),
                        const LinkedExternalWorkBadge(
                          key: Key(
                            'account-project-detail-linked-external-work',
                          ),
                          borderColor: SheetColors.background,
                        ),
                      ],
                    ],
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
    required String? headerSiteName,
    required bool showHeader,
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
        if (showHeader) ...[
          _buildDeviceSectionHeader(
            siteName: headerSiteName,
            label: _localDeviceLabel,
            labelIcon: Icons.settings_outlined,
            siteStyle: siteStyle,
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

  Widget _buildExternalWorkSection({
    required AccountProjectExternalWorkDetailRow row,
    required bool showTopDivider,
    required TextStyle? siteStyle,
    required TextStyle? rowTextStyle,
    required TextStyle? rowMetricStyle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTopDivider) ...[
          const SizedBox(height: 6),
          const Divider(height: 1, color: TimingColors.cardBorder),
          const SizedBox(height: 6),
        ],
        _buildExternalWorkHeader(
          row: row,
          siteStyle: siteStyle,
        ),
        const SizedBox(height: AppSpace.xs),
        Row(
          children: [
            Expanded(
              child: Text(
                _externalWorkRowLabel(row),
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
          ],
        ),
      ],
    );
  }

  Widget _buildExternalWorkHeader({
    required AccountProjectExternalWorkDetailRow row,
    required TextStyle? siteStyle,
  }) {
    final iconColor = AccountTokens.projectDetailActionColor;
    return Row(
      children: [
        Icon(Icons.settings_outlined, size: 18, color: iconColor),
        const SizedBox(width: 6),
        Text(
          _externalDeviceLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: siteStyle,
        ),
        const SizedBox(width: 12),
        // "分享人 · 地址" 分段省略；右侧没有固定按钮，让它吃满到卡片右边缘。
        Expanded(
          child: NameSiteInlineText(
            name: row.sourceDisplayName,
            site: row.siteSummary,
            nameStyle: siteStyle,
            siteStyle: siteStyle,
            separatorStyle: siteStyle,
          ),
        ),
      ],
    );
  }

  String _externalWorkRowLabel(AccountProjectExternalWorkDetailRow row) {
    final summary = row.equipmentSummary.trim();
    final base = summary.isEmpty ? '设备未填写' : summary;
    return '$base·${row.recordCount}条记录';
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
    final effectiveSettled =
        isProjectSettled ??
        (hasProjectTotal && displayRemaining <= _moneyEpsilon);
    final visuallySettled =
        hasProjectTotal &&
        (effectiveSettled || displayRemaining <= _moneyEpsilon);
    final canSettle =
        hasProjectTotal &&
        !visuallySettled &&
        displayRemaining > _moneyEpsilon &&
        onSettleProject != null;
    final canRevokeSettlement =
        visuallySettled &&
        hasUniqueWriteOffForRevoke &&
        onRevokeWriteOff != null;
    final settledSummary = '项目总额 ${FormatUtils.money(receivable)}';

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
        decoration: _progressCardDecoration(),
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
            if (visuallySettled) ...[
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
              const SizedBox(height: AppSpace.xs),
              Align(
                alignment: Alignment.centerRight,
                child: ProjectAccountSettlementPill(
                  label: canRevokeSettlement ? '已结清，点此撤销' : '已结清',
                  enabled: canRevokeSettlement,
                  onTap: canRevokeSettlement ? onRevokeWriteOff : null,
                ),
              ),
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
                    flex: 3,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            FormatUtils.money(received),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: progressAmountStyle,
                          ),
                        ),
                        if (canSettle) ...[
                          const SizedBox(width: 9),
                          ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 38),
                            child: _buildInlineSettleAction(
                              context: context,
                              style: progressMetaStyle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    flex: 2,
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

  Widget _buildInlineSettleAction({
    required BuildContext context,
    required TextStyle? style,
  }) {
    final actionStyle = (style ?? DefaultTextStyle.of(context).style).copyWith(
      color: AccountTokens.projectDetailActionColor,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    return InkWell(
      onTap: onSettleProject,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Text(
          '结清',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: actionStyle,
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

  BoxDecoration _progressCardDecoration() {
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
    final parts = title.split(ProjectTitleFormatter.separator);
    if (parts.length >= 2) {
      final site = parts.last.trim();
      if (site.isNotEmpty) return site;
    }
    final legacyParts = title.split('+');
    if (legacyParts.length >= 2) {
      final site = legacyParts.last.trim();
      if (site.isNotEmpty) return site;
    }
    return '';
  }

  String? _headerSiteName({
    required bool isMergedProject,
    required String projectTitle,
    required String siteName,
  }) {
    final normalizedSite = siteName.trim();
    if (normalizedSite.isEmpty) return null;

    if (isMergedProject) return normalizedSite;

    final normalizedTitle = projectTitle.trim();
    // 普通项目的标题已经展示了"姓名 · 地址"，地址重复展示反而冗余，
    // 所以普通项目只显示 "⚙ 本地设备"，省略 "📍 地址"。
    if (normalizedTitle.contains(normalizedSite)) return null;

    return normalizedSite;
  }

  (String, String?) _splitTitleParts(String value) {
    final trimmed = value.trim();
    final sepIndex = trimmed.indexOf(ProjectTitleFormatter.separator);
    if (sepIndex <= 0) return (trimmed, null);
    final name = trimmed.substring(0, sepIndex).trim();
    final tail = trimmed
        .substring(sepIndex + ProjectTitleFormatter.separator.length)
        .trim();
    if (tail.isEmpty) return (name, null);
    return (name, tail);
  }

  Widget _buildDeviceSectionHeader({
    required String? siteName,
    required String label,
    required IconData labelIcon,
    required TextStyle? siteStyle,
  }) {
    final iconColor = AccountTokens.projectDetailActionColor;
    final labelWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(labelIcon, size: 18, color: iconColor),
        const SizedBox(width: 6),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: siteStyle,
        ),
      ],
    );

    if (siteName == null || siteName.isEmpty) {
      // 没有地址需要展示时，"⚙ 本地设备" 单独占一行。
      return Row(children: [labelWidget]);
    }

    return Row(
      children: [
        Icon(Icons.location_on_outlined, size: 18, color: iconColor),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            siteName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: siteStyle,
          ),
        ),
        const SizedBox(width: 12),
        // "本地设备" 标签是固定语义，不能被动态地址挤掉。
        labelWidget,
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
