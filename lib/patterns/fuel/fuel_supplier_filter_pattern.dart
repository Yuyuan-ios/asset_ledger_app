import 'package:flutter/material.dart';

import '../../core/foundation/typography.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/sheet_tokens.dart';

const double _fuelSupplierFilterRadius = 8;

class FuelSupplierFilter extends StatefulWidget {
  final TextEditingController controller;
  final List<String> Function(String query) suggestionsBuilder;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSelected;

  const FuelSupplierFilter({
    super.key,
    required this.controller,
    required this.suggestionsBuilder,
    required this.onChanged,
    required this.onSelected,
  });

  @override
  State<FuelSupplierFilter> createState() => _FuelSupplierFilterState();
}

class _FuelSupplierFilterState extends State<FuelSupplierFilter> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textStyle = AppTypography.body(
      context,
      fontSize: SheetTokens.fieldTextSize,
      color: SheetColors.textPrimary,
    );
    final hintStyle = AppTypography.bodySecondary(
      context,
      fontSize: SheetTokens.fieldTextSize,
      color: SheetColors.textPrimary,
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(_fuelSupplierFilterRadius),
      borderSide: const BorderSide(
        color: SheetColors.fieldBorder,
        width: SheetTokens.fieldBorderWidth,
      ),
    );

    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (value) {
        return widget.suggestionsBuilder(value.text.trim());
      },
      displayStringForOption: (s) => s,
      onSelected: (value) {
        widget.onSelected(value);
        widget.onChanged(value);
      },
      fieldViewBuilder: (context, textEditingController, focusNode, _) {
        return TextField(
          controller: textEditingController,
          focusNode: focusNode,
          onChanged: widget.onChanged,
          style: textStyle,
          decoration: InputDecoration(
            hintText: l10n.fuelSupplierFilterLabel,
            hintStyle: hintStyle,
            filled: false,
            constraints: const BoxConstraints(
              minHeight: SheetTokens.fieldHeight,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: SheetTokens.fieldContentHPadding,
              vertical: SheetTokens.fieldContentVPadding,
            ),
            suffixIcon: const Padding(
              padding: EdgeInsets.only(
                right: SheetTokens.fieldSuffixRightPadding,
              ),
              child: Icon(Icons.arrow_drop_down, color: SheetColors.muted),
            ),
            border: border,
            enabledBorder: border,
            focusedBorder: border,
            disabledBorder: border,
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        if (options.isEmpty) return const SizedBox.shrink();

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: SheetTokens.suggestMenuElevation,
            borderRadius: BorderRadius.circular(SheetTokens.suggestMenuRadius),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: SheetTokens.suggestMenuMaxHeight,
                minWidth: SheetTokens.suggestMenuMinWidth,
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final opt = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(opt),
                    onTap: () => onSelected(opt),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
