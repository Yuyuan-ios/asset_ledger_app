import 'package:flutter/material.dart';

import '../../components/buttons/app_primary_button.dart';
import '../../core/foundation/spacing.dart';
import '../../core/foundation/typography.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../tokens/mapper/core_tokens.dart';

/// 防溢出的地址摘要：去重 + 取前 [maxShown] 个用 “、” 连接，超出再加 “...”。
/// 风格对齐项目标题地址展示（如 “鲜滩、尚义...”）。
String externalWorkLinkSiteSummary(
  Iterable<String> sites, {
  int maxShown = 2,
  String separator = ', ',
}) {
  final seen = <String>{};
  final distinct = <String>[];
  for (final raw in sites) {
    final site = raw.trim();
    if (site.isEmpty || !seen.add(site)) continue;
    distinct.add(site);
  }
  if (distinct.isEmpty) return '';
  final shown = distinct.take(maxShown).join(separator);
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

  /// 摘要次行：N条记录 · 累计工时。
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
/// 顶部"选择外协包"与"外协包摘要"并排展示（摘要随选择同步），再展示
/// "选择要关联的项目"，并通过回调把 确认关联 / 解除关联 / 取消 交给上层。
/// **不做任何写库**。
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
      padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ..._buildScrollableBody(package),
                  const SizedBox(height: AppSpace.lg),
                ],
              ),
            ),
          ),
          _buildFixedActions(package),
        ],
      ),
    );
  }

  List<Widget> _buildScrollableBody(ExternalWorkLinkPackage? package) {
    final l10n = AppLocalizations.of(context);
    final summaryLines = package == null
        ? const <String>[]
        : package.summaryDetail
              .split('\n')
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty)
              .toList(growable: false);
    final packageSummaryRowCount = widget.packages.length > summaryLines.length
        ? widget.packages.length
        : summaryLines.length;

    return [
      if (widget.packages.isNotEmpty) ...[
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                l10n.timingExternalWorkSelectPackage,
                style: AppTypography.sectionTitle(context),
              ),
            ),
            if (package != null) ...[
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    l10n.timingExternalWorkPackageSummary,
                    textAlign: TextAlign.right,
                    style: AppTypography.sectionTitle(context),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        for (var i = 0; i < packageSummaryRowCount; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: i < widget.packages.length
                    ? _RadioRow(
                        key: Key(
                          'external-work-link-package-${widget.packages[i].batchId}',
                        ),
                        title: widget.packages[i].optionTitle,
                        selected:
                            widget.packages[i].batchId == _selectedBatchId,
                        onTap: () => setState(
                          () => _selectedBatchId = widget.packages[i].batchId,
                        ),
                      )
                    : const SizedBox(height: 20 + AppSpace.sm * 2),
              ),
              if (package != null) ...[
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: i < summaryLines.length
                      ? Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpace.sm,
                            ),
                            child: Text(
                              summaryLines[i],
                              textAlign: TextAlign.right,
                              style: AppTypography.body(
                                context,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        const SizedBox(height: AppSpace.md),
      ],
      if (package != null) ...[
        if (package.isLinked)
          ..._buildLinkedContent(context, package)
        else
          ..._buildPickContent(package),
      ],
    ];
  }

  Widget _buildFixedActions(ExternalWorkLinkPackage? package) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.lg),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('external-work-link-cancel'),
                onPressed: widget.onCancel,
                child: Text(l10n.timingExternalWorkCancelAction),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(child: _buildPrimaryAction(package)),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryAction(ExternalWorkLinkPackage? package) {
    final l10n = AppLocalizations.of(context);
    if (package?.isLinked == true) {
      return OutlinedButton(
        key: const Key('external-work-link-unlink'),
        onPressed: widget.onUnlink == null || package == null
            ? null
            : () => widget.onUnlink!(package),
        child: Text(l10n.timingExternalWorkUnlinkAction),
      );
    }

    final candidate = _selectedCandidate;
    return AppPrimaryButton(
      key: const Key('external-work-link-confirm'),
      label: l10n.timingExternalWorkConfirmLinkAction,
      onPressed: package == null || candidate == null
          ? null
          : () => widget.onConfirm(package, candidate),
    );
  }

  List<Widget> _buildLinkedContent(
    BuildContext context,
    ExternalWorkLinkPackage package,
  ) {
    final l10n = AppLocalizations.of(context);
    return [
      Text(
        l10n.timingExternalWorkLinkedProject(package.linkedProjectTitle ?? ''),
        style: AppTypography.body(context, fontWeight: FontWeight.w600),
      ),
    ];
  }

  List<Widget> _buildPickContent(ExternalWorkLinkPackage package) {
    final l10n = AppLocalizations.of(context);
    final candidate = _selectedCandidate;
    return [
      Text(
        l10n.timingExternalWorkSelectProject,
        style: AppTypography.sectionTitle(context),
      ),
      const SizedBox(height: AppSpace.sm),
      if (widget.candidates.isEmpty)
        Text(
          l10n.timingExternalWorkNoLinkableProjects,
          style: AppTypography.body(
            context,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        )
      else
        for (final item in widget.candidates)
          _RadioRow(
            key: Key('external-work-link-candidate-${item.projectId}'),
            title: item.settled
                ? l10n.timingExternalWorkSettledCandidateTitle(item.title)
                : item.title,
            selected: _selectedProjectId == item.projectId,
            onTap: () => setState(() => _selectedProjectId = item.projectId),
          ),
      if (candidate != null && candidate.settled) ...[
        const SizedBox(height: AppSpace.sm),
        Text(
          l10n.timingExternalWorkSettledHint,
          style: AppTypography.caption(context, color: AppColors.brand),
        ),
      ],
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
