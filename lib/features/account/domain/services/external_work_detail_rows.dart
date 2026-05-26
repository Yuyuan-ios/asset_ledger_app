import '../../../../data/models/external_import_batch.dart';
import '../../../../data/models/external_work_record.dart';
import '../../../timing/state/timing_external_work_store.dart';
import 'external_work_receivable.dart';

/// 项目详情页“外协设备”section 用的明细行 VM。
///
/// 一个 `AccountProjectExternalWorkDetailRow` 表示「一个 importBatch 的外协
/// 包」在当前项目下的聚合结果（设备摘要、记录条数、总工时、应收 / 应付）。
/// UI 本轮只用 [sourceDisplayName] / [siteSummary] / [equipmentSummary] /
/// [recordCount] / [hours]，其余字段为后续详情财务拆分留接口。
class AccountProjectExternalWorkDetailRow {
  const AccountProjectExternalWorkDetailRow({
    required this.importBatchId,
    required this.linkedProjectId,
    required this.sourceDisplayName,
    required this.siteSummary,
    required this.equipmentSummary,
    required this.recordCount,
    required this.hours,
    required this.receivableFen,
    required this.payableFen,
  });

  final String importBatchId;
  final String linkedProjectId;
  final String sourceDisplayName;
  final String siteSummary;
  final String equipmentSummary;
  final int recordCount;
  final double hours;
  final int receivableFen;
  final int payableFen;
}

/// 从外协 store 的 items 中筛出已关联到 [projectIdentityIds] 的 active 记录，
/// 按 importBatchId 聚合成 [AccountProjectExternalWorkDetailRow] 列表。
///
/// 排序：按 importedAt（或 batch.createdAt / record.createdAt）降序，再按
/// importBatchId 升序，保持稳定。
///
/// [projectIdentityIds] 期望已 trim 过；空字符串会被忽略。普通项目传
/// `{project.effectiveProjectId}`；合并项目传 `{...memberProjectIds}`。
List<AccountProjectExternalWorkDetailRow> buildAccountProjectExternalWorkDetailRows({
  required Iterable<TimingExternalWorkRecordItem> externalWorkItems,
  required Set<String> projectIdentityIds,
}) {
  if (projectIdentityIds.isEmpty) return const [];

  final normalizedTargetIds = projectIdentityIds
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toSet();
  if (normalizedTargetIds.isEmpty) return const [];

  final groupsByBatch = <String, _BatchAccumulator>{};
  for (final item in externalWorkItems) {
    final record = item.record;
    if (record.status != ExternalWorkRecordStatus.active) continue;
    // 与 rollupExternalWorkReceivable 对齐：只看 active batch；batch 缺失
    // （旧库 / 异常数据）一并跳过，避免详情明细与卡片/总额口径不一致。
    if (item.batch?.status != ExternalImportBatchStatus.active) continue;
    final linked = record.linkedProjectId?.trim() ?? '';
    if (linked.isEmpty || !normalizedTargetIds.contains(linked)) continue;

    final key = record.importBatchId.trim();
    if (key.isEmpty) continue;

    groupsByBatch
        .putIfAbsent(
          key,
          () => _BatchAccumulator(
            importBatchId: key,
            linkedProjectId: linked,
            sourceDisplayName: item.displayName,
          ),
        )
        .add(item);
  }

  final groups = groupsByBatch.values.toList(growable: false)
    ..sort((a, b) {
      final byImported = b.importedAtSortKey.compareTo(a.importedAtSortKey);
      if (byImported != 0) return byImported;
      return a.importBatchId.compareTo(b.importBatchId);
    });

  return groups.map((group) => group.build()).toList(growable: false);
}

class _BatchAccumulator {
  _BatchAccumulator({
    required this.importBatchId,
    required this.linkedProjectId,
    required this.sourceDisplayName,
  });

  final String importBatchId;
  final String linkedProjectId;
  final String sourceDisplayName;

  final List<String> _siteOrder = [];
  final Set<String> _seenSites = {};
  final List<String> _deviceOrder = [];
  final Set<String> _seenDevices = {};
  int _recordCount = 0;
  int _hoursMilli = 0;
  int _receivableFen = 0;
  int _payableFen = 0;
  String _importedAtSortKey = '';

  int get importedAtSortKey =>
      DateTime.tryParse(_importedAtSortKey)?.millisecondsSinceEpoch ?? 0;

  void add(TimingExternalWorkRecordItem item) {
    final record = item.record;
    final site = record.siteSnapshot.trim();
    if (site.isNotEmpty && _seenSites.add(site)) {
      _siteOrder.add(site);
    }
    final deviceName = _deviceSummaryName(record);
    if (deviceName.isNotEmpty && _seenDevices.add(deviceName)) {
      _deviceOrder.add(deviceName);
    }
    _recordCount += 1;
    _hoursMilli += record.hoursMilli;
    _receivableFen += externalWorkRecordReceivableFen(record);
    _payableFen += record.amountFen;

    final candidate = _importedAtTextFor(item);
    if (candidate.compareTo(_importedAtSortKey) > 0) {
      _importedAtSortKey = candidate;
    }
  }

  AccountProjectExternalWorkDetailRow build() {
    return AccountProjectExternalWorkDetailRow(
      importBatchId: importBatchId,
      linkedProjectId: linkedProjectId,
      sourceDisplayName: sourceDisplayName,
      siteSummary: _siteOrder.join('、'),
      equipmentSummary: _formatEquipmentSummary(_deviceOrder),
      recordCount: _recordCount,
      hours: _hoursMilli / 1000.0,
      receivableFen: _receivableFen,
      payableFen: _payableFen,
    );
  }
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

String _formatEquipmentSummary(List<String> devices) {
  if (devices.isEmpty) return '设备未填写';
  if (devices.length == 1) return devices.first;
  return '${devices.first}等${devices.length}台';
}

String _importedAtTextFor(TimingExternalWorkRecordItem item) {
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
