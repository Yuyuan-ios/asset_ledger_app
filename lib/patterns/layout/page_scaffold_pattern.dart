import 'package:flutter/material.dart';

class PageScaffoldPattern extends StatelessWidget {
  const PageScaffoldPattern({
    super.key,
    required this.body,
    this.backgroundColor,
  });

  final Widget body;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: backgroundColor, body: body);
  }
}
