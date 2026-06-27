import 'package:flutter/material.dart';

import '../../../../core/foundation/typography.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../../patterns/layout/sheet_text_field_pattern.dart';
import '../../../../tokens/mapper/account_tokens.dart';
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
    final titleStyle = AppTypography.sectionTitle(
      context,
      fontSize: AccountTokens.projectDetailSectionTitleSize,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    );
    final bodyStyle = AppTypography.body(context, color: AppColors.textPrimary);
    final helperStyle = AppTypography.caption(
      context,
      color: Colors.grey.shade700,
    );

    return AlertDialog(
      title: Text(widget.title, style: titleStyle),
      content: Column(
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
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => _close(null),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.brand.withValues(alpha: 0.8),
          ),
          child: Text(l10n.accountCancelAction),
        ),
        FilledButton(
          onPressed: () {
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
          child: Text(l10n.accountConfirmAction),
        ),
      ],
    );
  }
}

class AccountRateSingleDialog extends StatefulWidget {
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
  State<AccountRateSingleDialog> createState() =>
      _AccountRateSingleDialogState();
}

class _AccountRateSingleDialogState extends State<AccountRateSingleDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialRateInt.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close(double? result) {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final titleStyle = AppTypography.sectionTitle(
      context,
      fontSize: AccountTokens.projectDetailSectionTitleSize,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    );
    final bodyStyle = AppTypography.body(context, color: AppColors.textPrimary);
    final helperStyle = AppTypography.caption(
      context,
      color: Colors.grey.shade700,
    );

    return AlertDialog(
      title: Text(widget.title, style: titleStyle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.deviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: bodyStyle,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 140,
                child: SheetTextFieldPattern(
                  controller: _controller,
                  labelText: l10n.accountSingleRateLabel,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(l10n.accountSingleRateHelper, style: helperStyle),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => _close(null),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.brand.withValues(alpha: 0.8),
          ),
          child: Text(l10n.accountCancelAction),
        ),
        FilledButton(
          onPressed: () {
            final valueInt = int.tryParse(_controller.text.trim());
            if (valueInt == null || valueInt <= 0) return;
            _close(valueInt.toDouble());
          },
          child: Text(l10n.accountConfirmAction),
        ),
      ],
    );
  }
}
