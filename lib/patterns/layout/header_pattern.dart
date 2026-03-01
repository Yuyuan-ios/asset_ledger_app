import 'package:flutter/material.dart';

class HeaderPattern extends StatelessWidget {
  const HeaderPattern({
    super.key,
    required this.title,
    this.trailing,
  });

  final Widget title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [title, trailing ?? const SizedBox.shrink()],
    );
  }
}
