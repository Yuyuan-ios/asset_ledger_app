import '../../../core/utils/format_utils.dart';
import '../../../data/models/external_work_record.dart';
import '../../account/model/project_title_formatter.dart';
import '../../../tokens/mapper/account_tokens.dart';
import '../state/timing_external_work_store.dart';

/// 阶段 C Step 7：外协项目记录列表的"分组 / 标题 fallback / 状态 / 摘要"
/// 展示业务判断从 pattern 上移到此处（feature 层 view-model builder）。
///
/// 该 builder 是纯函数式只读映射：输入 [TimingExternalWorkRecordItem] 列表，
/// 输出可直接渲染的 VM。不读写数据库、不碰导入协议、不做关联写操作。
///
/// 注意位置：放在 `features/timing/view_models/` 而非 `presentation/`，
/// 因为架构 lint 禁止 `features/<x>/(view|presentation)/` 直接 import `lib/data`，
/// 而该 builder 需要消费 data/models（ExternalWorkRecord）。view_models 目录
/// 不在该 lint 的 presentation 判定内。
class ExternalWorkRecordsVm {
  const ExternalWorkRecordsVm({required this.yearGroups});

  final List<ExternalWorkYearGroupVm> yearGroups;

  bool get isEmpty => yearGroups.isEmpty;
}

class ExternalWorkYearGroupVm {
  const ExternalWorkYearGroupVm({
    required this.year,
    required this.sourceGroups,
  });

  final int year;
  final List<ExternalWorkSourceGroupVm> sourceGroups;
}

class ExternalWorkSourceGroupVm {
  const ExternalWorkSourceGroupVm({required this.packages});

  final List<ExternalWorkPackageVm> packages;
}

/// 一个外协包（按 import batch 聚合）的展示摘要。
class ExternalWorkPackageVm {
  const ExternalWorkPackageVm({
    required this.key,
    required this.isAggregate,
    required this.recordCount,
    required this.title,
    required this.equipmentSummaryMain,
    required this.equipmentSummarySuffix,
    required this.recordCountLabel,
    required this.dateText,
    required this.hoursText,
    required this.hasLinkedRecord,
    required this.representativeItem,
    required this.childRows,
  });

  final String key;
  final bool isAggregate;
  final int recordCount;

  /// 包标题：分享人 · 工地（fallback 规则见 builder）。
  final String title;

  /// 设备摘要主文本（如 "Hitachi"）。
  final String equipmentSummaryMain;

  /// 设备摘要后缀（如 "等2台"），无则 null。
  final String? equipmentSummarySuffix;

  /// 记录数标签（聚合时 "•N条记录"，否则 null）。
  final String? recordCountLabel;

  /// 起始工作日期文本。
  final String dateText;

  /// 总工时文本。
  final String hoursText;

  /// 包内是否存在已关联记录。
  final bool hasLinkedRecord;

  /// 点击该包打开详情时的代表记录。
  final TimingExternalWorkRecordItem representativeItem;

  /// 展开后的子记录行（已按展示顺序排好）。
  final List<ExternalWorkRecordRowVm> childRows;
}

/// 单条外协子记录行的展示摘要。
class ExternalWorkRecordRowVm {
  const ExternalWorkRecordRowVm({
    required this.item,
    required this.title,
    required this.subtitle,
    required this.dateText,
    required this.hoursText,
    required this.isLinked,
  });

  final TimingExternalWorkRecordItem item;
  final String title;
  final String subtitle;
  final String dateText;
  final String hoursText;
  final bool isLinked;
}

/// 外协记录详情卡片的展示 VM（阶段 C Step 8）。
///
/// 把详情卡片原先散落在 pattern 里的格式化 / 状态 / fallback 判断
/// （site / equipment / 单价 / 金额 / 工时 / 状态 / 导入时间）收口到此处。
class ExternalWorkRecordDetailVm {
  const ExternalWorkRecordDetailVm({
    required this.sourceText,
    required this.sourceNameText,
    required this.siteText,
    required this.equipmentText,
    required this.workDateText,
    required this.hoursText,
    required this.sourceUnitPriceText,
    required this.amountText,
    required this.showProjectReceived,
    required this.projectReceivedText,
    required this.importedAtText,
    required this.statusText,
    required this.isLinked,
  });

  /// 固定来源说明文案（"从分享包导入"）。
  final String sourceText;
  final String sourceNameText;
  final String siteText;
  final String equipmentText;
  final String workDateText;
  final String hoursText;
  final String sourceUnitPriceText;
  final String amountText;
  final bool showProjectReceived;
  final String projectReceivedText;
  final String importedAtText;
  final String statusText;
  final bool isLinked;
}

/// 外协记录列表的展示 VM builder（纯只读）。
class ExternalWorkRecordsViewModelBuilder {
  const ExternalWorkRecordsViewModelBuilder._();

  /// 构建外协记录详情卡片 VM。
  ///
  /// [item] 是被点击的代表记录；[packageItems] 是同包记录（用于汇总地址 /
  /// 来源单价）。展示金额 / 工时 / 状态以代表记录 [item] 为准（与原 pattern
  /// 行为一致）。
  static ExternalWorkRecordDetailVm buildDetail({
    required TimingExternalWorkRecordItem item,
    List<TimingExternalWorkRecordItem>? packageItems,
  }) {
    final record = item.record;
    final detailItems = packageItems ?? [item];
    final records = detailItems.map((each) => each.record);
    return ExternalWorkRecordDetailVm(
      sourceText: '从分享包导入',
      sourceNameText: item.displayName,
      siteText: _detailSiteText(detailItems),
      equipmentText: _detailEquipmentText(record),
      workDateText: FormatUtils.date(record.workDate),
      hoursText: _hoursText(record.hoursMilli),
      sourceUnitPriceText: _sourceUnitPriceText(records),
      amountText: _moneyFen(record.amountFen),
      showProjectReceived: record.projectReceivedFen > 0,
      projectReceivedText: _moneyFen(record.projectReceivedFen),
      importedAtText: _blankFallback(
        item.batch?.importedAt ?? record.createdAt,
      ),
      statusText: _statusText(record),
      isLinked: detailItems.any((each) => each.isLinked),
    );
  }

  static ExternalWorkRecordsVm build(
    List<TimingExternalWorkRecordItem> items,
  ) {
    if (items.isEmpty) {
      return const ExternalWorkRecordsVm(yearGroups: []);
    }
    return ExternalWorkRecordsVm(yearGroups: _buildYearGroups(items));
  }

  /// 所有可聚合（batch）包的 key 集合，供 UI 维护展开状态。
  static Set<String> aggregateKeys(List<TimingExternalWorkRecordItem> items) {
    return _buildBatchGroups(items).map((group) => group.key).toSet();
  }

  /// 顶层包数量。
  static int topLevelCount(List<TimingExternalWorkRecordItem> items) {
    return _buildBatchGroups(items).length;
  }

  static List<ExternalWorkYearGroupVm> _buildYearGroups(
    List<TimingExternalWorkRecordItem> items,
  ) {
    final batchGroups = _buildBatchGroups(items);
    final grouped = <int, List<_BatchGroup>>{};
    for (final group in batchGroups) {
      grouped.putIfAbsent(group.year, () => <_BatchGroup>[]).add(group);
    }

    final yearGroups = [
      for (final entry in grouped.entries)
        ExternalWorkYearGroupVm(
          year: entry.key,
          sourceGroups: _buildSourceGroups(entry.value),
        ),
    ]..sort((a, b) => b.year.compareTo(a.year));
    return yearGroups;
  }

  static List<ExternalWorkSourceGroupVm> _buildSourceGroups(
    List<_BatchGroup> groups,
  ) {
    final grouped = <String, List<_BatchGroup>>{};
    for (final group in groups) {
      grouped.putIfAbsent(_sourceGroupKey(group.displayName), () => []).add(
        group,
      );
    }

    return [
      for (final entry in grouped.entries)
        ExternalWorkSourceGroupVm(
          packages: [for (final group in entry.value) group.toVm()],
        ),
    ];
  }

  static String _sourceGroupKey(String displayName) {
    final normalized = displayName.trim();
    return normalized.isEmpty ? '-' : normalized;
  }

  static List<_BatchGroup> _buildBatchGroups(
    List<TimingExternalWorkRecordItem> items,
  ) {
    final grouped = <String, List<TimingExternalWorkRecordItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(_batchKey(item), () => []).add(item);
    }

    final groups = <_BatchGroup>[];
    for (final entry in grouped.entries) {
      groups.add(_BatchGroup.fromItems(entry.key, entry.value));
    }

    groups.sort((a, b) {
      final byImportedAt = b.importedAtSort.compareTo(a.importedAtSort);
      if (byImportedAt != 0) return byImportedAt;
      final byImportedText = b.importedAt.compareTo(a.importedAt);
      if (byImportedText != 0) return byImportedText;
      return a.key.compareTo(b.key);
    });
    return groups;
  }

  static String _batchKey(TimingExternalWorkRecordItem item) {
    final batchId = item.record.importBatchId.trim();
    return batchId.isEmpty ? 'external-${item.record.id}' : 'batch-$batchId';
  }
}

/// 内部聚合中间体（不对外暴露）。负责承载分组计算结果并映射成 VM。
class _BatchGroup {
  _BatchGroup._({
    required this.key,
    required this.items,
    required this.displayName,
    required this.siteSummary,
    required this.equipmentSummaryMain,
    this.equipmentSummarySuffix,
    required this.startWorkDate,
    required this.year,
    required this.importedAt,
    required this.importedAtSort,
    required this.totalHoursMilli,
    required this.hasLinkedRecord,
  });

  final String key;
  final List<TimingExternalWorkRecordItem> items;
  final String displayName;
  final String siteSummary;
  final String equipmentSummaryMain;
  final String? equipmentSummarySuffix;
  final int startWorkDate;
  final int year;
  final String importedAt;
  final int importedAtSort;
  final int totalHoursMilli;
  final bool hasLinkedRecord;

  bool get isAggregate => items.length > 1;

  factory _BatchGroup.fromItems(
    String key,
    List<TimingExternalWorkRecordItem> items,
  ) {
    final sortedItems = [...items]
      ..sort((a, b) {
        final byDate = a.record.workDate.compareTo(b.record.workDate);
        if (byDate != 0) return byDate;
        return a.record.createdAt.compareTo(b.record.createdAt);
      });
    final first = sortedItems.first;
    final importedAt = _importedAtText(first);
    final equipmentSummary = _equipmentSummary(sortedItems);
    return _BatchGroup._(
      key: key,
      items: sortedItems,
      displayName: first.displayName,
      siteSummary: _siteSummaryText(sortedItems, first.batch?.siteSummary),
      equipmentSummaryMain: equipmentSummary.main,
      equipmentSummarySuffix: equipmentSummary.suffix,
      startWorkDate: sortedItems.first.record.workDate,
      year: _groupYear(sortedItems.first.record.workDate, importedAt),
      importedAt: importedAt,
      importedAtSort: _isoSortValue(importedAt),
      totalHoursMilli: sortedItems.fold<int>(
        0,
        (sum, item) => sum + item.record.hoursMilli,
      ),
      hasLinkedRecord: sortedItems.any((item) => item.isLinked),
    );
  }

  ExternalWorkPackageVm toVm() {
    return ExternalWorkPackageVm(
      key: key,
      isAggregate: isAggregate,
      recordCount: items.length,
      title: _externalWorkTitle(displayName, siteSummary),
      equipmentSummaryMain: equipmentSummaryMain,
      equipmentSummarySuffix: equipmentSummarySuffix,
      recordCountLabel: isAggregate ? '•${items.length}条记录' : null,
      dateText: FormatUtils.date(startWorkDate),
      hoursText: _hoursText(totalHoursMilli),
      hasLinkedRecord: hasLinkedRecord,
      representativeItem: items.first,
      childRows: [
        for (final item in items.reversed)
          ExternalWorkRecordRowVm(
            item: item,
            title: _externalWorkTitle(
              item.displayName,
              _blankFallback(item.record.siteSnapshot),
            ),
            subtitle: _rowEquipmentText(item.record),
            dateText: FormatUtils.date(item.record.workDate),
            hoursText: _hoursText(item.record.hoursMilli),
            isLinked: item.isLinked,
          ),
      ],
    );
  }
}

String _externalWorkTitle(String displayName, String site) {
  final normalizedName = displayName.trim();
  final normalizedSite = site.trim();
  return ProjectTitleFormatter.project(
    contact: normalizedName,
    site: normalizedSite,
  );
}

String _importedAtText(TimingExternalWorkRecordItem item) {
  final batchImportedAt = item.batch?.importedAt.trim();
  if (batchImportedAt != null && batchImportedAt.isNotEmpty) {
    return batchImportedAt;
  }
  final batchCreatedAt = item.batch?.createdAt.trim();
  if (batchCreatedAt != null && batchCreatedAt.isNotEmpty) {
    return batchCreatedAt;
  }
  return item.record.createdAt;
}

int _isoSortValue(String text) {
  return DateTime.tryParse(text)?.millisecondsSinceEpoch ?? 0;
}

int _groupYear(int workDate, String fallbackDateTime) {
  final workYear = workDate ~/ 10000;
  if (workYear >= 1900 && workYear <= 9999) return workYear;
  return DateTime.tryParse(fallbackDateTime)?.year ?? workYear;
}

String _siteSummaryText(
  List<TimingExternalWorkRecordItem> items,
  String? batchSiteSummary,
) {
  final sites = <String>[];
  for (final item in items) {
    final site = _visibleSiteText(item.record.siteSnapshot);
    if (site.isNotEmpty && !sites.contains(site)) sites.add(site);
  }
  if (sites.isEmpty) {
    final batchSite = _visibleSiteText(batchSiteSummary ?? '');
    if (batchSite.isNotEmpty) sites.add(_displaySiteSummary(batchSite));
  }
  if (sites.isEmpty) return '';

  final joined = sites.join('、');
  const maxChars = AccountTokens.projectCardMergedSitesPreviewMaxChars;
  if (joined.length <= maxChars) return joined;
  return '${joined.substring(0, maxChars)}...';
}

String _visibleSiteText(String text) {
  final trimmed = text.trim();
  if (RegExp(r'^合并\d+项目$').hasMatch(trimmed)) return '';
  return trimmed;
}

String _displaySiteSummary(String value) {
  return value.trim().replaceAll('+', '、').replaceAll('•', '、');
}

_EquipmentSummary _equipmentSummary(List<TimingExternalWorkRecordItem> items) {
  final devices = <String>[];
  for (final item in items) {
    final device = _deviceSummaryName(item.record);
    if (device.isNotEmpty && !devices.contains(device)) devices.add(device);
  }
  if (devices.isEmpty) return const _EquipmentSummary(main: '设备未填写');
  if (devices.length == 1) return _EquipmentSummary(main: devices.first);
  return _EquipmentSummary(main: devices.first, suffix: '等${devices.length}台');
}

class _EquipmentSummary {
  const _EquipmentSummary({required this.main, this.suffix});

  final String main;
  final String? suffix;
}

String _deviceSummaryName(ExternalWorkRecord record) {
  final brand = record.equipmentBrand?.trim() ?? '';
  if (brand.isNotEmpty) return brand;
  final model = record.equipmentModel?.trim() ?? '';
  if (model.isNotEmpty) return model;
  final type = record.equipmentType?.trim() ?? '';
  if (type.isNotEmpty) return type;
  return '';
}

String _rowEquipmentText(ExternalWorkRecord record) {
  final parts = [
    record.equipmentBrand?.trim(),
    record.equipmentModel?.trim(),
  ].where((part) => part != null && part.isNotEmpty).cast<String>().toList();
  if (parts.isNotEmpty) return parts.join(' / ');

  final type = record.equipmentType?.trim() ?? '';
  return type.isEmpty ? '设备未填写' : type;
}

String _hoursText(int hoursMilli) {
  return FormatUtils.hours(hoursMilli / 1000);
}

String _blankFallback(String? text) {
  final value = text?.trim();
  return value == null || value.isEmpty ? '-' : value;
}

// ===========================================================================
// 详情卡片专用展示 helper（阶段 C Step 8 从 pattern 上移）。
// ===========================================================================

String _detailSiteText(List<TimingExternalWorkRecordItem> items) {
  final sites = <String>[];
  for (final item in items) {
    final site = item.record.siteSnapshot.trim();
    if (site.isNotEmpty && !sites.contains(site)) sites.add(site);
  }
  return sites.isEmpty ? '-' : sites.join('、');
}

String _detailEquipmentText(ExternalWorkRecord record) {
  final parts = [
    record.equipmentBrand?.trim(),
    record.equipmentModel?.trim(),
    record.equipmentType?.trim(),
  ].where((part) => part != null && part.isNotEmpty).cast<String>().toList();
  return parts.isEmpty ? '设备未填写' : parts.join(' / ');
}

/// 计时页 "外协项目记录" 详情专用：展示**来源方**原始单价（不是接收方复核）。
///
/// 规则：
/// - 只汇总同一外协包内 hours 记录的明确 sourceUnitPriceFen。
/// - 多个明确单价按记录出现顺序去重，用 "、" 拼接。
/// - rent / 台班及 sourceUnitPriceFen 为 null 的记录不参与汇总。
/// - 没有任何明确来源单价时显示"未知"。
/// 0 是合法的"真实来源单价为 0"语义，仍按 ¥0 / h 显示。
///
/// 重要：这里**不要**回退到 `localUnitPriceFen`。
/// localUnitPriceFen 是接收方未来本地复核的外协应付/结算单价，账户页
/// 外协卡片才走 `localUnitPriceFen ?? sourceUnitPriceFen` 作为有效应付价；
/// 在计时页详情拉它会把"接收方复核值"伪装成"来源事实"，破坏审计语义。
String _sourceUnitPriceText(Iterable<ExternalWorkRecord> records) {
  final seen = <int>{};
  final values = <String>[];
  for (final record in records) {
    if (record.recordKind != ExternalWorkRecordKind.hours) continue;
    final price = record.sourceUnitPriceFen;
    if (price == null || !seen.add(price)) continue;
    values.add('${_moneyFen(price)} / h');
  }
  return values.isEmpty ? '未知' : values.join('、');
}

String _moneyFen(int fen) {
  return FormatUtils.money(fen / 100);
}

String _statusText(ExternalWorkRecord record) {
  if (record.status == ExternalWorkRecordStatus.active) {
    return record.linkedProjectId?.trim().isNotEmpty == true ? '已关联' : '待处理';
  }
  switch (record.status) {
    case ExternalWorkRecordStatus.active:
      return '待处理';
    case ExternalWorkRecordStatus.ignored:
      return '已忽略';
    case ExternalWorkRecordStatus.archived:
      return '已归档';
    case ExternalWorkRecordStatus.voided:
      return '已作废';
  }
}
