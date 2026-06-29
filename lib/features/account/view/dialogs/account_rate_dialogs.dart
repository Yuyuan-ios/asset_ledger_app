import 'package:flutter/material.dart';

import '../../../../core/foundation/typography.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../../patterns/account/account_dialog_shell_pattern.dart';
import '../../../../patterns/account/account_rate_input_dialog_pattern.dart';
import '../../../../patterns/layout/sheet_text_field_pattern.dart';
import '../../../../tokens/mapper/core_tokens.dart';

class AccountBatchRateUpdate {
  final double diggingRate;
  final double breakingRate;

  const AccountBatchRateUpdate({
    required this.diggingRate,
    required this.breakingRate,
  });
}

class AccountRateBatchDialog extends StatefulWidget {
  const AccountRateBatchDialog({
    super.key,
    required this.title,
    required this.deviceCount,
    required this.initialDiggingRateInt,
    required this.initialBreakingRateInt,
  });

  final String title;
  final int deviceCount;
  final int initialDiggingRateInt;
  final int initialBreakingRateInt;

  @override
  State<AccountRateBatchDialog> createState() => _AccountRateBatchDialogState();
}

class _AccountRateBatchDialogState extends State<AccountRateBatchDialog> {
  late final TextEditingController _diggingController;
  late final TextEditingController _breakingController;

  @override
  void initState() {
    super.initState();
    _diggingController = TextEditingController(
      text: widget.initialDiggingRateInt.toString(),
    );
    _breakingController = TextEditingController(
      text: widget.initialBreakingRateInt.toString(),
    );
  }

  @override
  void dispose() {
    _diggingController.dispose();
    _breakingController.dispose();
    super.dispose();
  }

  void _close(AccountBatchRateUpdate? result) {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bodyStyle = AppTypography.body(context, color: AppColors.textPrimary);
    final helperStyle = AppTypography.caption(
      context,
      color: Colors.grey.shade700,
    );

    return AccountDialogShell(
      title: widget.title,
      cancelText: l10n.accountCancelAction,
      confirmText: l10n.accountConfirmAction,
      onCancel: () => _close(null),
      onConfirm: () {
        final diggingInt = int.tryParse(_diggingController.text.trim());
        final breakingInt = int.tryParse(_breakingController.text.trim());
        if (diggingInt == null || diggingInt <= 0) return;
        if (breakingInt == null || breakingInt <= 0) return;
        _close(
          AccountBatchRateUpdate(
            diggingRate: diggingInt.toDouble(),
            breakingRate: breakingInt.toDouble(),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.accountDeviceCountLine(widget.deviceCount),
            style: bodyStyle,
          ),
          const SizedBox(height: 10),
          SheetTextFieldPattern(
            controller: _diggingController,
            labelText: l10n.accountDiggingBatchRateLabel,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          SheetTextFieldPattern(
            controller: _breakingController,
            labelText: l10n.accountBreakingBatchRateLabel,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          Text(l10n.accountBatchRateHelper, style: helperStyle),
        ],
      ),
    );
  }
}

class AccountRateSingleDialog extends StatelessWidget {
  const AccountRateSingleDialog({
    super.key,
    required this.title,
    required this.deviceName,
    required this.initialRateInt,
  });

  final String title;
  final String deviceName;
  final int initialRateInt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AccountRateInputDialog<double>(
      title: title,
      itemLabel: deviceName,
      initialText: initialRateInt.toString(),
      fieldLabel: l10n.accountSingleRateLabel,
      helperText: l10n.accountSingleRateHelper,
      cancelText: l10n.accountCancelAction,
      confirmText: l10n.accountConfirmAction,
      parseResult: (text) {
        final valueInt = int.tryParse(text);
        if (valueInt == null || valueInt <= 0) return null;
        return valueInt.toDouble();
      },
    );
  }
}
