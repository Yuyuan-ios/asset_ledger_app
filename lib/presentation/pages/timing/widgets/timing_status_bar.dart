import 'package:flutter/material.dart';

class TimingStatusBar extends StatelessWidget {
  final bool loading;
  final String? error;

  const TimingStatusBar({
    super.key,
    required this.loading,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    // 什么都没有就不占空间
    if (!loading && (error == null || error!.trim().isEmpty)) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        if (loading) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 10),
        ],
        if (error != null && error!.trim().isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              error!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.red),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
