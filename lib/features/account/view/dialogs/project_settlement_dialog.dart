import 'package:flutter/material.dart';

import '../../../../core/foundation/typography.dart';
import '../../../../core/utils/format_utils.dart';
import '../../domain/entities/account_entities.dart';
import '../../domain/services/project_finance_calculator.dart';
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
  late final TextEditingController _reasonController;
  String? _errorMessage;
  bool _saving = false;

  double get _remaining => widget.project.remaining;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    setState(() {
      _saving = false;
      _errorMessage = message;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (ProjectFinanceCalculator.yuanToFen(_remaining) <= 0) {
      _showError('项目已结清，不能重复结清');
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.onSave(
        ProjectSettlementDialogInput(
          paymentAmount: 0,
          writeOffAmount: _remaining,
          writeOffReason: ProjectWriteOffReason.settlement,
          ymd: int.parse(FormatUtils.todayYmd()),
          note: _reasonController.text.trim().isEmpty
              ? null
              : _reasonController.text.trim(),
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
            Row(
              children: [
                Expanded(child: Text('核销金额', style: labelStyle)),
                Text(FormatUtils.money(_remaining), style: valueStyle),
              ],
            ),
            const SizedBox(height: SpaceTokens.sectionGap),
            TextField(
              controller: _reasonController,
              enabled: !_saving,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '核销/减免原因（可填）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: SpaceTokens.sectionGap),
            Text('确认后，这笔待收将作为核销处理，不再计入待收，也不会算作实收。', style: helperStyle),
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
      actionsAlignment: MainAxisAlignment.spaceBetween,
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
              : const Text('确认结清'),
        ),
      ],
    );
  }
}
