import '../model/brand_catalog.dart';
import '../model/device_type_catalog.dart';

/// 设备头像选择页的轻量视图数据：
/// - 由页面层按当前设备类型 + 搜索词计算品牌分组
/// - 供 Pattern 直接渲染，避免 Pattern 内部持有筛选逻辑
class DeviceAvatarSelectViewData {
  final DeviceTypeDef selectedType;
  final Map<BrandCountry, List<BrandItem>> groups;

  const DeviceAvatarSelectViewData({
    required this.selectedType,
    required this.groups,
  });

  /// 过滤后是否还有可展示的品牌（用于切换到空态/兜底）。
  bool get hasAnyBrand => groups.values.any((items) => items.isNotEmpty);

  /// 该设备类型在品牌库里是否本就维护了任何品牌（与搜索无关）。
  /// 用于区分「无品牌库」与「搜索无结果」两种空态。
  bool get typeHasBrandLibrary => BrandCatalog.groupsByTypeId(
    selectedType.id,
  ).values.any((items) => items.isNotEmpty);

  factory DeviceAvatarSelectViewData.forType(
    DeviceTypeDef type, {
    String query = '',
  }) {
    return DeviceAvatarSelectViewData(
      selectedType: type,
      groups: BrandCatalog.groupsByTypeId(type.id, query: query),
    );
  }
}
