import 'package:flutter/material.dart';

import '../../components/fields/app_auto_suggest_field.dart';

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
    return AutoSuggestField(
      controller: controller,
      label: '筛选：供应人',
      hint: '输入关键字即可过滤（可空）',
      suggestionsBuilder: suggestionsBuilder,
      onChanged: onChanged,
      onSelected: onSelected,
    );
  }
}
