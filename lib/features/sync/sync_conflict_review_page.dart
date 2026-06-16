import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import 'sync_conflict_review_controller.dart';

class SyncConflictReviewPage extends StatefulWidget {
  const SyncConflictReviewPage({super.key, this.controller});

  final SyncConflictReviewController? controller;

  @override
  State<SyncConflictReviewPage> createState() => _SyncConflictReviewPageState();
}

class _SyncConflictReviewPageState extends State<SyncConflictReviewPage> {
  late final SyncConflictReviewController _controller =
      widget.controller ?? SyncConflictReviewController();
  late final bool _ownsController = widget.controller == null;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _controller.load();
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.syncConflictReviewTitle)),
      body: _buildBody(context, l10n),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    if (_controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.error != null) {
      return Center(child: Text(l10n.syncConflictReviewLoadFailure));
    }
    final items = _controller.items;
    if (items.isEmpty) {
      return Center(child: Text(l10n.syncConflictReviewEmpty));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Text(
            l10n.syncConflictReviewManualHint,
            style: Theme.of(context).textTheme.bodySmall,
          );
        }
        return _ConflictCard(
          item: items[index - 1],
          onUseRemote: () => _resolveRemote(items[index - 1]),
          onUseLocal: () => _resolveLocal(items[index - 1]),
        );
      },
    );
  }

  Future<void> _resolveRemote(SyncConflictReviewItem item) async {
    final l10n = AppLocalizations.of(context);
    try {
      await _controller.useRemote(item);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.syncConflictResolveFailure)));
    }
  }

  Future<void> _resolveLocal(SyncConflictReviewItem item) async {
    final l10n = AppLocalizations.of(context);
    try {
      await _controller.useLocal(item);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.syncConflictResolveFailure)));
    }
  }
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({
    required this.item,
    required this.onUseRemote,
    required this.onUseLocal,
  });

  final SyncConflictReviewItem item;
  final VoidCallback onUseRemote;
  final VoidCallback onUseLocal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.syncConflictReviewEntityTitle(item.conflict.entityId),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.syncConflictReviewReason(item.conflict.conflictReason),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _SummaryBlock(
              label: l10n.syncConflictReviewLocalLabel,
              value: _summaryText(
                l10n,
                item.local,
                missingText: l10n.syncConflictReviewMissingLocal,
              ),
            ),
            const SizedBox(height: 8),
            _SummaryBlock(
              label: l10n.syncConflictReviewRemoteLabel,
              value: _summaryText(
                l10n,
                item.remote,
                missingText: l10n.syncConflictReviewMissingRemote,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onUseLocal,
                  icon: const Icon(Icons.edit_note_outlined),
                  label: Text(l10n.syncConflictReviewUseLocal),
                ),
                FilledButton.icon(
                  onPressed: onUseRemote,
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: Text(l10n.syncConflictReviewUseRemote),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryBlock extends StatelessWidget {
  const _SummaryBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(value),
          ],
        ),
      ),
    );
  }
}

String _summaryText(
  AppLocalizations l10n,
  TimingConflictSummary? summary, {
  required String missingText,
}) {
  if (summary == null) return missingText;
  if (summary.deleted) return l10n.syncConflictReviewDeletedSummary;
  return l10n.syncConflictReviewTimingSummary(
    summary.deviceId,
    summary.dateLabel,
    summary.hoursLabel,
    summary.amountLabel,
  );
}
