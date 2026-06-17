import 'package:flutter/material.dart';

import '../../core/foundation/spacing.dart';
import '../../core/foundation/typography.dart';
import '../../core/money/amount_policy.dart';
import '../../core/utils/format_utils.dart';
import '../../features/account/model/account_view_model.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../tokens/mapper/account_tokens.dart';
import '../../tokens/mapper/color_tokens.dart';

const _addPayablePillBackground = AccountTokens.projectCardProgressFill;
const _addPayablePillBorder = AppColors.textPrimary;
const _addPayablePillText = SheetColors.actionOn;

/// 改应收单价对话框的结果。
/// - null 结果（弹窗 pop null）表示取消，不写库。
/// - [fen] 为 null 表示清除客户单价（应收回退到应付金额）。
class ExternalCustomerRateResult {
  const ExternalCustomerRateResult(this.fen);

  final int? fen;
}

/// 账户页「外协详情」弹窗内容（presentational）。
///
/// 镜像本地项目详情弹窗：顶部信息卡可改**应收单价**（[onEditCustomerRate]），
/// 中部「应付进度卡」（应付总额=分享人侧已定，已付当前占位 0），底部「支付记录」
/// 占位。应付不可改（边界走核销）。
class ExternalWorkDetailSheet extends StatelessWidget {
  const ExternalWorkDetailSheet({
    super.key,
    required this.project,
    required this.onEditCustomerRate,
  });

  final AccountExternalWorkProjectVM project;
  final VoidCallback onEditCustomerRate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fallbackStyle = DefaultTextStyle.of(context).style;
    final titleStyle = AppTypography.sectionTitle(
      context,
      fontSize: AccountTokens.projectCardTitleFontSize,
      fontWeight: FontWeight.w600,
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
    final mutedStyle = AppTypography.body(
      context,
      fontSize: AccountTokens.projectCardStatusFontSize,
      fontWeight: FontWeight.w400,
      height: 1,
      color: SheetColors.textDim,
    );
    final primaryLabelStyle =
        mutedStyle?.copyWith(color: SheetColors.textPrimary) ??
        fallbackStyle.copyWith(
          fontSize: AccountTokens.projectCardStatusFontSize,
          fontWeight: FontWeight.w400,
          color: SheetColors.textPrimary,
        );
    final amountStyle = AppTypography.body(
      context,
      fontSize: 18,
      fontWeight: FontWeight.w700,
      height: 1,
      color: SheetColors.textPrimary,
    );
    final actionStyle =
        AppTypography.actionText(
          context,
          fontSize: AccountTokens.projectDetailActionSize,
          fontWeight: FontWeight.w400,
          height: 1,
          color: AccountTokens.projectDetailActionColor,
        ) ??
        fallbackStyle.copyWith(
          fontSize: AccountTokens.projectDetailActionSize,
          fontWeight: FontWeight.w400,
          color: AccountTokens.projectDetailActionColor,
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

    final sourceUnitPriceText = project.sourceUnitPriceText;
    final customerRateText =
        _unitPriceText(project.customerUnitPriceFen) ??
        _compactRateText(sourceUnitPriceText) ??
        l10n.accountPendingSetup;
    final payableRateText = sourceUnitPriceText ?? l10n.accountPendingSetup;
    final receivableRateLabel = _rateLabel(l10n, customerRateText);
    final payableLabel = l10n.accountExternalPayableWithSourceRate(
      payableRateText,
    );
    final profitText = FormatUtils.money(project.profit);
    final paidRatio = project.payablePaidRatio;
    final paidPercent = (paidRatio * 100).round();
    final unpaidFen = (project.payableFen - project.paidFen).clamp(
      0,
      project.payableFen,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 4),
        // ============ 顶部信息卡：可改应收单价 ============
        _Card(
          key: const Key('external-detail-summary-card'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      project.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Text(
                    l10n.accountExternalHoursSummary(
                      _hours(project.totalHours),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: rowMetricStyle?.copyWith(color: SheetColors.textDim),
                  ),
                ],
              ),
              const SizedBox(height: AccountTokens.projectCardSectionGap),
              // 应收项目款 + 修改
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            l10n.accountExternalReceivableLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: primaryLabelStyle,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Flexible(
                          child: Text(
                            receivableRateLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: primaryLabelStyle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 48,
                          height: 36,
                          child: TextButton(
                            key: const Key(
                              'external-detail-edit-customer-rate',
                            ),
                            onPressed: onEditCustomerRate,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(48, 36),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor:
                                  AccountTokens.projectDetailActionColor,
                            ),
                            child: Text(
                              l10n.accountEditAction,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                              style: actionStyle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    FormatUtils.money(project.receivable),
                    key: const Key('external-detail-customer-receivable'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    textAlign: TextAlign.right,
                    style: rowMetricStyle,
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.xs),
              Divider(height: 8, color: AppColors.divider),
              const SizedBox(height: AppSpace.sm),
              _Metric(
                label: payableLabel,
                value: FormatUtils.money(project.payable),
                labelStyle: mutedStyle,
                valueStyle: rowMetricStyle,
              ),
              const SizedBox(height: AppSpace.sm),
              _Metric(
                label: l10n.accountGrossProfitLabel,
                value: profitText,
                labelStyle: mutedStyle,
                valueStyle: rowMetricStyle,
              ),
            ],
          ),
        ),
        const SizedBox(height: AccountTokens.projectCardBottomMargin),
        // ============ 应付进度卡（替换收款进度）============
        _Card(
          key: const Key('external-detail-progress-card'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PayableProgressBar(paidRatio: paidRatio),
              const SizedBox(height: AppSpace.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.accountExternalPaidPercent(paidPercent),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: mutedStyle,
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Text(
                      l10n.accountExternalUnpaidAmount(
                        FormatUtils.money(unpaidFen / 100),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      textAlign: TextAlign.right,
                      style: mutedStyle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.xs),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      FormatUtils.money(project.paidFen / 100),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: amountStyle,
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    flex: 2,
                    child: Text(
                      l10n.accountExternalPayableTotalSummary(
                        FormatUtils.money(project.payable),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      textAlign: TextAlign.right,
                      style: mutedStyle,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.md),
        // ============ 支付记录（本轮占位）============
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AccountTokens.projectDetailSectionHorizontalPadding,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.accountExternalPaymentRecordsTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: sectionTitleStyle,
                ),
              ),
              const SizedBox(width: 12),
              _AddPayablePillButton(
                actionStyle: actionStyle,
                label: l10n.accountExternalAddPayableAction,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.xxl),
          child: Center(
            child: Text(l10n.accountExternalPaymentsEmpty, style: emptyStyle),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  static String _hours(double hours) {
    if (hours == hours.roundToDouble()) return hours.toStringAsFixed(0);
    return hours.toStringAsFixed(1);
  }

  static String? _unitPriceText(int? fen) {
    if (fen == null) return null;
    return FormatUtils.money(fen / 100);
  }

  static String? _compactRateText(String? rateText) {
    if (rateText == null) return null;
    return rateText.replaceAll('/h', '');
  }

  static String _rateLabel(AppLocalizations l10n, String rateText) {
    final label = l10n.accountSingleRateLabel;
    if (l10n.localeName.startsWith('zh')) return '$label$rateText';
    return '$label $rateText';
  }
}

class _AddPayablePillButton extends StatelessWidget {
  const _AddPayablePillButton({required this.actionStyle, required this.label});

  final TextStyle actionStyle;
  final String label;

  @override
  Widget build(BuildContext context) {
    final pillStyle = actionStyle.copyWith(
      color: _addPayablePillText,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );

    return InkWell(
      onTap: null,
      borderRadius: BorderRadius.circular(999),
      child: Opacity(
        opacity: 0.46,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _addPayablePillBackground,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _addPayablePillBorder),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: pillStyle,
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
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
        decoration: const BoxDecoration(
          color: SheetColors.background,
          borderRadius: BorderRadius.all(
            Radius.circular(AccountTokens.projectCardRadius),
          ),
          border: Border.fromBorderSide(
            BorderSide(
              color: AccountTokens.projectCardBorderColor,
              width: AccountTokens.projectCardBorderWidth,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Color.fromRGBO(
                0,
                0,
                0,
                AccountTokens.projectCardShadowOpacity,
              ),
              blurRadius: AccountTokens.projectCardShadowBlur,
              offset: Offset(
                AccountTokens.projectCardShadowOffsetX,
                AccountTokens.projectCardShadowOffsetY,
              ),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.labelStyle,
    required this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: labelStyle,
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          textAlign: TextAlign.right,
          style: valueStyle,
        ),
      ],
    );
  }
}

class _PayableProgressBar extends StatelessWidget {
  const _PayableProgressBar({required this.paidRatio});

  final double paidRatio;

  @override
  Widget build(BuildContext context) {
    final ratio = paidRatio.clamp(0.0, 1.0).toDouble();
    return SizedBox(
      height: AccountTokens.projectCardProgressHeight,
      width: double.infinity,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Stack(
          children: [
            Container(
              height: AccountTokens.projectCardProgressFillHeight,
              decoration: BoxDecoration(
                color: AccountTokens.overviewPieRemaining,
                borderRadius: BorderRadius.circular(
                  AccountTokens.projectCardProgressRadius,
                ),
              ),
            ),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
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
    );
  }
}

/// 应收单价录入对话框：输入元，提交按 [Money.fromYuan] 转分。空输入=清除。
class ExternalCustomerRateDialog extends StatefulWidget {
  const ExternalCustomerRateDialog({super.key, this.initialFen});

  final int? initialFen;

  @override
  State<ExternalCustomerRateDialog> createState() =>
      _ExternalCustomerRateDialogState();
}

class _ExternalCustomerRateDialogState
    extends State<ExternalCustomerRateDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialFen;
    _controller = TextEditingController(
      text: initial == null ? '' : (initial / 100).toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final text = _controller.text.trim();
    if (text.isEmpty) {
      // 空输入 = 清除客户单价。
      Navigator.of(context).pop(const ExternalCustomerRateResult(null));
      return;
    }
    final yuan = double.tryParse(text);
    if (yuan == null || yuan < 0) {
      setState(() => _error = l10n.accountExternalCustomerRateInvalid);
      return;
    }
    Navigator.of(
      context,
    ).pop(ExternalCustomerRateResult(Money.fromYuan(yuan).fen));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.accountExternalCustomerRateEditTitle),
      content: TextField(
        key: const Key('external-customer-rate-input'),
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          hintText: l10n.accountExternalCustomerRateInputHint,
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.accountCancelAction),
        ),
        TextButton(
          key: const Key('external-customer-rate-confirm'),
          onPressed: _submit,
          child: Text(l10n.accountConfirmAction),
        ),
      ],
    );
  }
}
