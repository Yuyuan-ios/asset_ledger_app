import 'package:flutter/material.dart';

import '../../../../core/foundation/typography.dart';
import '../../../../core/utils/form_feedback.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/utils/text_field_utils.dart';
import '../../../../data/models/account_payment.dart';
import '../../../../data/services/account_service.dart';
import '../../../../features/account/model/account_view_model.dart';
import '../../../../tokens/mapper/core_tokens.dart';
import '../../../../tokens/mapper/account_tokens.dart';

class AccountPaymentEditorDialog extends StatefulWidget {
  const AccountPaymentEditorDialog({
    super.key,
    required this.project,
    required this.allPayments,
    this.editing,
  });

  final AccountProjectVM project;
  final List<AccountPayment> allPayments;
  final AccountPayment? editing;

  @override
  State<AccountPaymentEditorDialog> createState() =>
      _AccountPaymentEditorDialogState();
}

class _AccountPaymentEditorDialogState
    extends State<AccountPaymentEditorDialog> {
  late final TextEditingController _dateController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    _dateController = TextEditingController(
      text: editing == null
          ? FormatUtils.todayDisplayDate()
          : FormatUtils.date(editing.ymd),
    );
    _amountController = TextEditingController(
      text: editing == null ? '' : editing.amount.round().toString(),
    );
    _noteController = TextEditingController(text: editing?.note ?? '');
  }

  @override
  void dispose() {
    _dateController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
    });
  }

  double get _receivable => widget.project.receivable;

  double _received({int? excludePaymentId}) {
    return AccountService.sumReceivedByProject(
      projectKey: widget.project.projectKey,
      payments: widget.allPayments,
      excludePaymentId: excludePaymentId,
    );
  }

  void _close(AccountPayment? result) {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final editing = widget.editing;
    final titleStyle = AppTypography.sectionTitle(
      context,
      fontSize: AccountTokens.projectDetailSectionTitleSize,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    );
    final labelStyle = AppTypography.body(
      context,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
    );
    final helperStyle = AppTypography.caption(
      context,
      color: Colors.grey.shade700,
    );

    return AlertDialog(
      title: Text(editing == null ? '新增收款' : '编辑收款', style: titleStyle),
      content: SingleChildScrollView(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text('项目：${project.displayName}', style: labelStyle),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _dateController,
              keyboardType: TextInputType.number,
              onTap: () => selectAllIfZeroLike(_dateController),
              decoration: InputDecoration(
                labelText: FormatUtils.ymdInputLabel,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: SpaceTokens.sectionGap),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              onTap: () => selectAllIfZeroLike(_amountController),
              decoration: const InputDecoration(
                labelText: '金额（整数）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: SpaceTokens.sectionGap),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: '备注（可填）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '应收：${FormatUtils.money(_receivable)}'
                '，已收：${FormatUtils.money(_received(excludePaymentId: editing?.id))}',
                style: helperStyle,
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _errorMessage!,
                  style: AppTypography.caption(
                    context,
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _close(null),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.brand.withValues(alpha: 0.8),
          ),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            if (editing != null && editing.projectKey != project.projectKey) {
              _showError(formValidationMessage('编辑记录不属于当前项目'));
              return;
            }

            final ymd = FormatUtils.parseDate(_dateController.text);
            if (ymd == null) {
              _showError(formValidationMessage(FormatUtils.ymdInvalidMsg));
              return;
            }

            final amountInt = int.tryParse(_amountController.text.trim());
            if (amountInt == null || amountInt <= 0) {
              _showError(formValidationMessage('金额必须是 > 0 的整数'));
              return;
            }
            final amount = amountInt.toDouble();

            final receivedExcluding = _received(excludePaymentId: editing?.id);
            final after = receivedExcluding + amount;

            const eps = 0.05;
            if (after > _receivable + eps) {
              final remain = _receivable - receivedExcluding;
              _showError(
                formValidationMessage(
                  '超出剩余应收（剩余约 ${FormatUtils.money(remain)}）',
                ),
              );
              return;
            }

            if (_errorMessage != null) {
              setState(() {
                _errorMessage = null;
              });
            }

            _close(
              AccountPayment(
                id: editing?.id,
                projectKey: project.projectKey,
                ymd: ymd,
                amount: amount,
                note: _noteController.text.trim().isEmpty
                    ? null
                    : _noteController.text.trim(),
              ),
            );
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}
