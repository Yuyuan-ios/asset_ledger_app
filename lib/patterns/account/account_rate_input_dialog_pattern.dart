import 'package:flutter/material.dart';

import '../../core/foundation/typography.dart';
import '../../tokens/mapper/core_tokens.dart';
import 'account_dialog_shell_pattern.dart';
import '../layout/sheet_text_field_pattern.dart';

class AccountRateInputDialog<T extends Object> extends StatefulWidget {
  const AccountRateInputDialog({
    super.key,
    required this.title,
    required this.itemLabel,
    required this.initialText,
    required this.fieldLabel,
    required this.helperText,
    required this.cancelText,
    required this.confirmText,
    required this.parseResult,
    this.invalidText,
    this.inputKey,
    this.confirmKey,
    this.keyboardType = TextInputType.number,
    this.autofocus = false,
  });

  final String title;
  final String itemLabel;
  final String initialText;
  final String fieldLabel;
  final String helperText;
  final String cancelText;
  final String confirmText;
  final T? Function(String text) parseResult;
  final String? invalidText;
  final Key? inputKey;
  final Key? confirmKey;
  final TextInputType keyboardType;
  final bool autofocus;

  @override
  State<AccountRateInputDialog<T>> createState() =>
      _AccountRateInputDialogState<T>();
}

class _AccountRateInputDialogState<T extends Object>
    extends State<AccountRateInputDialog<T>> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close(T? result) {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(result);
  }

  void _submit() {
    final result = widget.parseResult(_controller.text.trim());
    if (result == null) {
      final invalidText = widget.invalidText;
      if (invalidText != null) {
        setState(() => _error = invalidText);
      }
      return;
    }
    _close(result);
  }

  @override
  Widget build(BuildContext context) {
    final bodyStyle = AppTypography.body(context, color: AppColors.textPrimary);
    final helperStyle = AppTypography.caption(
      context,
      color: Colors.grey.shade700,
    );

    return AccountDialogShell(
      title: widget.title,
      cancelText: widget.cancelText,
      confirmText: widget.confirmText,
      onCancel: () => _close(null),
      onConfirm: _submit,
      confirmKey: widget.confirmKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.itemLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: bodyStyle,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 140,
                child: SheetTextFieldPattern(
                  key: widget.inputKey,
                  controller: _controller,
                  autofocus: widget.autofocus,
                  labelText: widget.fieldLabel,
                  keyboardType: widget.keyboardType,
                  errorText: _error,
                  onSubmitted: (_) => _submit(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(widget.helperText, style: helperStyle),
        ],
      ),
    );
  }
}
