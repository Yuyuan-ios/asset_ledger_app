import 'package:flutter/material.dart';

class RecordsTitle extends StatelessWidget {
  final int count;
  const RecordsTitle({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Text(
      '最近记录($count)',
      style: const TextStyle(
        fontSize: 36 / 2,
        fontWeight: FontWeight.w400,
        color: Colors.black,
        height: 1,
      ),
    );
  }
}
