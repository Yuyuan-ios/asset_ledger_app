import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/money/amount_policy.dart';
import '../../models/device.dart';
import '../../models/project_device_rate.dart';
import '../../models/timing_calculation_history.dart';
import '../../models/timing_record.dart';
import '../../services/account_service.dart';
import 'project_external_work_share_rich_payload.dart';

/// 纯数据 builder：把项目下的 TimingRecord / Device / TimingCalculationHistory
/// 转成 project_external_work_share v1 富 payload。
///
/// 纯函数：不读 DeviceStore / DB / clock，所有输入经参数注入，输出确定。
/// 不写文件、不计算 envelope/payloadSha256（属既有/5C）。
class ProjectExternalWorkShareBuilder {
  const ProjectExternalWorkShareBuilder();

  /// [records]            该项目下的全部 TimingRecord（必须非空，且每条 id 非空）。
  /// [deviceMap]          deviceId -> Device。
  /// [calcHistoryMap]     timingRecordId -> 该记录的计算历史（顺序不限，内部按
  ///                      createdAt 取最新一条作为 filledCalculation）。
  /// [projectDeviceRates] 全量项目设备覆盖单价；rich record `source_unit_price_fen`
  ///                      用此还原"按当前项目+isBreaking 解析后的有效单价"再过
  ///                      AmountPolicy 校验，确保项目覆盖价（如 200）能被写入。
  ///                      为空表示该项目不存在任何覆盖，回落到设备默认单价。
  /// [projectReceivedFen] 该项目累计实收款（分），随项目快照进入分享包。
  /// [memberProjectIds]   合并分享场景的成员项目 id 集合。非空表示合并分享：
  ///                      records[] 允许跨集合内多个成员项目（但仍拒绝集合外的
  ///                      无关项目），并输出 member_projects[] 与聚合展示名；
  ///                      为空表示普通单项目分享，沿用单项目断言与口径。
  ProjectExternalWorkShareRichPayload build({
    required String shareId,
    required String senderName,
    required String sourceInstallationUuid,
    required List<TimingRecord> records,
    required Map<int, Device> deviceMap,
    required Map<int, List<TimingCalculationHistory>> calcHistoryMap,
    List<ProjectDeviceRate> projectDeviceRates = const [],
    String? expectedProjectId,
    Set<String> memberProjectIds = const {},
    int projectReceivedFen = 0,
  }) {
    final safeShareId = _requireNonBlank(shareId, 'shareId');
    final safeSenderName = _requireNonBlank(senderName, 'senderName');
    final safeInstallationUuid = _requireNonBlank(
      sourceInstallationUuid,
      'sourceInstallationUuid',
    );
    if (records.isEmpty) {
      throw ArgumentError.value(records, 'records', 'must not be empty');
    }

    // 防御调用方误把无关项目的记录混进同一个分享包：显式失败，不静默过滤
    // （静默过滤会让用户误以为已完整导出）。
    final memberSet = memberProjectIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    final isMerged = memberSet.isNotEmpty;
    final projectIds = records.map((r) => r.effectiveProjectId).toSet();
    if (isMerged) {
      // 合并分享：允许 records 跨成员项目，但只允许 memberProjectIds 内的项目；
      // 真正无关项目混入仍显式失败。
      final unrelated = projectIds.difference(memberSet);
      if (unrelated.isNotEmpty) {
        throw ArgumentError.value(
          records,
          'records',
          'records contain non-member projects: $unrelated',
        );
      }
    } else {
      if (projectIds.length > 1) {
        throw ArgumentError.value(
          records,
          'records',
          'records span multiple projects: $projectIds',
        );
      }
      final expected = expectedProjectId?.trim() ?? '';
      if (expected.isNotEmpty && projectIds.first != expected) {
        throw ArgumentError.value(
          records,
          'records',
          'records project ${projectIds.first} != expected $expected',
        );
      }
    }

    // 稳定排序：先 workDate(startDate)，再 timingRecordId。
    final sorted = [...records]
      ..sort((a, b) {
        final byDate = a.startDate.compareTo(b.startDate);
        if (byDate != 0) return byDate;
        return _requireId(a).compareTo(_requireId(b));
      });

    // 每条记录按「它自己的项目 + isBreaking」解析当前有效单价。
    // 与账户页 / TimingPreviewIncome 同源（AccountService.buildEffectiveRateMap），
    // 自动应用项目对设备的单价覆盖；不存在覆盖时回落到设备默认单价。
    // 合并分享下各成员项目可能有各自覆盖价，故按项目缓存、逐条解析。
    final deviceList = deviceMap.values.toList(growable: false);
    final rateMapCache = <String, Map<int, double>>{};
    double? effectiveRateYuanFor(TimingRecord r) {
      final cacheKey = '${r.effectiveProjectId}|${r.isBreaking}';
      final map = rateMapCache.putIfAbsent(
        cacheKey,
        () => AccountService.buildEffectiveRateMap(
          projectId: r.effectiveProjectId,
          projectKey: r.legacyProjectKey,
          devices: deviceList,
          rates: projectDeviceRates,
          isBreaking: r.isBreaking,
        ),
      );
      return map[r.deviceId];
    }

    final shareRecords = <ProjectExternalWorkShareRecord>[];
    final exportLines = <ProjectExternalWorkShareExportLine>[];
    for (final record in sorted) {
      final recordId = _requireId(record);
      final hoursMilli = WorkHours.fromHours(record.hours).milliHours;
      final isHours = record.type == TimingType.hours;

      // originFingerprint 用原始来源金额：保持来源身份稳定（与历史包一致），
      // 不随单价口径重算而漂移。
      final originalIncomeFen = Money.fromYuan(record.income).fen;
      final fingerprint = _originFingerprint(
        record,
        hoursMilli,
        originalIncomeFen,
      );

      // 普通 hours：采信「当前有效项目单价（含项目覆盖）」，并按该单价重算导出
      // 金额——即使本机 TimingRecord.income 仍是旧单价口径，也不显示"未知"。
      // rent / 台班 / 人工覆写金额 / 无法确认单价：单价 null + 原始来源金额。
      // 全程不做 income÷hours 反推。
      final resolved = _resolveExportAmount(
        record: record,
        hoursMilli: hoursMilli,
        isHours: isHours,
        device: deviceMap[record.deviceId],
        currentRateYuanPerHour: effectiveRateYuanFor(record),
      );

      shareRecords.add(
        ProjectExternalWorkShareRecord(
          sourceRecordUuid: _sourceRecordUuid(recordId),
          sourceTimingRecordId: recordId,
          sourceProjectId: record.effectiveProjectId,
          sourceDeviceId: record.deviceId,
          workDate: record.startDate,
          type: record.type.name,
          // rent/台班无有效码表：start/end 留 null，不填 0。
          startMeter: isHours ? record.startMeter : null,
          endMeter: isHours ? record.endMeter : null,
          hoursMilli: hoursMilli,
          incomeFen: resolved.incomeFen,
          sourceUnitPriceFen: resolved.unitPriceFen,
          isBreaking: record.isBreaking,
          originFingerprint: fingerprint,
          filledCalculation: _filledCalculation(
            recordId,
            calcHistoryMap[recordId],
          ),
        ),
      );

      final exportLine = _tryBuildExportLine(
        record: record,
        recordId: recordId,
        hoursMilli: hoursMilli,
        incomeFen: resolved.incomeFen,
        fingerprint: fingerprint,
        device: deviceMap[record.deviceId],
        isHours: isHours,
      );
      if (exportLine != null) exportLines.add(exportLine);
    }

    final deviceIds = sorted.map((r) => r.deviceId).toSet();
    final totalHoursMilli = shareRecords.fold<int>(
      0,
      (sum, r) => sum + r.hoursMilli,
    );
    final totalIncomeFen = shareRecords.fold<int>(
      0,
      (sum, r) => sum + r.incomeFen,
    );

    final first = sorted.first;
    // 合并分享：项目快照用聚合身份 + 「分享人 · 地址摘要」展示名；
    // 普通分享：沿用单项目 contact/site，displayName 留 null。
    final sitesSummary = isMerged ? _sitesSummary(sorted) : first.site;
    final snapshotProjectId = isMerged
        ? ((expectedProjectId?.trim().isNotEmpty ?? false)
              ? expectedProjectId!.trim()
              : 'merge')
        : first.effectiveProjectId;
    final snapshotProjectKey = isMerged
        ? snapshotProjectId
        : first.legacyProjectKey;
    final snapshotDisplayName = isMerged
        ? '$safeSenderName · $sitesSummary'
        : null;

    return ProjectExternalWorkShareRichPayload(
      shareId: safeShareId,
      senderName: safeSenderName,
      sourceInstallationUuid: safeInstallationUuid,
      protocolVersion:
          ProjectExternalWorkShareRichPayload.currentProtocolVersion,
      fingerprintVersion:
          ProjectExternalWorkShareRichPayload.currentFingerprintVersion,
      summary: ProjectExternalWorkShareSummary(
        deviceCount: deviceIds.length,
        recordCount: shareRecords.length,
        totalIncomeFen: totalIncomeFen,
        totalHoursMilli: totalHoursMilli,
      ),
      projectSnapshot: ProjectExternalWorkShareProjectSnapshot(
        sourceProjectId: snapshotProjectId,
        sourceProjectKey: snapshotProjectKey,
        contactSnapshot: first.contact,
        siteSnapshot: sitesSummary,
        displayName: snapshotDisplayName,
        projectReceivedFen: projectReceivedFen < 0 ? 0 : projectReceivedFen,
      ),
      devices: _buildDevices(sorted, shareRecords, deviceMap),
      records: shareRecords,
      deviceGroups: _buildDeviceGroups(sorted, shareRecords),
      exportLines: exportLines,
      memberProjects: isMerged ? _buildMemberProjects(sorted) : const [],
    );
  }

  static String _sourceRecordUuid(int timingRecordId) =>
      'timing:$timingRecordId';

  // 来源指纹：稳定字段整数归一化后 sha256(hex)。导入端只比对、不重算，
  // 字段顺序与口径在此固化，禁止随意调整。fingerprint_version 仍为 1：
  // 算法仍是首个真实发布版（无任何已发布/已导入数据依赖旧 rent 口径），
  // 故不升版本。
  // 顺序：sourceProjectKey | deviceId | workDate | startMeterMilli |
  //       endMeterMilli | hoursMilli | incomeFen | type | isBreaking(0/1)
  // 码表口径：使用「导出后规范字段」参与指纹——hours 用千分整数码表；
  // rent/台班导出 start/end_meter 为 null，故指纹中按空串归一化，
  // 不泄漏 UI 不展示的内部 meter 值（有意设计，由测试锁定）。
  static String _originFingerprint(
    TimingRecord record,
    int hoursMilli,
    int incomeFen,
  ) {
    final isHours = record.type == TimingType.hours;
    final startMeterToken = isHours
        ? (record.startMeter * 1000).round().toString()
        : '';
    final endMeterToken = isHours
        ? (record.endMeter * 1000).round().toString()
        : '';
    final canonical = [
      record.legacyProjectKey,
      record.deviceId,
      record.startDate,
      startMeterToken,
      endMeterToken,
      hoursMilli,
      incomeFen,
      record.type.name,
      record.isBreaking ? 1 : 0,
    ].join('|');
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  static ProjectExternalWorkShareFilledCalculation? _filledCalculation(
    int recordId,
    List<TimingCalculationHistory>? histories,
  ) {
    if (histories == null || histories.isEmpty) return null;
    // 防御性过滤：即便入参 map 误装(misbucket)了别的记录历史，也只认
    // timingRecordId == 当前记录 的条目。
    final bound = histories
        .where((h) => h.timingRecordId == recordId)
        .toList(growable: false);
    if (bound.isEmpty) return null;
    // 取 createdAt 最新一条；createdAt 相同则取 id 字典序较大的一条，
    // 保证确定性（与入参顺序无关）。
    final latest = bound.reduce((a, b) {
      if (a.createdAt.isAfter(b.createdAt)) return a;
      if (b.createdAt.isAfter(a.createdAt)) return b;
      return a.id.compareTo(b.id) >= 0 ? a : b;
    });
    return ProjectExternalWorkShareFilledCalculation(
      calculatedAt: latest.createdAt.toIso8601String(),
      expression: latest.expression,
      result: latest.result,
      ticketCount: latest.ticketCount,
      resultMilliHours: WorkHours.fromHours(latest.result).milliHours,
      resultDisplay: '${latest.result.toStringAsFixed(1)} h',
    );
  }

  // 旧导入端兼容行准入：仅 hours、hoursMilli>0、contact/site 非空，且能得到
  // 单价使 AmountPolicy(hoursMilli, unitPriceFen) == 真实 incomeFen。
  // 不满足者只进富 records[]，不进 export_lines[]，绝不伪造金额。
  static ProjectExternalWorkShareExportLine? _tryBuildExportLine({
    required TimingRecord record,
    required int recordId,
    required int hoursMilli,
    required int incomeFen,
    required String fingerprint,
    required Device? device,
    required bool isHours,
  }) {
    if (!isHours || hoursMilli <= 0 || incomeFen < 0) return null;
    if (record.contact.trim().isEmpty || record.site.trim().isEmpty) {
      return null;
    }

    final unitPriceFen = _resolveUnitPriceFen(
      device: device,
      isBreaking: record.isBreaking,
      hoursMilli: hoursMilli,
      incomeFen: incomeFen,
    );
    if (unitPriceFen == null) return null;

    return ProjectExternalWorkShareExportLine(
      exportLineUuid: _sourceRecordUuid(recordId),
      originFingerprint: fingerprint,
      contactSnapshot: record.contact,
      siteSnapshot: record.site,
      equipmentBrand: device?.brand,
      equipmentModel: device?.model,
      equipmentType: device?.equipmentType.dbValue,
      workDate: record.startDate,
      hoursMilli: hoursMilli,
      sourceUnitPriceFen: unitPriceFen,
      // 准入已保证恒等，amountFen 即真实 incomeFen，非近似。
      amountFen: incomeFen,
      note: null,
    );
  }

  // 富 records 专用：决定导出的 source_unit_price_fen 与 income_fen。
  //
  // 规则（与导入端协议一致，全程不做 income÷hours 反推）：
  // - 非 hours / 工时<=0 / 设备缺失 / 无当前有效单价 / 单价<=0：
  //     单价 = null，金额 = 原始来源金额（TimingRecord.income）。
  // - hours 且来源金额已与「当前有效项目单价」一致：直接采信，金额不变。
  // - hours 且来源金额仍是「设备默认单价」旧口径（单价被改过、income 未回写）：
  //     采信当前有效单价，并按当前单价**重算**导出金额（修正陈旧口径，
  //     避免接收端把已改价记录显示成"未知"）。
  // - 其余（人工覆写金额 / 无法用任一已知单价解释）：单价 = null，
  //     金额 = 原始来源金额，绝不伪造。
  static _ResolvedExportAmount _resolveExportAmount({
    required TimingRecord record,
    required int hoursMilli,
    required bool isHours,
    required Device? device,
    required double? currentRateYuanPerHour,
  }) {
    final originalIncomeFen = Money.fromYuan(record.income).fen;
    if (!isHours ||
        hoursMilli <= 0 ||
        device == null ||
        currentRateYuanPerHour == null) {
      return _ResolvedExportAmount(
        unitPriceFen: null,
        incomeFen: originalIncomeFen,
      );
    }

    final currentFen = UnitPrice.fromYuanPerHour(
      currentRateYuanPerHour,
    ).fenPerHour;
    if (currentFen <= 0) {
      return _ResolvedExportAmount(
        unitPriceFen: null,
        incomeFen: originalIncomeFen,
      );
    }

    // 来源金额已与当前有效单价一致：采信，金额不变。
    if (_amountFen(hoursMilli, currentFen) == originalIncomeFen) {
      return _ResolvedExportAmount(
        unitPriceFen: currentFen,
        incomeFen: originalIncomeFen,
      );
    }

    // 来源金额仍可由「设备默认单价」解释（典型：改了项目覆盖价但 income 未回写）：
    // 采信当前有效单价，并按当前单价重算导出金额。
    final deviceDefaultYuan = (record.isBreaking)
        ? (device.breakingUnitPrice ?? device.defaultUnitPrice)
        : device.defaultUnitPrice;
    final deviceFen = UnitPrice.fromYuanPerHour(deviceDefaultYuan).fenPerHour;
    if (deviceFen > 0 && _amountFen(hoursMilli, deviceFen) == originalIncomeFen) {
      return _ResolvedExportAmount(
        unitPriceFen: currentFen,
        incomeFen: _amountFen(hoursMilli, currentFen),
      );
    }

    // 人工覆写金额 / 无法确认单价：单价 null，保留原始来源金额。
    return _ResolvedExportAmount(
      unitPriceFen: null,
      incomeFen: originalIncomeFen,
    );
  }

  // 合并分享：地址摘要（如「鲜滩+尚义...」）。
  static String _sitesSummary(List<TimingRecord> sorted) {
    final unique = <String>[];
    for (final r in sorted) {
      final site = r.site.trim();
      if (site.isEmpty || unique.contains(site)) continue;
      unique.add(site);
    }
    if (unique.isEmpty) return '';
    if (unique.length <= 2) return unique.join('+');
    return '${unique.take(2).join('+')}...';
  }

  static String _memberDisplayName(String contact, String site) {
    final c = contact.trim();
    final s = site.trim();
    if (c.isEmpty) return s;
    if (s.isEmpty) return c;
    return '$c · $s';
  }

  // 合并分享：按成员项目分组，输出 member_projects[]（保序、确定性）。
  static List<ProjectExternalWorkShareMemberProject> _buildMemberProjects(
    List<TimingRecord> sorted,
  ) {
    final byProject = <String, List<TimingRecord>>{};
    for (final r in sorted) {
      byProject.putIfAbsent(r.effectiveProjectId, () => []).add(r);
    }
    return byProject.entries.map((entry) {
      final records = entry.value;
      final firstRecord = records.first;
      return ProjectExternalWorkShareMemberProject(
        sourceProjectId: entry.key,
        sourceProjectKey: firstRecord.legacyProjectKey,
        contactSnapshot: firstRecord.contact,
        siteSnapshot: firstRecord.site,
        displayName: _memberDisplayName(firstRecord.contact, firstRecord.site),
        recordIds: records.map(_requireIdStatic).toList(growable: false),
      );
    }).toList(growable: false);
  }

  // 优先用设备真实单价；不一致再用 incomeFen/hoursMilli 反推，反推后必须再过
  // AmountPolicy 且结果等于真实 incomeFen，否则返回 null（不改 amountFen）。
  static int? _resolveUnitPriceFen({
    required Device? device,
    required bool isBreaking,
    required int hoursMilli,
    required int incomeFen,
  }) {
    if (device != null) {
      final yuanPerHour = (isBreaking && device.breakingUnitPrice != null)
          ? device.breakingUnitPrice!
          : device.defaultUnitPrice;
      final deviceFen = UnitPrice.fromYuanPerHour(yuanPerHour).fenPerHour;
      if (deviceFen >= 0 && _amountFen(hoursMilli, deviceFen) == incomeFen) {
        return deviceFen;
      }
    }
    final derived = (incomeFen * 1000 / hoursMilli).round();
    if (derived >= 0 && _amountFen(hoursMilli, derived) == incomeFen) {
      return derived;
    }
    return null;
  }

  static int _amountFen(int hoursMilli, int unitPriceFen) {
    return AmountPolicy.calculateAmount(
      hours: WorkHours(hoursMilli),
      unitPrice: UnitPrice(unitPriceFen),
    ).fen;
  }

  static List<ProjectExternalWorkShareDeviceSnapshot> _buildDevices(
    List<TimingRecord> sorted,
    List<ProjectExternalWorkShareRecord> shareRecords,
    Map<int, Device> deviceMap,
  ) {
    final byDevice = <int, List<ProjectExternalWorkShareRecord>>{};
    for (final r in shareRecords) {
      byDevice.putIfAbsent(r.sourceDeviceId, () => []).add(r);
    }
    final deviceIds = byDevice.keys.toList()..sort();
    return deviceIds
        .map((deviceId) {
          final group = byDevice[deviceId]!;
          final device = deviceMap[deviceId];
          return ProjectExternalWorkShareDeviceSnapshot(
            sourceDeviceId: deviceId,
            name: device?.name ?? '',
            brand: device?.brand ?? '',
            model: device?.model,
            type: device?.equipmentType.dbValue,
            displayName: device?.name ?? '',
            recordCount: group.length,
            totalHoursMilli: group.fold<int>(0, (s, r) => s + r.hoursMilli),
            totalIncomeFen: group.fold<int>(0, (s, r) => s + r.incomeFen),
          );
        })
        .toList(growable: false);
  }

  static List<ProjectExternalWorkShareDeviceGroup> _buildDeviceGroups(
    List<TimingRecord> sorted,
    List<ProjectExternalWorkShareRecord> shareRecords,
  ) {
    // sorted 已按 (workDate, id) 稳定排序；按设备保序分组。
    final byDevice = <int, List<TimingRecord>>{};
    for (final r in sorted) {
      byDevice.putIfAbsent(r.deviceId, () => []).add(r);
    }
    final recordById = {
      for (final r in shareRecords) r.sourceTimingRecordId: r,
    };
    final deviceIds = byDevice.keys.toList()..sort();
    return deviceIds
        .map((deviceId) {
          final groupRecords = byDevice[deviceId]!;
          final shareGroup = groupRecords
              .map((r) => recordById[_requireIdStatic(r)]!)
              .toList(growable: false);
          final totalHoursMilli = shareGroup.fold<int>(
            0,
            (s, r) => s + r.hoursMilli,
          );
          final totalIncomeFen = shareGroup.fold<int>(
            0,
            (s, r) => s + r.incomeFen,
          );

          // 码表跨度仅对 hours 型有效记录计算；混入 rent 时仍按 spec 用组 total
          // hours 求误差（rent 工时一并计入，已在文档口径内）。
          final hoursOnly = groupRecords
              .where((r) => r.type == TimingType.hours)
              .toList(growable: false);
          double? firstStartMeter;
          double? lastEndMeter;
          int? meterSpanMilli;
          int? meterErrorMilli;
          if (hoursOnly.isNotEmpty) {
            firstStartMeter = hoursOnly.first.startMeter;
            lastEndMeter = hoursOnly.last.endMeter;
            final spanMilli =
                (lastEndMeter * 1000).round() -
                (firstStartMeter * 1000).round();
            meterSpanMilli = spanMilli;
            meterErrorMilli = (spanMilli - totalHoursMilli).abs();
          }

          return ProjectExternalWorkShareDeviceGroup(
            sourceDeviceId: deviceId,
            recordIds: groupRecords
                .map(_requireIdStatic)
                .toList(growable: false),
            recordCount: groupRecords.length,
            firstStartMeter: firstStartMeter,
            lastEndMeter: lastEndMeter,
            totalHoursMilli: totalHoursMilli,
            totalIncomeFen: totalIncomeFen,
            meterSpanMilli: meterSpanMilli,
            meterErrorMilli: meterErrorMilli,
          );
        })
        .toList(growable: false);
  }

  int _requireId(TimingRecord record) => _requireIdStatic(record);

  static int _requireIdStatic(TimingRecord record) {
    final id = record.id;
    if (id == null) {
      throw ArgumentError.value(
        record,
        'records',
        'TimingRecord.id is required to build a stable share record',
      );
    }
    return id;
  }

  static String _requireNonBlank(String value, String name) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, name, 'must not be blank');
    }
    return value;
  }
}

/// 单条 hours/rent 记录导出时解析出的「单价 + 导出金额」。
/// [unitPriceFen] 为 null 表示协议口径下的"未知"（绝不伪造 0）。
class _ResolvedExportAmount {
  const _ResolvedExportAmount({
    required this.unitPriceFen,
    required this.incomeFen,
  });

  final int? unitPriceFen;
  final int incomeFen;
}
