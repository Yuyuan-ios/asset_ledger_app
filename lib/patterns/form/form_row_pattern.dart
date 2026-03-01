import 'package:flutter/material.dart';

class FormRowPattern extends StatelessWidget {
  const FormRowPattern({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(children: children);
  }
}
