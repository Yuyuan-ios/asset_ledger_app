import 'package:flutter/material.dart';

import '../../components/buttons/app_primary_button.dart';
import '../../core/foundation/spacing.dart';
import '../../core/foundation/typography.dart';

/// 选择已结清项目时的边界提示文案（关联不改变项目财务/结清状态）。
const String externalWorkLinkSettledHint =
    '该项目已结清。关联外协包不会改变项目总额、已收、待收和结清状态，仅用于后续外协应付/成本统计。';

/// 解除关联确认文案（阶段二仅提示，不写库）。
const String externalWorkLinkUnlinkConfirm =
    '解除关联后，该外协包将作为独立外协项目保留，不会删除外协记录。是否继续？';

/// 防溢出的地址摘要：去重 + 取前 [maxShown] 个用 “+” 连接，超出再加 “...”。
/// 风格对齐账户页项目卡片（如 “鲜滩+尚义...”）。
String externalWorkLinkSiteSummary(Iterable<String> sites, {int maxShown = 2}) {
  final seen = <String>{};
  final distinct = <String>[];
  for (final raw in sites) {
    final site = raw.trim();
    if (site.isEmpty || !seen.add(site)) continue;
    distinct.add(site);
  }
  if (distinct.isEmpty) return '';
  final shown = distinct.take(maxShown).join('+');
  return distinct.length > maxShown ? '$shown...' : shown;
}

/// 可关联的外协包（一个 importBatch）。仅承载展示，不写库。
class ExternalWorkLinkPackage {
  const ExternalWorkLinkPackage({
    required this.batchId,
    required this.optionTitle,
    required this.summaryDetail,
    this.linkedProjectTitle,
  });

  /// 选项标题：来源人 · 地址摘要（如 “余远 · 鲜滩”）。
  final String optionTitle;

  /// 摘要次行：设备 · N条记录 · 累计工时。
  final String summaryDetail;

  final String batchId;

  /// 已关联项目名（非空时该包显示已关联态 + 解除入口）。
  final String? linkedProjectTitle;

  bool get isLinked => (linkedProjectTitle ?? '').trim().isNotEmpty;
}

/// 候选自有项目（关联弹窗用）。本阶段只承载展示与选择，不写库。
class ExternalWorkLinkCandidate {
  const ExternalWorkLinkCandidate({
    required this.projectId,
    required this.title,
    required this.settled,
  });

  final String projectId;
  final String title;
  final bool settled;
}

typedef ExternalWorkLinkConfirm =
    void Function(
      ExternalWorkLinkPackage package,
      ExternalWorkLinkCandidate candidate,
    );

typedef ExternalWorkLinkUnlink = void Function(ExternalWorkLinkPackage package);

/// “关联到项目”底部弹窗内容（阶段二骨架）。
///
/// 顶部"选择外协包" → "外协包摘要"（随选择同步）→ "选择要关联的项目"，并通过
/// 回调把 确认关联 / 解除关联 / 取消 交给上层。**不做任何写库**。
class ExternalWorkLinkSheet extends StatefulWidget {
  const ExternalWorkLinkSheet({
    super.key,
    required this.packages,
    required this.candidates,
    required this.onConfirm,
    required this.onCancel,
    this.onUnlink,
    this.initialBatchId,
  });

  final List<ExternalWorkLinkPackage> packages;
  final List<ExternalWorkLinkCandidate> candidates;
  final ExternalWorkLinkConfirm onConfirm;
  final VoidCallback onCancel;
  final ExternalWorkLinkUnlink? onUnlink;
  final String? initialBatchId;

  @override
  State<ExternalWorkLinkSheet> createState() => _ExternalWorkLinkSheetState();
}

class _ExternalWorkLinkSheetState extends State<ExternalWorkLinkSheet> {
  String? _selectedBatchId;
  String? _selectedProjectId;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialBatchId;
    final hasInitial =
        initial != null && widget.packages.any((pkg) => pkg.batchId == initial);
    _selectedBatchId = hasInitial
        ? initial
        : (widget.packages.isEmpty ? null : widget.packages.first.batchId);
  }

  ExternalWorkLinkPackage? get _selectedPackage {
    final id = _selectedBatchId;
    if (id == null) return null;
    for (final pkg in widget.packages) {
      if (pkg.batchId == id) return pkg;
    }
    return widget.packages.isEmpty ? null : widget.packages.first;
  }

  ExternalWorkLinkCandidate? get _selectedCandidate {
    final id = _selectedProjectId;
    if (id == null) return null;
    for (final candidate in widget.candidates) {
      if (candidate.projectId == id) return candidate;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final package = _selectedPackage;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        0,
        AppSpace.lg,
        AppSpace.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.packages.isNotEmpty) ...[
            Text('选择外协包', style: AppTypography.sectionTitle(context)),
            const SizedBox(height: AppSpace.sm),
            for (final pkg in widget.packages)
              _RadioRow(
                key: Key('external-work-link-package-${pkg.batchId}'),
                title: pkg.optionTitle,
                selected: pkg.batchId == _selectedBatchId,
                onTap: () => setState(() => _selectedBatchId = pkg.batchId),
              ),
            const SizedBox(height: AppSpace.md),
          ],
          if (package != null) ...[
            Text('外协包摘要', style: AppTypography.sectionTitle(context)),
            const SizedBox(height: AppSpace.sm),
            Text(
              package.summaryDetail,
              style: AppTypography.caption(
                context,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpace.md),
            if (package.isLinked)
              ..._buildLinkedBody(context, package)
            else
              ..._buildPickBody(package),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildLinkedBody(
    BuildContext context,
    ExternalWorkLinkPackage package,
  ) {
    return [
      Text(
        '已关联：${package.linkedProjectTitle}',
        style: AppTypography.body(context, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: AppSpace.lg),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              key: const Key('external-work-link-cancel'),
              onPressed: widget.onCancel,
              child: const Text('取消'),
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: OutlinedButton(
              key: const Key('external-work-link-unlink'),
              onPressed: widget.onUnlink == null
                  ? null
                  : () => widget.onUnlink!(package),
              child: const Text('解除关联'),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildPickBody(ExternalWorkLinkPackage package) {
    final candidate = _selectedCandidate;
    return [
      Text('选择要关联的项目', style: AppTypography.sectionTitle(context)),
      const SizedBox(height: AppSpace.sm),
      if (widget.candidates.isEmpty)
        Text(
          '暂无可关联的自有项目',
          style: AppTypography.body(
            context,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        )
      else
        for (final item in widget.candidates)
          _RadioRow(
            key: Key('external-work-link-candidate-${item.projectId}'),
            title: item.settled ? '${item.title}（已结清）' : item.title,
            selected: _selectedProjectId == item.projectId,
            onTap: () => setState(() => _selectedProjectId = item.projectId),
          ),
      if (candidate != null && candidate.settled) ...[
        const SizedBox(height: AppSpace.sm),
        Text(
          externalWorkLinkSettledHint,
          style: AppTypography.caption(context, color: Colors.orange.shade800),
        ),
      ],
      const SizedBox(height: AppSpace.lg),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              key: const Key('external-work-link-cancel'),
              onPressed: widget.onCancel,
              child: const Text('取消'),
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: AppPrimaryButton(
              key: const Key('external-work-link-confirm'),
              label: '确认关联',
              onPressed: candidate == null
                  ? null
                  : () => widget.onConfirm(package, candidate),
            ),
          ),
        ],
      ),
    ];
  }
}

class _RadioRow extends StatelessWidget {
  const _RadioRow({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: selected ? colorScheme.primary : colorScheme.outline,
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(child: Text(title, style: AppTypography.body(context))),
          ],
        ),
      ),
    );
  }
}
