// =====================================================================
// ============================== 一、设备模型 Device ==============================
// =====================================================================
//
// 设计目标：
// - id：唯一主键，永不复用（历史记录靠 device_id 锚定）
// - name：显示标签，可以复用（例如“新 SANY 1#”）
// - brand：品牌键（=头像选择），用于自动命名与默认头像
// - customAvatarPath：订阅版可选，自定义头像路径（本地文件路径）
//
// 放置层级：数据层（Models）
// =====================================================================

class Device {
  // -------------------------------------------------------------------
  // 1.1 主键：设备 id（DB 自增，永不复用）
  // -------------------------------------------------------------------
  final int? id;

  // -------------------------------------------------------------------
  // 1.2 显示名（标签）：允许复用，但不作为主键
  // 例如：SANY 1# / SANY 2#
  // -------------------------------------------------------------------
  final String name;

  // -------------------------------------------------------------------
  // 1.3 品牌键（=头像选择）
  // - 必填：因为你 UI 上“选择头像就是在选品牌”
  // -------------------------------------------------------------------
  final String brand;

  // -------------------------------------------------------------------
  // 1.4 型号（可选）
  // -------------------------------------------------------------------
  final String? model;

  // -------------------------------------------------------------------
  // 1.5 默认单价（必填）
  // -------------------------------------------------------------------
  final double defaultUnitPrice;

  // -------------------------------------------------------------------
  // 1.6 基准码表（必填，默认 0.0）
  // -------------------------------------------------------------------
  final double baseMeterHours;

  // -------------------------------------------------------------------
  // 1.7 是否在用（软删除/停用）
  // -------------------------------------------------------------------
  final bool isActive;

  // -------------------------------------------------------------------
  // 1.8 订阅版：自定义头像路径（可选）
  // - 免费版：一般保持 null
  // - Pro：允许填入本地图片路径（后续也可换成资源ID/云端URL）
  // -------------------------------------------------------------------
  final String? customAvatarPath;

  const Device({
    this.id,
    required this.name,
    required this.brand,
    this.model,
    required this.defaultUnitPrice,
    required this.baseMeterHours,
    this.isActive = true,
    this.customAvatarPath,
  });

  Device copyWith({
    int? id,
    String? name,
    String? brand,
    String? model,
    double? defaultUnitPrice,
    double? baseMeterHours,
    bool? isActive,
    String? customAvatarPath,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      defaultUnitPrice: defaultUnitPrice ?? this.defaultUnitPrice,
      baseMeterHours: baseMeterHours ?? this.baseMeterHours,
      isActive: isActive ?? this.isActive,
      customAvatarPath: customAvatarPath ?? this.customAvatarPath,
    );
  }

  // -------------------------------------------------------------------
  // 1.9 toMap / fromMap：给 Repo/DB 用
  // -------------------------------------------------------------------
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'brand': brand,
      'model': model,
      'default_unit_price': defaultUnitPrice,
      'base_meter_hours': baseMeterHours,
      'is_active': isActive ? 1 : 0,
      'custom_avatar_path': customAvatarPath,
    };
  }

  factory Device.fromMap(Map<String, dynamic> map) {
    return Device(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? '',
      brand: (map['brand'] as String?) ?? '',
      model: map['model'] as String?,
      defaultUnitPrice: (map['default_unit_price'] as num?)?.toDouble() ?? 0.0,
      baseMeterHours: (map['base_meter_hours'] as num?)?.toDouble() ?? 0.0,
      isActive: ((map['is_active'] as int?) ?? 1) == 1,
      customAvatarPath: map['custom_avatar_path'] as String?,
    );
  }
}
