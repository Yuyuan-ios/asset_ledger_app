import 'package:flutter/material.dart';

class DeviceEditorActionsPattern {
  const DeviceEditorActionsPattern._();

  static List<Widget> build({
    required bool saving,
    required VoidCallback onCancel,
    required VoidCallback onConfirm,
  }) {
    return [
      TextButton(onPressed: saving ? null : onCancel, child: const Text('取消')),
      FilledButton(
        onPressed: saving ? null : onConfirm,
        child: const Text('确定'),
      ),
    ];
  }
}
