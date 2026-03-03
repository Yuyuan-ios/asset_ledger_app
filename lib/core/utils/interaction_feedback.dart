String missingEntityMessage(
  String entity, {
  int? id,
  String? suffix,
}) {
  final buffer = StringBuffer(entity);
  if (id != null) {
    buffer.write('不存在（id=$id）');
  } else {
    buffer.write('不存在');
  }
  if (suffix != null && suffix.trim().isNotEmpty) {
    buffer.write('，${suffix.trim()}');
  }
  return buffer.toString();
}

String inactiveEntityCreateMessage(
  String entity, {
  String? recordLabel,
}) {
  final suffix = recordLabel == null || recordLabel.trim().isEmpty
      ? ''
      : recordLabel.trim();
  return '$entity已停用，不能用于新建$suffix';
}

String filterStatusMessage({
  required bool cleared,
  required bool hasActiveFilter,
}) {
  if (cleared) return '已清空筛选';
  return hasActiveFilter ? '已筛选' : '未筛选';
}

String noEditableDevicesMessage() => '该项目暂无设备可修改';

String autoCorrectedMessage(String message) => message;
