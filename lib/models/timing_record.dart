// ==============================================================================
// 📁 文件说明：计时记录模型 (timing_record.dart)
// 设计目标：
// 1. 表达单条设备计时/租赁记录
// 2. 作为 Timing / Fuel / Account 计算的统一数据源
// 3. 支持“包油”业务场景：该工时不计入燃油效率计算
// ==============================================================================

/// 计时类型：
/// - hours：按小时计费
/// - rent ：按租期/包月等方式计费
enum TimingType { hours, rent }

class TimingRecord {
  /// SQLite 主键
  final int? id;

  /// 设备 ID
  final int deviceId;

  /// 开始日期（YYYYMMDD）
  final int startDate;

  /// 联系人
  final String contact;

  /// 工地/项目名称
  final String site;

  /// 计时类型
  final TimingType type;

  /// 开始码表
  final double startMeter;

  /// 结束码表
  final double endMeter;

  /// 工时（小时）
  final double hours;

  /// 本条记录对应的收入
  final double income;

  /// ✅ 是否排除在燃油效率统计之外
  /// true  = 包油 / 不计入油耗效率
  /// false = 正常计入（默认）
  final bool excludeFromFuelEfficiency;

  const TimingRecord({
    this.id,
    required this.deviceId,
    required this.startDate,
    required this.contact,
    required this.site,
    required this.type,
    required this.startMeter,
    required this.endMeter,
    required this.hours,
    required this.income,
    this.excludeFromFuelEfficiency = false,
  });

  // ---------------------------------------------------------------------------
  // copyWith：用于编辑/更新记录
  // ---------------------------------------------------------------------------
  TimingRecord copyWith({
    int? id,
    int? deviceId,
    int? startDate,
    String? contact,
    String? site,
    TimingType? type,
    double? startMeter,
    double? endMeter,
    double? hours,
    double? income,
    bool? excludeFromFuelEfficiency,
  }) {
    return TimingRecord(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      startDate: startDate ?? this.startDate,
      contact: contact ?? this.contact,
      site: site ?? this.site,
      type: type ?? this.type,
      startMeter: startMeter ?? this.startMeter,
      endMeter: endMeter ?? this.endMeter,
      hours: hours ?? this.hours,
      income: income ?? this.income,
      excludeFromFuelEfficiency:
          excludeFromFuelEfficiency ?? this.excludeFromFuelEfficiency,
    );
  }

  // ---------------------------------------------------------------------------
  // SQLite → Map
  // ---------------------------------------------------------------------------
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'device_id': deviceId,
      'start_date': startDate,
      'contact': contact,
      'site': site,
      'type': type.name, // 'hours' / 'rent'
      'start_meter': startMeter,
      'end_meter': endMeter,
      'hours': hours,
      'income': income,
      // SQLite 不支持 bool，这里统一用 0 / 1
      'exclude_from_fuel_eff': excludeFromFuelEfficiency ? 1 : 0,
    };
  }

  // ---------------------------------------------------------------------------
  // Map → Model
  // 字段不存在时，默认 false
  // ---------------------------------------------------------------------------
  static TimingRecord fromMap(Map<String, Object?> m) {
    return TimingRecord(
      id: m['id'] as int?,
      deviceId: m['device_id'] as int,
      startDate: m['start_date'] as int,
      contact: (m['contact'] as String?) ?? '',
      site: (m['site'] as String?) ?? '',
      type: TimingType.values.byName((m['type'] as String?) ?? 'hours'),
      startMeter: (m['start_meter'] as num).toDouble(),
      endMeter: (m['end_meter'] as num).toDouble(),
      hours: (m['hours'] as num).toDouble(),
      income: (m['income'] as num).toDouble(),
      excludeFromFuelEfficiency:
          ((m['exclude_from_fuel_eff'] as int?) ?? 0) == 1,
    );
  }

  @override
  String toString() =>
      'TimingRecord(id:$id deviceId:$deviceId date:$startDate '
      'hours:$hours excludeFuel:$excludeFromFuelEfficiency)';
}
