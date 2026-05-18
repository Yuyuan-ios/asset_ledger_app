import 'package:flutter/material.dart';

import '../../../../core/foundation/typography.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/utils/text_field_utils.dart';
import '../../../../data/models/project_write_off.dart';
import '../../../../features/account/model/account_view_model.dart';
import '../../../../features/account/use_cases/project_settlement_use_case.dart';
import '../../../../tokens/mapper/account_tokens.dart';
import '../../../../tokens/mapper/core_tokens.dart';

class ProjectSettlementDialogInput {
  const ProjectSettlementDialogInput({
    required this.paymentAmount,
    required this.writeOffAmount,
    required this.writeOffReason,
    required this.ymd,
    this.note,
  });

  final double paymentAmount;
  final double writeOffAmount;
  final ProjectWriteOffReason? writeOffReason;
  final int ymd;
  final String? note;
}

class ProjectSettlementDialog extends StatefulWidget {
  const ProjectSettlementDialog({
    super.key,
    required this.project,
    required this.onSave,
  });

  final AccountProjectVM project;
  final Future<ProjectSettlementResult> Function(
    ProjectSettlementDialogInput input,
  )
  onSave;

  @override
  State<ProjectSettlementDialog> createState() =>
      _ProjectSettlementDialogState();
}

class _ProjectSettlementDialogState extends State<ProjectSettlementDialog> {
  late final TextEditingController _paymentController;
  late final TextEditingController _noteController;
  ProjectWriteOffReason? _reason;
  String? _errorMessage;
  bool _saving = false;

  double get _remaining => widget.project.remaining;

  double get _paymentAmount {
    final raw = _paymentController.text.trim();
    if (raw.isEmpty) return 0.0;
    return double.tryParse(raw) ?? double.nan;
  }

  double get _writeOffAmount {
    final payment = _paymentAmount;
    if (payment.isNaN) return double.nan;
    final value = _remaining - payment;
    return value.abs() <= projectSettlementEpsilon ? 0.0 : value;
  }

  bool get _requiresReason {
    final amount = _writeOffAmount;
    return !amount.isNaN && amount > projectSettlementEpsilon;
  }

  @override
  void initState() {
    super.initState();
    _paymentController = TextEditingController(
      text: widget.project.remaining.round().toString(),
    )..addListener(_onPaymentChanged);
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _paymentController.removeListener(_onPaymentChanged);
    _paymentController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onPaymentChanged() {
    if (!mounted) return;
    setState(() {
      _errorMessage = null;
    });
  }

  void _showError(String message) {
    setState(() {
      _saving = false;
      _errorMessage = message;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final payment = _paymentAmount;
    if (payment.isNaN) {
      _showError('本次实收金额格式不正确');
      return;
    }
    if (payment < -projectSettlementEpsilon) {
      _showError('本次实收不能为负数');
      return;
    }
    if (payment > _remaining + projectSettlementEpsilon) {
      _showError('本次实收不能超过当前待收');
      return;
    }

    final writeOff = _writeOffAmount;
    if (writeOff.isNaN || writeOff < -projectSettlementEpsilon) {
      _showError('核销金额不能为负数');
      return;
    }
    if (writeOff > projectSettlementEpsilon && _reason == null) {
      _showError('请选择核销原因');
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.onSave(
        ProjectSettlementDialogInput(
          paymentAmount: payment,
          writeOffAmount: writeOff,
          writeOffReason: writeOff > projectSettlementEpsilon ? _reason : null,
          ymd: int.parse(FormatUtils.todayYmd()),
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        ),
      );
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) return;
      _showError(_friendlyError(error));
    }
  }

  String _friendlyError(Object error) {
    if (error is StateError) return error.message;
    if (error is ArgumentError) {
      return error.message?.toString() ?? '输入不合法';
    }
    return '保存失败，请稍后重试';
  }

  @override
  Widget build(BuildContext context) {
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
    final valueStyle = AppTypography.body(
      context,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    );
    final helperStyle = AppTypography.caption(
      context,
      color: Colors.grey.shade700,
    );

    return AlertDialog(
      title: Text('结清项目', style: titleStyle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.project.displayName, style: labelStyle),
            const SizedBox(height: SpaceTokens.sectionGap),
            _buildMoneyRow('项目总额', widget.project.receivable, valueStyle),
            _buildMoneyRow('已收金额', widget.project.received, valueStyle),
            _buildMoneyRow('已核销金额', widget.project.writeOff, valueStyle),
            _buildMoneyRow('当前待收', _remaining, valueStyle),
            const SizedBox(height: SpaceTokens.sectionGap),
            TextField(
              controller: _paymentController,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onTap: () => selectAllIfZeroLike(_paymentController),
              decoration: const InputDecoration(
                labelText: '本次实收金额',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: SpaceTokens.sectionGap),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: '核销金额',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              child: Text(
                _writeOffAmount.isNaN
                    ? '金额格式不正确'
                    : FormatUtils.money(
                        _writeOffAmount.clamp(0.0, _remaining).toDouble(),
                      ),
                style: valueStyle,
              ),
            ),
            const SizedBox(height: SpaceTokens.sectionGap),
            DropdownButtonFormField<ProjectWriteOffReason>(
              initialValue: _reason,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '核销原因',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final reason in ProjectWriteOffReason.values)
                  DropdownMenuItem(
                    value: reason,
                    child: Text(_reasonLabel(reason)),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (value) {
                      setState(() {
                        _reason = value;
                        _errorMessage = null;
                      });
                    },
            ),
            if (_requiresReason) ...[
              const SizedBox(height: 6),
              Text('核销金额大于 0 时必须选择原因', style: helperStyle),
            ],
            const SizedBox(height: SpaceTokens.sectionGap),
            TextField(
              controller: _noteController,
              enabled: !_saving,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '备注（可填）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (_writeOffAmount > 1000) ...[
              const SizedBox(height: 6),
              Text('核销金额较大，建议填写备注', style: helperStyle),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: AppTypography.caption(
                  context,
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.brand.withValues(alpha: 0.8),
          ),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存结清'),
        ),
      ],
    );
  }

  Widget _buildMoneyRow(String label, double amount, TextStyle? valueStyle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(FormatUtils.money(amount), style: valueStyle),
        ],
      ),
    );
  }

  String _reasonLabel(ProjectWriteOffReason reason) {
    switch (reason) {
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
}
