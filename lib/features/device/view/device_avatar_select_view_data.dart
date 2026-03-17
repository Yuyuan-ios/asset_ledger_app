import '../../../data/models/device.dart';
import '../model/brand_catalog.dart';

/// 设备头像选择页的轻量视图数据：
/// - 由页面层按当前类别计算分组数据
/// - 供 Pattern 直接渲染，避免 Pattern 内部持有筛选逻辑
class DeviceAvatarSelectViewData {
  final EquipmentType selectedType;
  final Map<BrandCountry, List<BrandItem>> groups;

  const DeviceAvatarSelectViewData({
    required this.selectedType,
    required this.groups,
  });

  bool get isEmpty => groups.values.every((items) => items.isEmpty);

  factory DeviceAvatarSelectViewData.fromSelectedType(
    EquipmentType selectedType,
  ) {
    return DeviceAvatarSelectViewData(
      selectedType: selectedType,
      groups: BrandCatalog.groups(equipmentType: selectedType),
    );
  }
}
