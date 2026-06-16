import 'package:flutter/material.dart';

import '../../components/fields/app_auto_suggest_field.dart';
import '../../l10n/gen/app_localizations.dart';

class FuelSupplierFilter extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AutoSuggestField(
      controller: controller,
      label: l10n.fuelSupplierFilterLabel,
      hint: l10n.fuelSupplierFilterHint,
      suggestionsBuilder: suggestionsBuilder,
      onChanged: onChanged,
      onSelected: onSelected,
    );
  }
}
