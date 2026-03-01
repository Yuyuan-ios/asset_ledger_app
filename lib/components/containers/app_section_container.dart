import 'package:flutter/material.dart';

class AppSectionContainer extends StatelessWidget {
  const AppSectionContainer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(child: child);
  }
}
