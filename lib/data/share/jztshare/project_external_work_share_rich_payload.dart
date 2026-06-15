// project_external_work_share v1 富事实层 payload 模型。
//
// 设计要点（5B）：
// - 加法式：本模型 toMap() 同时输出旧导入端兼容键
//   (share_id / sender_name / source_installation_uuid / export_lines)
//   与富事实层键 (summary / project_snapshot / devices / records /
//   device_groups)。旧 ProjectExternalWorkSharePayload.fromMap 对未知键宽容，
//   因此本输出对现有导入链路零破坏。
// - 真实金额永远在 records[].income_fen（来自 TimingRecord.income_fen，不重算）。
//   export_lines[] 仅是能无损通过旧 AmountPolicy 校验的兼容子集。
// - 本文件不写文件、不计算 envelope/payloadSha256（属既有/5C）。
//
// 导入端（6+）：本文件额外提供 fromMap 工厂，作为 v1 富事实层 schema 的
// 唯一解析来源（与导出 toMap 同源，避免双份 schema 漂移）。fromMap 为纯加法，
// 不改变任何导出行为。

import '../../models/external_work_parse.dart';
import 'jztshare_errors.dart';

JztShareParseException _richParseError(String message, Object? source) {
  return JztShareParseException(
    JztShareErrorCodes.invalidPayload,
    message,
    source,
  );
}

Map<String, Object?> _requireObject(Object? raw, String label) {
  if (raw is! Map<String, Object?>) {
    throw _richParseError('$label must be an object', raw);
  }
  return raw;
}

double? _optionalDouble(Object? value, String key, Object? source) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  throw _richParseError('Invalid number: $key', source);
}

/// 加法式可选字段：旧 payload 不含此键、或 JSON 显式 null 时返回 null；
/// 非整数或负数立刻报错（绝不悄悄当作 0 / 未知）。
int? _optionalNonNegativeInt(Map<String, Object?> map, String key) {
  if (!map.containsKey(key)) return null;
  final value = map[key];
  if (value == null) return null;
  if (value is int) {
    if (value < 0) {
      throw _richParseError('$key must be >= 0', map);
    }
    return value;
  }
  if (value is num) {
    final asInt = value.toInt();
    if (asInt != value || asInt < 0) {
      throw _richParseError('$key must be a non-negative integer', map);
    }
    return asInt;
  }
  throw _richParseError('$key must be an integer', map);
}

double _requiredDouble(Object? value, String key, Object? source) {
  if (value is num) return value.toDouble();
  throw _richParseError('Missing required number: $key', source);
}

bool _requiredBool(Object? value, String key, Object? source) {
  if (value is bool) return value;
  throw _richParseError('Missing required bool: $key', source);
}

class ProjectExternalWorkShareRichPayload {
  const ProjectExternalWorkShareRichPayload({
    required this.shareId,
    required this.senderName,
    required this.sourceInstallationUuid,
    required this.protocolVersion,
    required this.fingerprintVersion,
    required this.summary,
    required this.projectSnapshot,
    required this.devices,
    required this.records,
    required this.deviceGroups,
    required this.exportLines,
    this.memberProjects = const [],
  });

  /// 富事实层版本号；与 envelope.formatVersion 相互独立。
  static const int currentProtocolVersion = 1;

  /// originFingerprint 算法版本：字段集合/顺序/口径变更时递增，
  /// 供导入端判断指纹可比性。
  static const int currentFingerprintVersion = 2;

  final String shareId;
  final String senderName;
  final String sourceInstallationUuid;
  final int protocolVersion;
  final int fingerprintVersion;
  final ProjectExternalWorkShareSummary summary;
  final ProjectExternalWorkShareProjectSnapshot projectSnapshot;
  final List<ProjectExternalWorkShareDeviceSnapshot> devices;
  final List<ProjectExternalWorkShareRecord> records;
  final List<ProjectExternalWorkShareDeviceGroup> deviceGroups;
  final List<ProjectExternalWorkShareExportLine> exportLines;

  /// 合并分享包的成员项目结构；普通单项目分享为空（加法式键，旧导入端忽略）。
  /// 每个成员携带 projectId/projectKey/contact/site/displayName + 其下
  /// source_timing_record_id 列表（与 records[] 关联），接收端据此可还原
  /// 「这是一个分享包，含哪些成员项目，每个成员下有哪些子记录」。
  final List<ProjectExternalWorkShareMemberProject> memberProjects;

  Map<String, Object?> toMap() {
    return {
      // ---- 旧导入端兼容键（顺序与既有 fromMap 读取一致）----
      'share_id': shareId,
      'sender_name': senderName,
      'source_installation_uuid': sourceInstallationUuid,
      'export_lines': exportLines
          .map((line) => line.toMap())
          .toList(growable: false),
      // ---- 富事实层键 ----
      'protocol_version': protocolVersion,
      'fingerprint_version': fingerprintVersion,
      'summary': summary.toMap(),
      'project_snapshot': projectSnapshot.toMap(),
      'devices': devices.map((d) => d.toMap()).toList(growable: false),
      'records': records.map((r) => r.toMap()).toList(growable: false),
      'device_groups': deviceGroups
          .map((g) => g.toMap())
          .toList(growable: false),
      // 加法式：仅合并分享包输出，单项目分享不写此键。
      if (memberProjects.isNotEmpty)
        'member_projects': memberProjects
            .map((m) => m.toMap())
            .toList(growable: false),
    };
  }
}

/// 合并分享包的成员项目快照（加法式键 member_projects[] 元素）。
class ProjectExternalWorkShareMemberProject {
  const ProjectExternalWorkShareMemberProject({
    required this.sourceProjectId,
    required this.sourceProjectKey,
    required this.contactSnapshot,
    required this.siteSnapshot,
    required this.displayName,
    required this.recordIds,
  });

  /// 成员项目真实身份（保留溯源，导入端不得复用为本机 id）。
  final String sourceProjectId;
  final String sourceProjectKey;
  final String contactSnapshot;
  final String siteSnapshot;

  /// 成员项目展示名（如「联系人 · 工地」）。
  final String displayName;

  /// 该成员项目下的 source_timing_record_id 列表（与 records[] 关联）。
  final List<int> recordIds;

  static ProjectExternalWorkShareMemberProject fromMap(
    Map<String, Object?> map,
  ) {
    final reader = ExternalFieldReader(map);
    try {
      final rawIds = map['record_ids'];
      final ids = <int>[];
      if (rawIds is List) {
        for (final value in rawIds) {
          if (value is int) {
            ids.add(value);
          } else if (value is num && value.toInt() == value) {
            ids.add(value.toInt());
          } else {
            throw _richParseError('record_ids must be integers', map);
          }
        }
      } else if (rawIds != null) {
        throw _richParseError('record_ids must be an array', map);
      }
      return ProjectExternalWorkShareMemberProject(
        sourceProjectId: reader.requiredString('source_project_id'),
        sourceProjectKey: reader.requiredString('source_project_key'),
        contactSnapshot: reader.requiredString('contact_snapshot'),
        siteSnapshot: reader.requiredString('site_snapshot'),
        displayName: reader.requiredString('display_name'),
        recordIds: List<int>.unmodifiable(ids),
      );
    } on ExternalDataParseException catch (error) {
      throw _richParseError(error.message, map);
    }
  }

  Map<String, Object?> toMap() {
    return {
      'source_project_id': sourceProjectId,
      'source_project_key': sourceProjectKey,
      'contact_snapshot': contactSnapshot,
      'site_snapshot': siteSnapshot,
      'display_name': displayName,
      'record_ids': List<int>.unmodifiable(recordIds),
    };
  }
}

class ProjectExternalWorkShareSummary {
  const ProjectExternalWorkShareSummary({
    required this.deviceCount,
    required this.recordCount,
    required this.totalIncomeFen,
    required this.totalHoursMilli,
  });

  final int deviceCount;
  final int recordCount;
  final int totalIncomeFen;
  final int totalHoursMilli;

  static ProjectExternalWorkShareSummary fromMap(Map<String, Object?> map) {
    final reader = ExternalFieldReader(map);
    try {
      return ProjectExternalWorkShareSummary(
        deviceCount: reader.requiredNonNegativeInt('device_count'),
        recordCount: reader.requiredNonNegativeInt('record_count'),
        totalIncomeFen: reader.requiredNonNegativeInt('total_income_fen'),
        totalHoursMilli: reader.requiredNonNegativeInt('total_hours_milli'),
      );
    } on ExternalDataParseException catch (error) {
      throw _richParseError(error.message, map);
    }
  }

  Map<String, Object?> toMap() {
    return {
      'device_count': deviceCount,
      'record_count': recordCount,
      'total_income_fen': totalIncomeFen,
      'total_hours_milli': totalHoursMilli,
    };
  }
}

class ProjectExternalWorkShareProjectSnapshot {
  const ProjectExternalWorkShareProjectSnapshot({
    required this.sourceProjectId,
    required this.sourceProjectKey,
    required this.contactSnapshot,
    required this.siteSnapshot,
    this.displayName,
    this.projectReceivedFen = 0,
  });

  final String sourceProjectId;
  final String sourceProjectKey;

  /// 仅作来源追踪；导入列表/详情不展示。
  final String contactSnapshot;
  final String siteSnapshot;

  /// 合并分享包的聚合展示名（如「分享人 · 鲜滩+尚义...」）。
  /// 普通单项目分享为 null：接收端继续按既有口径自行拼展示名（加法式可选字段）。
  final String? displayName;

  /// 导出时该项目累计实收款（分）。旧分享包缺字段时按 0 兼容。
  final int projectReceivedFen;

  static ProjectExternalWorkShareProjectSnapshot fromMap(
    Map<String, Object?> map,
  ) {
    final reader = ExternalFieldReader(map);
    try {
      return ProjectExternalWorkShareProjectSnapshot(
        sourceProjectId: reader.requiredString('source_project_id'),
        sourceProjectKey: reader.requiredString('source_project_key'),
        contactSnapshot: reader.requiredString('contact_snapshot'),
        siteSnapshot: reader.requiredString('site_snapshot'),
        displayName: reader.optionalString('display_name'),
        projectReceivedFen:
            _optionalNonNegativeInt(map, 'project_received_fen') ?? 0,
      );
    } on ExternalDataParseException catch (error) {
      throw _richParseError(error.message, map);
    }
  }

  Map<String, Object?> toMap() {
    return {
      'source_project_id': sourceProjectId,
      'source_project_key': sourceProjectKey,
      'contact_snapshot': contactSnapshot,
      'site_snapshot': siteSnapshot,
      if (displayName != null) 'display_name': displayName,
      'project_received_fen': projectReceivedFen,
      // v1 省略 project_status_snapshot：代码中无 Project 实体/项目状态来源。
    };
  }
}

class ProjectExternalWorkShareDeviceSnapshot {
  const ProjectExternalWorkShareDeviceSnapshot({
    required this.sourceDeviceId,
    required this.name,
    required this.brand,
    this.model,
    this.type,
    required this.displayName,
    required this.recordCount,
    required this.totalHoursMilli,
    required this.totalIncomeFen,
  });

  final int sourceDeviceId;
  final String name;
  final String brand;
  final String? model;

  /// 取自 Device.equipmentType.dbValue；设备缺失时为 null。
  final String? type;
  final String displayName;
  final int recordCount;
  final int totalHoursMilli;
  final int totalIncomeFen;

  static ProjectExternalWorkShareDeviceSnapshot fromMap(
    Map<String, Object?> map,
  ) {
    final reader = ExternalFieldReader(map);
    try {
      return ProjectExternalWorkShareDeviceSnapshot(
        sourceDeviceId: reader.requiredNonNegativeInt('source_device_id'),
        name: reader.requiredString('name'),
        brand: reader.requiredString('brand'),
        model: reader.optionalString('model'),
        type: reader.optionalString('type'),
        displayName: reader.requiredString('display_name'),
        recordCount: reader.requiredNonNegativeInt('record_count'),
        totalHoursMilli: reader.requiredNonNegativeInt('total_hours_milli'),
        totalIncomeFen: reader.requiredNonNegativeInt('total_income_fen'),
      );
    } on ExternalDataParseException catch (error) {
      throw _richParseError(error.message, map);
    }
  }

  Map<String, Object?> toMap() {
    return {
      'source_device_id': sourceDeviceId,
      'name': name,
      'brand': brand,
      if (model != null) 'model': model,
      if (type != null) 'type': type,
      'display_name': displayName,
      'record_count': recordCount,
      'total_hours_milli': totalHoursMilli,
      'total_income_fen': totalIncomeFen,
    };
  }
}

class ProjectExternalWorkShareFilledCalculation {
  const ProjectExternalWorkShareFilledCalculation({
    required this.calculatedAt,
    required this.expression,
    required this.result,
    required this.ticketCount,
    required this.resultMilliHours,
    required this.resultDisplay,
  });

  final String calculatedAt;
  final String expression;
  final double result;
  final int ticketCount;

  /// 派生：WorkHours.fromHours(result).milliHours。
  final int resultMilliHours;

  /// 派生：result 保留 1 位小数 + " h"（如 "37.0 h"）。
  final String resultDisplay;

  static ProjectExternalWorkShareFilledCalculation fromMap(
    Map<String, Object?> map,
  ) {
    final reader = ExternalFieldReader(map);
    try {
      return ProjectExternalWorkShareFilledCalculation(
        calculatedAt: reader.requiredString('calculated_at'),
        expression: reader.requiredString('expression'),
        result: _requiredDouble(map['result'], 'result', map),
        ticketCount: reader.requiredNonNegativeInt('ticket_count'),
        resultMilliHours: reader.requiredNonNegativeInt('result_milli_hours'),
        resultDisplay: reader.requiredString('result_display'),
      );
    } on ExternalDataParseException catch (error) {
      throw _richParseError(error.message, map);
    }
  }

  Map<String, Object?> toMap() {
    return {
      'calculated_at': calculatedAt,
      'expression': expression,
      'result': result,
      'ticket_count': ticketCount,
      'result_milli_hours': resultMilliHours,
      'result_display': resultDisplay,
    };
  }
}

class ProjectExternalWorkShareRecord {
  const ProjectExternalWorkShareRecord({
    required this.sourceRecordUuid,
    required this.sourceTimingRecordId,
    required this.sourceProjectId,
    required this.sourceDeviceId,
    required this.workDate,
    required this.type,
    this.startMeter,
    this.endMeter,
    required this.hoursMilli,
    required this.incomeFen,
    this.sourceUnitPriceFen,
    required this.isBreaking,
    required this.originFingerprint,
    this.filledCalculation,
  });

  /// 包内临时记录 id。导出端必须保证每次重打包生成新的值。
  final String sourceRecordUuid;
  final int sourceTimingRecordId;
  final String sourceProjectId;

  /// 包内临时设备 id，不得复用本机设备表 id。
  final int sourceDeviceId;
  final int workDate;

  /// 'hours' / 'rent'。
  final String type;

  /// rent/台班无有效码表时为 null，不填 0。
  final double? startMeter;
  final double? endMeter;
  final int hoursMilli;

  /// 始终来自 TimingRecord.income_fen，真实收入，不按工时×单价重算。
  final int incomeFen;

  /// 可信单价：仅在导出端能从设备真实单价无损还原 incomeFen
  /// (`AmountPolicy(hoursMilli, deviceFen).fen == incomeFen`) 时写入。
  /// rent/台班 / 人工覆写金额 / 设备缺失 / 来源不可信时为 null（绝不填 0）。
  /// 导入端禁止用 income_fen ÷ hours 反推此字段。
  final int? sourceUnitPriceFen;
  final bool isBreaking;
  final String originFingerprint;
  final ProjectExternalWorkShareFilledCalculation? filledCalculation;

  static ProjectExternalWorkShareRecord fromMap(Map<String, Object?> map) {
    final reader = ExternalFieldReader(map);
    try {
      final rawFilled = map['filled_calculation'];
      return ProjectExternalWorkShareRecord(
        sourceRecordUuid: reader.requiredString('source_record_uuid'),
        sourceTimingRecordId: reader.requiredNonNegativeInt(
          'source_timing_record_id',
        ),
        sourceProjectId: reader.requiredString('source_project_id'),
        sourceDeviceId: reader.requiredNonNegativeInt('source_device_id'),
        workDate: reader.requiredNonNegativeInt('work_date'),
        type: reader.requiredString('type'),
        startMeter: _optionalDouble(map['start_meter'], 'start_meter', map),
        endMeter: _optionalDouble(map['end_meter'], 'end_meter', map),
        hoursMilli: reader.requiredNonNegativeInt('hours_milli'),
        incomeFen: reader.requiredNonNegativeInt('income_fen'),
        // 加法式：旧 payload 缺字段 → null；显式 null → null；存在数值 → 校验 >=0。
        sourceUnitPriceFen: _optionalNonNegativeInt(
          map,
          'source_unit_price_fen',
        ),
        isBreaking: _requiredBool(map['is_breaking'], 'is_breaking', map),
        originFingerprint: reader.requiredString('origin_fingerprint'),
        filledCalculation: rawFilled == null
            ? null
            : ProjectExternalWorkShareFilledCalculation.fromMap(
                _requireObject(rawFilled, 'filled_calculation'),
              ),
      );
    } on ExternalDataParseException catch (error) {
      throw _richParseError(error.message, map);
    }
  }

  Map<String, Object?> toMap() {
    return {
      'source_record_uuid': sourceRecordUuid,
      'source_timing_record_id': sourceTimingRecordId,
      'source_project_id': sourceProjectId,
      'source_device_id': sourceDeviceId,
      'work_date': workDate,
      'type': type,
      'start_meter': startMeter,
      'end_meter': endMeter,
      'hours_milli': hoursMilli,
      'income_fen': incomeFen,
      // 未知用 null，禁止伪造 0；与 startMeter/endMeter 同样的 null 显式输出。
      'source_unit_price_fen': sourceUnitPriceFen,
      'is_breaking': isBreaking,
      'origin_fingerprint': originFingerprint,
      if (filledCalculation != null)
        'filled_calculation': filledCalculation!.toMap(),
    };
  }
}

class ProjectExternalWorkShareDeviceGroup {
  const ProjectExternalWorkShareDeviceGroup({
    required this.sourceDeviceId,
    required this.recordIds,
    required this.recordCount,
    this.firstStartMeter,
    this.lastEndMeter,
    required this.totalHoursMilli,
    required this.totalIncomeFen,
    this.meterSpanMilli,
    this.meterErrorMilli,
  });

  final int sourceDeviceId;

  /// 组内 source_timing_record_id，按 workDate 再 id 稳定排序。
  final List<int> recordIds;
  final int recordCount;

  /// 无 hours 型有效码表时为 null。
  final double? firstStartMeter;
  final double? lastEndMeter;
  final int totalHoursMilli;
  final int totalIncomeFen;

  /// = lastEndMeterMilli - firstStartMeterMilli；无有效码表时 null。
  final int? meterSpanMilli;

  /// = abs(meterSpanMilli - totalHoursMilli)；无有效码表时 null。
  final int? meterErrorMilli;

  Map<String, Object?> toMap() {
    return {
      'source_device_id': sourceDeviceId,
      'record_ids': List<int>.unmodifiable(recordIds),
      'record_count': recordCount,
      'first_start_meter': firstStartMeter,
      'last_end_meter': lastEndMeter,
      'total_hours_milli': totalHoursMilli,
      'total_income_fen': totalIncomeFen,
      'meter_span_milli': meterSpanMilli,
      'meter_error_milli': meterErrorMilli,
    };
  }
}

/// 旧导入端兼容行。字段/键与既有 ProjectExternalWorkShareLine.fromMap 严格一致。
class ProjectExternalWorkShareExportLine {
  const ProjectExternalWorkShareExportLine({
    required this.exportLineUuid,
    required this.originFingerprint,
    required this.contactSnapshot,
    required this.siteSnapshot,
    this.equipmentBrand,
    this.equipmentModel,
    this.equipmentType,
    required this.workDate,
    required this.hoursMilli,
    required this.sourceUnitPriceFen,
    required this.amountFen,
    this.note,
  });

  final String exportLineUuid;
  final String originFingerprint;
  final String contactSnapshot;
  final String siteSnapshot;
  final String? equipmentBrand;
  final String? equipmentModel;
  final String? equipmentType;
  final int workDate;
  final int hoursMilli;
  final int sourceUnitPriceFen;
  final int amountFen;
  final String? note;

  Map<String, Object?> toMap() {
    return {
      'export_line_uuid': exportLineUuid,
      'origin_fingerprint': originFingerprint,
      'contact_snapshot': contactSnapshot,
      'site_snapshot': siteSnapshot,
      if (equipmentBrand != null) 'equipment_brand': equipmentBrand,
      if (equipmentModel != null) 'equipment_model': equipmentModel,
      if (equipmentType != null) 'equipment_type': equipmentType,
      'work_date': workDate,
      'hours_milli': hoursMilli,
      'source_unit_price_fen': sourceUnitPriceFen,
      'amount_fen': amountFen,
      if (note != null) 'note': note,
    };
  }
}
