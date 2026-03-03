String formValidationMessage(
  String message, {
  String action = '保存',
}) {
  final trimmed = message.trim();
  if (trimmed.isEmpty) {
    return '$action失败：请检查输入内容';
  }
  if (_isAlreadyPrefixed(trimmed)) {
    return trimmed;
  }
  return '$action失败：$trimmed';
}

bool _isAlreadyPrefixed(String message) {
  return RegExp(r'^\S+失败：').hasMatch(message);
}
