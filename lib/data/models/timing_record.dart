// ==============================================================================

import '../../core/date/ymd_date.dart';
import '../../core/measure/measure_unit.dart';
import 'project_id.dart';
import 'project_key.dart';
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

  /// 工时收入图表分摊的内部 exclusive end（YYYYMMDD）。
  ///
  /// UI 结束日为 inclusive；保存时会写入 UI 结束日 + 1 day。字段名和
  /// SQLite 列 allocation_cutoff_date 为兼容保留，不重命名。null 表示继续
  /// 使用当前隐式下一条同设备记录/下月 1 日规则；该字段只影响收入图表月份分布。
  final int? allocationCutoffDate;

  /// UI inclusive end date（YYYYMMDD）。
  ///
  /// 仅用于 rent/台班记录展示与编辑回填，不参与收入、月度图表、账户或结清计算。
  /// 不同于 [allocationCutoffDate]：后者是 hours 收入分摊的内部 exclusive end。
  final int? displayEndDate;

  /// 稳定项目身份。旧数据为空时由 contact/site 兼容生成。
  final String projectId;

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

  /// 本条记录收入的整数分（fen 存储权威）。
  ///
  /// Track A / A4-7 起 DB 只保留 income_fen；[income] 是由本字段派生的
  /// yuan getter。构造函数仍接收 yuan double 作为调用便利入口，并立即 round
  /// 成整数分。
  final int incomeFen;

  /// 存储的计量单位（DB unit 列原值的解析结果，nullable）。null 表示 legacy 行，
  /// 由 [unit] getter 按 [type] 派生。仅 [fromMap] 设置；其余构造默认 null。
  final MeasureUnit? _storedUnit;

  /// 存储的 quantity_scaled（DB 列原值，nullable）。null 时由 [quantityScaled]
  /// getter 按 [hours] 派生镜像（rent 行保持 null）。仅 [fromMap] 设置。
  final int? _quantityScaled;

  /// ✅ 是否排除在燃油效率统计之外
  /// true  = 包油 / 不计入油耗效率
  /// false = 正常计入（默认）
  final bool excludeFromFuelEfficiency;

  /// 是否为破碎模式
  /// true  = 破碎
  /// false = 挖斗（默认）
  final bool isBreaking;

  TimingRecord({
    this.id,
    required this.deviceId,
    required this.startDate,
    this.allocationCutoffDate,
    this.displayEndDate,
    this.projectId = '',
    required this.contact,
    required this.site,
    required this.type,
    required this.startMeter,
    required this.endMeter,
    required this.hours,
    required double income,
    int? incomeFen,
    MeasureUnit? unit,
    int? quantityScaled,
    this.excludeFromFuelEfficiency = false,
    this.isBreaking = false,
  }) : incomeFen = incomeFen ?? _yuanToFen(income),
       _storedUnit = unit,
       _quantityScaled = quantityScaled;

  // ---------------------------------------------------------------------------
  // copyWith：用于编辑/更新记录
  // ---------------------------------------------------------------------------
  TimingRecord copyWith({
    int? id,
    int? deviceId,
    int? startDate,
    Object? allocationCutoffDate = _sentinel,
    Object? displayEndDate = _sentinel,
    String? projectId,
    String? contact,
    String? site,
    TimingType? type,
    double? startMeter,
    double? endMeter,
    double? hours,
    double? income,
    int? incomeFen,
    bool? excludeFromFuelEfficiency,
    bool? isBreaking,
  }) {
    final resolvedIncomeFen =
        incomeFen ?? (income == null ? this.incomeFen : _yuanToFen(income));
    return TimingRecord(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      startDate: startDate ?? this.startDate,
      allocationCutoffDate: identical(allocationCutoffDate, _sentinel)
          ? this.allocationCutoffDate
          : allocationCutoffDate as int?,
      displayEndDate: identical(displayEndDate, _sentinel)
          ? this.displayEndDate
          : displayEndDate as int?,
      projectId: projectId ?? this.projectId,
      contact: contact ?? this.contact,
      site: site ?? this.site,
      type: type ?? this.type,
      startMeter: startMeter ?? this.startMeter,
      endMeter: endMeter ?? this.endMeter,
      hours: hours ?? this.hours,
      income: resolvedIncomeFen / 100,
      incomeFen: resolvedIncomeFen,
      excludeFromFuelEfficiency:
          excludeFromFuelEfficiency ?? this.excludeFromFuelEfficiency,
      isBreaking: isBreaking ?? this.isBreaking,
    );
  }

  // ---------------------------------------------------------------------------
  // SQLite → Map
  // ---------------------------------------------------------------------------
  Map<String, Object?> toMap({
    bool includeNullAllocationCutoffDate = false,
    bool includeNullDisplayEndDate = false,
  }) {
    final map = <String, Object?>{
      'id': id,
      'project_id': effectiveProjectId,
      'device_id': deviceId,
      'start_date': startDate,
      'contact': contact,
      'site': site,
      'type': type.name, // 'hours' / 'rent'
      'start_meter': startMeter,
      'end_meter': endMeter,
      'hours': hours,
      // Track A / A4-7：income_fen 是唯一存储权威，income REAL 已从 schema
      // 删除；double income 仅为派生 getter。
      'income_fen': incomeFen,
      // S2 统一计量镜像双写（v33）：unit/quantity_scaled 与 type/hours 同步
      // 落库；type/hours 仍是权威，读路径不切换。rent 行 quantity 暂为 null
      // （租期计量语义留待租期模板落地时定义）。
      'unit': unit.dbValue,
      'quantity_scaled': quantityScaled,
      // SQLite 不支持 bool，这里统一用 0 / 1
      'exclude_from_fuel_eff': excludeFromFuelEfficiency ? 1 : 0,
      'is_breaking': isBreaking ? 1 : 0,
    };
    final cutoff = allocationCutoffDate;
    if (cutoff != null) {
      map['allocation_cutoff_date'] = cutoff;
    } else if (includeNullAllocationCutoffDate) {
      map['allocation_cutoff_date'] = null;
    }
    final displayEnd = displayEndDate;
    if (displayEnd != null) {
      map['display_end_date'] = displayEnd;
    } else if (includeNullDisplayEndDate) {
      map['display_end_date'] = null;
    }
    return map;
  }

  // ---------------------------------------------------------------------------
  // Map → Model
  // 字段不存在时，默认 false
  // ---------------------------------------------------------------------------
  static TimingRecord fromMap(Map<String, Object?> m) {
    final incomeFen = (m['income_fen'] as num?)?.toInt();
    if (incomeFen == null) {
      throw StateError('timing_records.income_fen is required');
    }
    final startDate = m['start_date'];
    if (startDate is! int || YmdDate.fromInt(startDate) == null) {
      throw FormatException('Invalid timing_records.start_date: $startDate');
    }
    return TimingRecord(
      id: m['id'] as int?,
      deviceId: m['device_id'] as int,
      startDate: startDate,
      allocationCutoffDate: (m['allocation_cutoff_date'] as num?)?.toInt(),
      displayEndDate: (m['display_end_date'] as num?)?.toInt(),
      projectId: (m['project_id'] as String?) ?? '',
      contact: (m['contact'] as String?) ?? '',
      site: (m['site'] as String?) ?? '',
      type: _parseType(m['type']),
      startMeter: (m['start_meter'] as num).toDouble(),
      endMeter: (m['end_meter'] as num).toDouble(),
      hours: (m['hours'] as num).toDouble(),
      income: incomeFen / 100,
      incomeFen: incomeFen,
      unit: MeasureUnitCodec.tryFromDbValue(m['unit'] as String?),
      quantityScaled: (m['quantity_scaled'] as num?)?.toInt(),
      excludeFromFuelEfficiency:
          ((m['exclude_from_fuel_eff'] as int?) ?? 0) == 1,
      isBreaking: ((m['is_breaking'] as int?) ?? 0) == 1,
    );
  }

  /// 本条记录收入的 yuan 派生值。
  ///
  /// **hours 应收不读此值**，仍由 hours×rate 重算；income_fen 对 hours 仅是快照。
  double get income => incomeFen / 100;

  /// 计量单位（统一计量模型镜像，《纲要》§3/§10.2）。优先返回存储的 unit；
  /// legacy 行由 [type] 派生：rent → RENT，其余 → HOUR。type 仍是业务权威。
  MeasureUnit get unit =>
      _storedUnit ??
      (type == TimingType.rent ? MeasureUnit.rent : MeasureUnit.hour);

  /// 计量值定标整数（×1000，HOUR 下等同 hours_milli）。优先返回存储值；
  /// hours 行由 [hours] 派生镜像；rent 行租期计量语义未定，返回 null。
  int? get quantityScaled =>
      _quantityScaled ??
      (type == TimingType.rent ? null : (hours * 1000).round());

  /// 权威工作量的小时表示（[quantityScaled]/1000；rent 行为 0）。
  ///
  /// S2 读路径：聚合/报表的工时来源统一走此 getter，而非 REAL [hours]——
  /// 与旧值的差异仅是对齐到毫时网格（应收经 AmountPolicy 时本就按毫时取整）。
  double get hoursFromQuantity => (quantityScaled ?? 0) / 1000.0;

  static TimingType _parseType(Object? value) {
    if (value is String) {
      for (final type in TimingType.values) {
        if (type.name == value) return type;
      }
    }
    return TimingType.hours;
  }

  String get legacyProjectKey {
    return ProjectKey.buildKey(contact: contact, site: site);
  }

  String get effectiveProjectId {
    return ProjectId.ensure(
      projectId: projectId,
      legacyProjectKey: legacyProjectKey,
    );
  }

  @override
  String toString() =>
      'TimingRecord(id:$id deviceId:$deviceId date:$startDate '
      'allocationCutoffDate:$allocationCutoffDate '
      'displayEndDate:$displayEndDate '
      'hours:$hours excludeFuel:$excludeFromFuelEfficiency '
      'isBreaking:$isBreaking)';
}

const _sentinel = Object();

int _yuanToFen(num value) => (value * 100).round();
