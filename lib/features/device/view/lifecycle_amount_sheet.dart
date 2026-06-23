import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/foundation/typography.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../patterns/layout/bottom_sheet_shell_pattern.dart';
import '../../../tokens/mapper/device_tokens.dart';
import '../domain/services/lifecycle_payback_calculator.dart';

Future<LifecyclePaybackAmounts?> showLifecycleAmountSheet({
  required BuildContext context,
  required String deviceName,
  required int netReceivedFen,
  required int? initialCostFen,
  required int? estimatedResidualFen,
}) {
  return showAppBottomSheet<LifecyclePaybackAmounts>(
    context: context,
    builder: (_) {
      return LifecycleAmountSheet(
        deviceName: deviceName,
        netReceivedFen: netReceivedFen,
        initialCostFen: initialCostFen,
        estimatedResidualFen: estimatedResidualFen,
      );
    },
  );
}

class LifecycleAmountSheet extends StatefulWidget {
  const LifecycleAmountSheet({
    super.key,
    required this.deviceName,
    required this.netReceivedFen,
    required this.initialCostFen,
    required this.estimatedResidualFen,
  });

  final String deviceName;
  final int netReceivedFen;
  final int? initialCostFen;
  final int? estimatedResidualFen;

  @override
  State<LifecycleAmountSheet> createState() => _LifecycleAmountSheetState();
}

class _LifecycleAmountSheetState extends State<LifecycleAmountSheet> {
  late final TextEditingController _initialCostController;
  late final TextEditingController _estimatedResidualController;
  late int? _initialCostFen;
  late int? _estimatedResidualFen;

  @override
  void initState() {
    super.initState();
    _initialCostFen = widget.initialCostFen;
    _estimatedResidualFen = widget.estimatedResidualFen;
    _initialCostController = TextEditingController(
      text: _formatInput(widget.initialCostFen),
    );
    _estimatedResidualController = TextEditingController(
      text: _formatInput(widget.estimatedResidualFen),
    );
  }

  @override
  void dispose() {
    _initialCostController.dispose();
    _estimatedResidualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final result = calculateLifecyclePayback(
      LifecyclePaybackInput(
        initialCostFen: _initialCostFen,
        netReceivedFen: widget.netReceivedFen,
        estimatedResidualFen: _estimatedResidualFen,
      ),
    );

    return AppBottomSheetShell(
      title: l10n.deviceLifecycleAmountSheetTitle,
      scrollable: false,
      cancelText: l10n.deviceCancelAction,
      confirmText: l10n.deviceLifecycleAmountUpdateAction,
      onCancel: () => Navigator.of(context).pop(),
      onConfirm: () {
        Navigator.of(context).pop(
          LifecyclePaybackAmounts(
            initialCostFen: _initialCostFen,
            estimatedResidualFen: _estimatedResidualFen,
          ),
        );
      },
      backgroundColor: LifecyclePaybackTokens.sheetBackground,
      handleColor: LifecyclePaybackTokens.sheetHandle,
      contentPadding: EdgeInsets.zero,
      child: Column(
        children: [
          Expanded(
            child: _LifecycleAmountCardSection(
              children: [
                _InputGroup(
                  initialCostController: _initialCostController,
                  estimatedResidualController: _estimatedResidualController,
                  onInitialCostChanged: (value) {
                    setState(() => _initialCostFen = _parseInputFen(value));
                  },
                  onEstimatedResidualChanged: (value) {
                    setState(() {
                      _estimatedResidualFen = _parseInputFen(value);
                    });
                  },
                ),
                _PreviewCard(
                  result: result,
                  netReceivedFen: widget.netReceivedFen,
                  initialCostFen: _initialCostFen,
                  estimatedResidualFen: _estimatedResidualFen,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatInput(int? amountFen) {
    if (amountFen == null || amountFen <= 0) return '';
    final yuan = amountFen / 100;
    return _formatNumber(yuan);
  }
}

class _LifecycleAmountCardSection extends StatelessWidget {
  const _LifecycleAmountCardSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        LifecyclePaybackTokens.sheetContentHorizontalPadding,
        0,
        LifecyclePaybackTokens.sheetContentHorizontalPadding,
        LifecyclePaybackTokens.sheetContentBottomPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0)
              const SizedBox(height: LifecyclePaybackTokens.sheetCardGap),
            children[index],
          ],
        ],
      ),
    );
  }
}

class _LifecycleAmountCard extends StatelessWidget {
  const _LifecycleAmountCard({
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: LifecyclePaybackTokens.sheetSurface,
        borderRadius: BorderRadius.circular(
          LifecyclePaybackTokens.sheetCardRadius,
        ),
      ),
      child: child,
    );
  }
}

class _InputGroup extends StatelessWidget {
  const _InputGroup({
    required this.initialCostController,
    required this.estimatedResidualController,
    required this.onInitialCostChanged,
    required this.onEstimatedResidualChanged,
  });

  final TextEditingController initialCostController;
  final TextEditingController estimatedResidualController;
  final ValueChanged<String> onInitialCostChanged;
  final ValueChanged<String> onEstimatedResidualChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _LifecycleAmountCard(
      child: Column(
        children: [
          _MoneyInputRow(
            label: l10n.deviceLifecycleInitialCostLabel,
            controller: initialCostController,
            onChanged: onInitialCostChanged,
          ),
          const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: LifecyclePaybackTokens.sheetDivider,
            ),
          ),
          _MoneyInputRow(
            label: l10n.deviceLifecycleEstimatedResidualInputLabel,
            controller: estimatedResidualController,
            onChanged: onEstimatedResidualChanged,
          ),
        ],
      ),
    );
  }
}

class _MoneyInputRow extends StatelessWidget {
  const _MoneyInputRow({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: AppTypography.body(
                context,
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: LifecyclePaybackTokens.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 150,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: const [_ThousandsMoneyInputFormatter()],
              onChanged: onChanged,
              decoration: const InputDecoration(
                border: InputBorder.none,
                prefixText: '¥ ',
                hintText: '0',
                isDense: true,
              ),
              style: AppTypography.body(
                context,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: LifecyclePaybackTokens.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.result,
    required this.netReceivedFen,
    required this.initialCostFen,
    required this.estimatedResidualFen,
  });

  final LifecyclePaybackResult result;
  final int netReceivedFen;
  final int? initialCostFen;
  final int? estimatedResidualFen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isProfit = result.lifeCycleProfitFen > 0;
    final title = result.isCostUnset
        ? l10n.deviceLifecycleProjectedSurplusTitle
        : isProfit
        ? l10n.deviceLifecycleProjectedSurplusTitle
        : result.lifeCycleProfitFen < 0
        ? l10n.deviceLifecyclePaybackRemainingTitle
        : l10n.deviceLifecycleProjectedSurplusTitle;
    final value = result.isCostUnset
        ? '¥0'
        : isProfit
        ? formatLifecycleMoneyFen(result.lifeCycleProfitFen, explicitPlus: true)
        : result.lifeCycleProfitFen < 0
        ? formatLifecycleMoneyFen(result.lifeCycleProfitFen.abs())
        : '¥0';
    final valueColor = result.isCostUnset
        ? LifecyclePaybackTokens.textSecondary
        : isProfit
        ? LifecyclePaybackTokens.surplus
        : result.lifeCycleProfitFen < 0
        ? LifecyclePaybackTokens.textBody
        : LifecyclePaybackTokens.textPrimary;

    return _LifecycleAmountCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.caption(
              context,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: LifecyclePaybackTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.pageTitle(
              context,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 14),
          _FormulaRow(
            label: l10n.deviceLifecycleNetReceivedLabel,
            value: formatLifecycleMoneyFen(netReceivedFen),
          ),
          _FormulaRow(
            label: l10n.deviceLifecycleEstimatedResidualFormulaLabel,
            value: formatLifecycleMoneyFen(estimatedResidualFen ?? 0),
          ),
          _FormulaRow(
            label: l10n.deviceLifecycleInitialCostFormulaLabel,
            value: formatLifecycleMoneyFen(initialCostFen ?? 0),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: LifecyclePaybackTokens.sheetDivider,
            ),
          ),
          _FormulaRow(
            label: l10n.deviceLifecycleNetProfitFormulaLabel,
            value: formatLifecycleMoneyFen(
              result.lifeCycleProfitFen,
              explicitPlus: result.lifeCycleProfitFen > 0,
            ),
            strong: true,
            valueColor: valueColor,
          ),
        ],
      ),
    );
  }
}

class _FormulaRow extends StatelessWidget {
  const _FormulaRow({
    required this.label,
    required this.value,
    this.strong = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool strong;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.caption(
                context,
                fontSize: 13,
                fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
                color: strong
                    ? LifecyclePaybackTokens.textPrimary
                    : LifecyclePaybackTokens.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: AppTypography.caption(
              context,
              fontSize: 13,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
              color: valueColor ?? LifecyclePaybackTokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThousandsMoneyInputFormatter extends TextInputFormatter {
  const _ThousandsMoneyInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = _cleanNumber(newValue.text);
    if (raw.isEmpty) return const TextEditingValue();
    final formatted = _formatNumberString(raw);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

int? _parseInputFen(String value) {
  final cleaned = _cleanNumber(value);
  if (cleaned.isEmpty) return null;
  final parsed = double.tryParse(cleaned);
  if (parsed == null || parsed <= 0) return null;
  return (parsed * 100).round();
}

String _cleanNumber(String value) {
  final buffer = StringBuffer();
  var hasDot = false;
  for (final unit in value.codeUnits) {
    final char = String.fromCharCode(unit);
    if (char == '.' && !hasDot) {
      buffer.write(char);
      hasDot = true;
      continue;
    }
    if (unit >= 48 && unit <= 57) buffer.write(char);
  }
  return buffer.toString();
}

String _formatNumber(num value) {
  final asDouble = value.toDouble();
  if (asDouble == asDouble.roundToDouble()) {
    return _formatNumberString(asDouble.toStringAsFixed(0));
  }
  return _formatNumberString(asDouble.toStringAsFixed(2));
}

String _formatNumberString(String raw) {
  final parts = raw.split('.');
  final integerPart = parts.first.isEmpty ? '0' : parts.first;
  final decimalPart = parts.length > 1 ? parts[1] : null;
  final grouped = _groupThousands(integerPart);
  if (decimalPart == null) return grouped;
  return '$grouped.$decimalPart';
}

String _groupThousands(String source) {
  final trimmed = source.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  final buffer = StringBuffer();
  for (var i = 0; i < trimmed.length; i++) {
    if (i > 0 && (trimmed.length - i) % 3 == 0) buffer.write(',');
    buffer.write(trimmed[i]);
  }
  return buffer.toString();
}
