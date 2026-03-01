import 'package:flutter/material.dart';

class AppListItem extends StatelessWidget {
  const AppListItem({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(title: title, subtitle: subtitle, trailing: trailing);
  }
}
