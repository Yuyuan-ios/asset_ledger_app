import 'package:flutter/material.dart';

import '../../core/money/amount_policy.dart';
import '../../core/utils/format_utils.dart';
import '../../features/account/model/account_view_model.dart';
import '../../l10n/gen/app_localizations.dart';

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
    final theme = Theme.of(context);
    final hasCustomer = project.hasCustomerUnitPrice;
    final muted = Colors.black.withValues(alpha: 0.55);

    final customerRateText = hasCustomer
        ? FormatUtils.money(project.customerUnitPriceFen! / 100)
        : l10n.accountPendingSetup;
    final profitText = hasCustomer
        ? FormatUtils.money(project.profit)
        : l10n.accountPendingCalculation;
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
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    l10n.accountExternalHoursSummary(
                      _hours(project.totalHours),
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // 应收单价 + 修改
              Row(
                children: [
                  Flexible(
                    child: Text(
                      l10n.accountExternalCustomerRateLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    customerRateText,
                    key: const Key('external-detail-customer-rate'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    key: const Key('external-detail-edit-customer-rate'),
                    onPressed: onEditCustomerRate,
                    child: Text(l10n.accountEditAction),
                  ),
                ],
              ),
              const Divider(height: 8),
              const SizedBox(height: 6),
              _Metric(
                label: l10n.accountExternalReceivableLabel,
                value: FormatUtils.money(project.receivable),
              ),
              const SizedBox(height: 8),
              _Metric(label: l10n.accountGrossProfitLabel, value: profitText),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // ============ 应付进度卡（替换收款进度）============
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PayableProgressBar(paidRatio: paidRatio),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    l10n.accountExternalPaidPercent(paidPercent),
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                  const Spacer(),
                  Text(
                    l10n.accountExternalUnpaidAmount(
                      FormatUtils.money(unpaidFen / 100),
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    FormatUtils.money(project.paidFen / 100),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    l10n.accountExternalPayableTotalSummary(
                      FormatUtils.money(project.payable),
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // ============ 支付记录（本轮占位）============
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      l10n.accountExternalPaymentRecordsTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: null,
                    child: Text(l10n.accountExternalAddPayableAction),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    l10n.accountExternalPaymentsEmpty,
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                ),
              ),
            ],
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
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.black.withValues(alpha: 0.55),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
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
    final radius = BorderRadius.circular(4);
    return SizedBox(
      height: 8,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE74C3C),
              borderRadius: radius,
            ),
          ),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: ratio,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF27AE60),
                borderRadius: radius,
              ),
            ),
          ),
        ],
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
