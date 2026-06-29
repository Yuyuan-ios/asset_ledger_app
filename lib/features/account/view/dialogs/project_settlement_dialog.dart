import 'package:flutter/material.dart';

import '../../../../core/foundation/typography.dart';
import '../../../../core/utils/format_utils.dart';
import '../../domain/entities/account_entities.dart';
import '../../domain/services/project_finance_calculator.dart';
import '../../../../features/account/model/account_view_model.dart';
import '../../../../features/account/use_cases/project_settlement_use_case.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../../patterns/account/account_dialog_shell_pattern.dart';
import '../../../../patterns/layout/sheet_text_field_pattern.dart';
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
    final l10n = AppLocalizations.of(context);
    if (ProjectFinanceCalculator.yuanToFen(_remaining) <= 0) {
      _showError(l10n.accountSettlementAlreadySettled);
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
    final l10n = AppLocalizations.of(context);
    if (error is StateError) return error.message;
    if (error is ArgumentError) {
      return error.message?.toString() ?? l10n.accountInputInvalid;
    }
    return l10n.accountSaveFailureGeneric;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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

    return AccountDialogShell(
      title: l10n.accountSettlementDialogTitle,
      cancelText: l10n.accountCancelAction,
      confirmText: l10n.accountConfirmSettlementAction,
      onCancel: _saving ? null : () => Navigator.of(context).pop(),
      onConfirm: _saving ? null : _save,
      confirmChild: _saving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      scrollable: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l10n.accountWriteOffAmountLabel, style: labelStyle),
              ),
              Text(FormatUtils.money(_remaining), style: valueStyle),
            ],
          ),
          const SizedBox(height: SpaceTokens.sectionGap),
          SheetTextFieldPattern(
            controller: _reasonController,
            enabled: !_saving,
            labelText: l10n.accountWriteOffReasonLabel,
            maxLines: 2,
          ),
          const SizedBox(height: SpaceTokens.sectionGap),
          Text(l10n.accountSettlementHelper, style: helperStyle),
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
    );
  }
}
