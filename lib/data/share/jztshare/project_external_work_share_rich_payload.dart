// project_external_work_share v1 富事实层 payload 模型。
//
// 设计要点（5B）：
// - 加法式：本模型 toMap() 同时输出旧导入端兼容键
//   (share_id / sender_name / source_installation_uuid / export_lines)
//   与富事实层键 (summary / project_snapshot / devices / records /
//   device_groups)。旧 ProjectExternalWorkSharePayload.fromMap 对未知键宽容，
//   因此本输出对现有导入链路零破坏。
// - 真实金额永远在 records[].income_fen（来自 TimingRecord.income，不重算）。
//   export_lines[] 仅是能无损通过旧 AmountPolicy 校验的兼容子集。
// - 本文件不写文件、不计算 envelope/payloadSha256（属既有/5C）。

class ProjectExternalWorkShareRichPayload {
  const ProjectExternalWorkShareRichPayload({
    required this.shareId,
    required this.senderName,
    required this.sourceInstallationUuid,
    required this.protocolVersion,
    required this.summary,
    required this.projectSnapshot,
    required this.devices,
    required this.records,
    required this.deviceGroups,
    required this.exportLines,
  });

  /// 富事实层版本号；与 envelope.formatVersion 相互独立。
  static const int currentProtocolVersion = 1;

  final String shareId;
  final String senderName;
  final String sourceInstallationUuid;
  final int protocolVersion;
  final ProjectExternalWorkShareSummary summary;
  final ProjectExternalWorkShareProjectSnapshot projectSnapshot;
  final List<ProjectExternalWorkShareDeviceSnapshot> devices;
  final List<ProjectExternalWorkShareRecord> records;
  final List<ProjectExternalWorkShareDeviceGroup> deviceGroups;
  final List<ProjectExternalWorkShareExportLine> exportLines;

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
      'summary': summary.toMap(),
      'project_snapshot': projectSnapshot.toMap(),
      'devices': devices.map((d) => d.toMap()).toList(growable: false),
      'records': records.map((r) => r.toMap()).toList(growable: false),
      'device_groups': deviceGroups
          .map((g) => g.toMap())
          .toList(growable: false),
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
  });

  final String sourceProjectId;
  final String sourceProjectKey;

  /// 仅作来源追踪；导入列表/详情不展示。
  final String contactSnapshot;
  final String siteSnapshot;

  Map<String, Object?> toMap() {
    return {
      'source_project_id': sourceProjectId,
      'source_project_key': sourceProjectKey,
      'contact_snapshot': contactSnapshot,
      'site_snapshot': siteSnapshot,
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
    required this.isBreaking,
    required this.originFingerprint,
    this.filledCalculation,
  });

  /// 无原生 uuid：使用带命名空间的来源 id，格式 `timing:{sourceTimingRecordId}`。
  final String sourceRecordUuid;
  final int sourceTimingRecordId;
  final String sourceProjectId;
  final int sourceDeviceId;
  final int workDate;

  /// 'hours' / 'rent'。
  final String type;

  /// rent/台班无有效码表时为 null，不填 0。
  final double? startMeter;
  final double? endMeter;
  final int hoursMilli;

  /// 始终来自 TimingRecord.income，真实收入，不按工时×单价重算。
  final int incomeFen;
  final bool isBreaking;
  final String originFingerprint;
  final ProjectExternalWorkShareFilledCalculation? filledCalculation;

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
