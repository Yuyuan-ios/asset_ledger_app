import 'package:flutter/material.dart';

import '../../components/buttons/app_primary_button.dart';
import '../../core/foundation/spacing.dart';
import '../../core/foundation/typography.dart';
import '../../tokens/mapper/core_tokens.dart';

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

/// “关联到项目”底部弹窗内容（阶段二骨架）。
///
/// 只负责展示外协包摘要 + 候选项目选择 + 已结清边界提示，并通过回调把
/// “确认关联 / 解除关联 / 取消” 交给上层。**不做任何写库**。
class ExternalWorkLinkSheet extends StatefulWidget {
  const ExternalWorkLinkSheet({
    super.key,
    required this.summaryTitle,
    required this.summaryDetail,
    required this.candidates,
    required this.onConfirm,
    required this.onCancel,
    this.linkedProjectTitle,
    this.onUnlink,
  });

  /// 外协包摘要主行：来源人 · 地址摘要。
  final String summaryTitle;

  /// 外协包摘要次行：设备 · N条记录 · 累计工时。
  final String summaryDetail;

  final List<ExternalWorkLinkCandidate> candidates;
  final ValueChanged<ExternalWorkLinkCandidate> onConfirm;
  final VoidCallback onCancel;

  /// 已关联项目名（非空时显示已关联态 + 解除入口）。
  final String? linkedProjectTitle;
  final VoidCallback? onUnlink;

  @override
  State<ExternalWorkLinkSheet> createState() => _ExternalWorkLinkSheetState();
}

class _ExternalWorkLinkSheetState extends State<ExternalWorkLinkSheet> {
  String? _selectedProjectId;

  bool get _isLinked => (widget.linkedProjectTitle ?? '').trim().isNotEmpty;

  ExternalWorkLinkCandidate? get _selected {
    final id = _selectedProjectId;
    if (id == null) return null;
    for (final candidate in widget.candidates) {
      if (candidate.projectId == id) return candidate;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
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
          _SummaryCard(
            title: widget.summaryTitle,
            detail: widget.summaryDetail,
          ),
          const SizedBox(height: AppSpace.md),
          if (_isLinked) ..._buildLinkedBody(context) else ..._buildPickBody(),
        ],
      ),
    );
  }

  List<Widget> _buildLinkedBody(BuildContext context) {
    return [
      Text(
        '已关联：${widget.linkedProjectTitle}',
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
              onPressed: widget.onUnlink,
              child: const Text('解除关联'),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildPickBody() {
    final selected = _selected;
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
        for (final candidate in widget.candidates)
          _CandidateTile(
            key: Key('external-work-link-candidate-${candidate.projectId}'),
            candidate: candidate,
            selected: _selectedProjectId == candidate.projectId,
            onTap: () =>
                setState(() => _selectedProjectId = candidate.projectId),
          ),
      if (selected != null && selected.settled) ...[
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
              onPressed: selected == null
                  ? null
                  : () => widget.onConfirm(selected),
            ),
          ),
        ],
      ),
    ];
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({
    super.key,
    required this.candidate,
    required this.selected,
    required this.onTap,
  });

  final ExternalWorkLinkCandidate candidate;
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
            Expanded(
              child: Text(
                candidate.settled ? '${candidate.title}（已结清）' : candidate.title,
                style: AppTypography.body(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body(context, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption(
                context,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
