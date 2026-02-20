import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  final VoidCallback? onAdd;

  const SectionHeader({super.key, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '计时',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.black,
              height: 1.2,
            ),
          ),
          SizedBox(
            height: 38,
            child: FilledButton(
              onPressed: onAdd,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE67E22),
                foregroundColor: const Color(0xFFF8F8F8),
                elevation: 0,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                textStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              child: const Text('+ 新建'),
            ),
          ),
        ],
      ),
    );
  }
}
