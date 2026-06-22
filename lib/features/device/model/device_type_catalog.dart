import 'package:flutter/material.dart';

import '../../../data/models/device.dart';
import '../../../l10n/gen/app_localizations.dart';
import 'device_create_flow.dart';

/// 设备类型可用性：
/// - [available]：已接入创建流程，可真正落库创建。
/// - [comingSoon]：仅可浏览（含品牌墙），创建流程待 Phase 2/3 接入。
enum DeviceTypeAvailability { available, comingSoon }

/// 文案解析器：把 l10n key 的取值延后到 build 期，保证全部走国际化。
typedef L10nText = String Function(AppLocalizations l10n);

/// 设备类型定义。
///
/// 这是**展示层分类法**（taxonomy），刻意与落库的 [EquipmentType] 解耦：
/// - 选择页只消费本配置，可随时新增类型而不触碰 DB/领域层。
/// - 只有 [availability] == available 的类型才映射到 [equipmentType] 并可创建。
class DeviceTypeDef {
  /// 稳定标识（也用于品牌库按类型分桶）：'excavator' / 'roller' / 'drone' ...
  final String id;

  /// 所属大类 id（对应 [DeviceTypeCategory.id]）。
  final String categoryId;

  /// 列表/卡片图标（Material 占位图标）。当 [svgGlyph] 非空时由后者覆盖渲染。
  final IconData icon;

  /// 可选的内联 SVG 图标字符串（如挖掘机的「挖斗」），优先于 [icon] 渲染。
  /// 走 flutter_svg 内联绘制，不引入第三方图片资源。
  final String? svgGlyph;

  /// 类型显示名（国际化）。
  final L10nText name;

  /// 一句短描述（国际化），如「土方 / 矿山 / 施工」。
  final L10nText description;

  final DeviceTypeAvailability availability;

  /// 仅当 [availability] == available 且映射到现有落库枚举时非空。
  final EquipmentType? equipmentType;

  /// 选定后进入的创建业务模式。
  final DeviceCreateFlow createFlow;

  const DeviceTypeDef({
    required this.id,
    required this.categoryId,
    required this.icon,
    required this.name,
    required this.description,
    required this.availability,
    required this.createFlow,
    this.equipmentType,
    this.svgGlyph,
  });

  bool get isAvailable => availability == DeviceTypeAvailability.available;
}

/// 挖掘机图标（内联 SVG，0.8px 细描边对齐其它 Material outlined 图标）：
/// 左向侧视——大臂/小臂上扬至左上、挖斗垂于左下，右侧驾驶室带车窗、
/// 底部履带含驱动轮。线性风格，简洁统一，颜色由渲染处通过 colorFilter 注入。
const String kExcavatorGlyphSvg =
    '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" '
    'fill="none" stroke="#000" stroke-width="0.8" '
    'stroke-linecap="round" stroke-linejoin="round">'
    // 大臂 + 小臂（左上）
    '<path d="M14 13.4 L7.4 8.2 L4.8 13.4"/>'
    // 挖斗（左下）
    '<path d="M4.8 13.4 L3.6 15 Q4.8 16.6 6.8 15.6"/>'
    // 驾驶室（右）
    '<path d="M20.4 17.4 V12.6 A1 1 0 0 0 19.4 11.6 H14.6 A1 1 0 0 0 13.6 12.6 V17.4 Z"/>'
    // 车窗
    '<path d="M15.1 13 H18 V15 H15.1 Z"/>'
    // 履带
    '<path d="M20 17.4 H12 A1.6 1.6 0 0 0 12 20.6 H20 A1.6 1.6 0 0 0 20 17.4 Z"/>'
    // 驱动轮
    '<circle cx="17.4" cy="19" r="1"/>'
    '</svg>';

/// 装载机（铲车）图标（内联 SVG，0.8px 细描边，与挖掘机同一线性风格）：
/// 左向侧视——车身/驾驶室 + 双前轮 + 前置举升臂连铲斗。
const String kLoaderGlyphSvg =
    '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" '
    'fill="none" stroke="#000" stroke-width="0.8" '
    'stroke-linecap="round" stroke-linejoin="round">'
    // 车身 + 驾驶室
    '<path d="M6.8 15.4 L6.8 13 L10.3 13 L10.3 9.6 L14 9.6 Q14.6 9.6 14.6 10.2 '
    'L14.6 13 L19 13 Q19.6 13 19.6 13.6 L19.6 15.4"/>'
    // 车底
    '<path d="M11.4 15.7 H14.2"/>'
    // 双举升臂
    '<path d="M6.9 13.4 L3.5 13.9"/>'
    '<path d="M6.9 14.9 L4 15.9"/>'
    // 铲斗
    '<path d="M3.5 13.4 L1.6 14.4 L2.3 16.6 L4.7 16.4"/>'
    // 前后轮
    '<circle cx="9" cy="17.8" r="2.3"/>'
    '<circle cx="16.6" cy="17.8" r="2.3"/>'
    '</svg>';

/// 设备大类（弹层按大类分组展示）。
class DeviceTypeCategory {
  final String id;
  final L10nText name;
  final List<DeviceTypeDef> types;

  const DeviceTypeCategory({
    required this.id,
    required this.name,
    required this.types,
  });
}

/// 设备类型分类法配置（单一数据源，新增类型只改这里）。
///
/// Phase 1：仅 excavator / loader 为 available（复用现有工程机械编辑器），
/// 其余均为 comingSoon —— 可在弹层选中、可浏览品牌墙，但底部主按钮置为「敬请期待」。
final List<DeviceTypeCategory> kDeviceTypeCategories = [
  DeviceTypeCategory(
    id: 'construction',
    name: (l) => l.deviceCategoryConstruction,
    types: [
      DeviceTypeDef(
        id: 'excavator',
        categoryId: 'construction',
        icon: Icons.construction_outlined,
        svgGlyph: kExcavatorGlyphSvg,
        name: (l) => l.deviceEquipmentExcavator,
        description: (l) => l.deviceTypeExcavatorDesc,
        availability: DeviceTypeAvailability.available,
        equipmentType: EquipmentType.excavator,
        createFlow: DeviceCreateFlow.engineeringEditor,
      ),
      DeviceTypeDef(
        id: 'loader',
        categoryId: 'construction',
        icon: Icons.front_loader,
        svgGlyph: kLoaderGlyphSvg,
        name: (l) => l.deviceEquipmentLoader,
        description: (l) => l.deviceTypeLoaderDesc,
        availability: DeviceTypeAvailability.available,
        equipmentType: EquipmentType.loader,
        createFlow: DeviceCreateFlow.engineeringEditor,
      ),
      DeviceTypeDef(
        id: 'roller',
        categoryId: 'construction',
        icon: Icons.circle_outlined,
        name: (l) => l.deviceTypeRollerName,
        description: (l) => l.deviceTypeRollerDesc,
        availability: DeviceTypeAvailability.available,
        equipmentType: EquipmentType.roller,
        createFlow: DeviceCreateFlow.engineeringEditor,
      ),
      DeviceTypeDef(
        id: 'handling_vehicle',
        categoryId: 'construction',
        icon: Icons.local_shipping_outlined,
        name: (l) => l.deviceTypeHandlingVehicleName,
        description: (l) => l.deviceTypeHandlingVehicleDesc,
        availability: DeviceTypeAvailability.comingSoon,
        createFlow: DeviceCreateFlow.comingSoon,
      ),
    ],
  ),
  DeviceTypeCategory(
    id: 'agriculture',
    name: (l) => l.deviceCategoryAgriculture,
    types: [
      DeviceTypeDef(
        id: 'agricultural_machine',
        categoryId: 'agriculture',
        icon: Icons.agriculture_outlined,
        name: (l) => l.deviceTypeAgriMachineName,
        description: (l) => l.deviceTypeAgriMachineDesc,
        availability: DeviceTypeAvailability.comingSoon,
        createFlow: DeviceCreateFlow.comingSoon,
      ),
    ],
  ),
  DeviceTypeCategory(
    id: 'unmanned',
    name: (l) => l.deviceCategoryUnmanned,
    types: [
      DeviceTypeDef(
        id: 'drone',
        categoryId: 'unmanned',
        icon: Icons.flight_outlined,
        name: (l) => l.deviceTypeDroneName,
        description: (l) => l.deviceTypeDroneDesc,
        availability: DeviceTypeAvailability.comingSoon,
        createFlow: DeviceCreateFlow.comingSoon,
      ),
    ],
  ),
  DeviceTypeCategory(
    id: 'smart',
    name: (l) => l.deviceCategorySmart,
    types: [
      DeviceTypeDef(
        id: 'robot',
        categoryId: 'smart',
        icon: Icons.smart_toy_outlined,
        name: (l) => l.deviceTypeRobotName,
        description: (l) => l.deviceTypeRobotDesc,
        availability: DeviceTypeAvailability.comingSoon,
        createFlow: DeviceCreateFlow.comingSoon,
      ),
    ],
  ),
  DeviceTypeCategory(
    id: 'other',
    name: (l) => l.deviceCategoryOther,
    types: [
      DeviceTypeDef(
        id: 'custom',
        categoryId: 'other',
        icon: Icons.devices_other_outlined,
        name: (l) => l.deviceTypeCustomName,
        description: (l) => l.deviceTypeCustomDesc,
        availability: DeviceTypeAvailability.comingSoon,
        createFlow: DeviceCreateFlow.comingSoon,
      ),
    ],
  ),
];

/// 设备类型查询工具。
class DeviceTypeCatalog {
  const DeviceTypeCatalog._();

  static List<DeviceTypeCategory> get categories => kDeviceTypeCategories;

  static List<DeviceTypeDef> get allTypes => [
    for (final c in kDeviceTypeCategories) ...c.types,
  ];

  static DeviceTypeDef? byId(String? id) {
    if (id == null) return null;
    for (final t in allTypes) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// 无历史记录时的默认类型。
  static DeviceTypeDef get defaultType => byId('excavator')!;

  /// 由落库枚举回推展示类型（用于带入历史已选）。
  static DeviceTypeDef fromEquipmentType(EquipmentType type) {
    for (final t in allTypes) {
      if (t.equipmentType == type) return t;
    }
    return defaultType;
  }

  static DeviceTypeCategory categoryOf(DeviceTypeDef def) {
    return kDeviceTypeCategories.firstWhere((c) => c.id == def.categoryId);
  }

  /// 常用类型快捷入口（前四个）；UI 会在末尾再追加「更多」入口。
  static List<DeviceTypeDef> get quickEntries => [
    byId('excavator')!,
    byId('loader')!,
    byId('roller')!,
    byId('handling_vehicle')!,
  ];
}
