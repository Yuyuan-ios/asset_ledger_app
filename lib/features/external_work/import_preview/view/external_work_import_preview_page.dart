import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../components/buttons/app_primary_button.dart';
import '../../../../components/feedback/store_error_banner.dart';
import '../../../../core/foundation/spacing.dart';
import '../../../../core/foundation/typography.dart';
import '../../../../data/share/jztshare/project_external_work_import_preview.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../../tokens/mapper/core_tokens.dart';
import '../use_cases/confirm_external_work_import_use_case.dart';
import '../use_cases/prepare_external_work_import_preview_use_case.dart';
import '../view_model/external_work_import_preview_copy.dart';
import '../view_model/external_work_import_preview_view_model.dart';

class ExternalWorkImportPreviewPage extends StatelessWidget {
  const ExternalWorkImportPreviewPage({
    super.key,
    this.initialContent,
    this.viewModel,
    this.onCancel,
    this.onImported,
  });

  final String? initialContent;
  final ExternalWorkImportPreviewViewModel? viewModel;
  final VoidCallback? onCancel;
  final VoidCallback? onImported;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final providedViewModel = viewModel;
    if (providedViewModel != null) {
      return ChangeNotifierProvider<ExternalWorkImportPreviewViewModel>.value(
        value: providedViewModel,
        child: _ExternalWorkImportPreviewContent(
          initialContent: initialContent,
          onCancel: onCancel,
          onImported: onImported,
        ),
      );
    }

    return ChangeNotifierProvider<ExternalWorkImportPreviewViewModel>(
      create: (context) => ExternalWorkImportPreviewViewModel(
        preparePreview: context.read<ExternalWorkImportPreviewPreparer>(),
        confirmImport: context.read<ExternalWorkImportConfirmer>(),
        copy: ExternalWorkImportPreviewCopy(l10n: l10n),
      ),
      child: _ExternalWorkImportPreviewContent(
        initialContent: initialContent,
        onCancel: onCancel,
        onImported: onImported,
      ),
    );
  }
}

class _ExternalWorkImportPreviewContent extends StatefulWidget {
  const _ExternalWorkImportPreviewContent({
    this.initialContent,
    this.onCancel,
    this.onImported,
  });

  final String? initialContent;
  final VoidCallback? onCancel;
  final VoidCallback? onImported;

  @override
  State<_ExternalWorkImportPreviewContent> createState() =>
      _ExternalWorkImportPreviewContentState();
}

class _ExternalWorkImportPreviewContentState
    extends State<_ExternalWorkImportPreviewContent> {
  bool _preparedInitialContent = false;

  @override
  void initState() {
    super.initState();
    if ((widget.initialContent ?? '').trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _preparedInitialContent) return;
        _preparedInitialContent = true;
        context.read<ExternalWorkImportPreviewViewModel>().prepare(
          widget.initialContent!,
        );
      });
    }
  }

  Future<void> _confirm() async {
    final viewModel = context.read<ExternalWorkImportPreviewViewModel>();
    await viewModel.confirmImport();
    if (!mounted) return;
    if (viewModel.status == ExternalWorkImportPreviewStatus.success) {
      widget.onImported?.call();
    }
  }

  void _cancel() {
    final onCancel = widget.onCancel;
    if (onCancel != null) {
      onCancel();
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    context.read<ExternalWorkImportPreviewViewModel>().cancel();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final copy = ExternalWorkImportPreviewCopy(l10n: l10n);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.externalWorkImportPreviewTitle)),
      body: SafeArea(
        child: Consumer<ExternalWorkImportPreviewViewModel>(
          builder: (context, viewModel, _) {
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpace.lg),
                    children: [
                      if (viewModel.errorMessage != null)
                        StoreErrorBanner(message: viewModel.errorMessage!),
                      if (viewModel.successMessage != null)
                        _SuccessBanner(
                          message: viewModel.successMessage!,
                          l10n: l10n,
                        ),
                      if (viewModel.preview != null) ...[
                        _PreviewSummary(
                          preview: viewModel.preview!,
                          l10n: l10n,
                        ),
                        const SizedBox(height: AppSpace.md),
                        _PreviewLines(
                          lines: viewModel.preview!.lines,
                          copy: copy,
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.lg,
                    AppSpace.md,
                    AppSpace.lg,
                    AppSpace.lg,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('external-work-import-preview-cancel'),
                          onPressed: viewModel.isBusy ? null : _cancel,
                          child: Text(l10n.timingExternalWorkCancelAction),
                        ),
                      ),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: AppPrimaryButton(
                          key: const Key(
                            'external-work-import-preview-confirm',
                          ),
                          label:
                              viewModel.status ==
                                  ExternalWorkImportPreviewStatus.importing
                              ? l10n.externalWorkImportPreviewImportingAction
                              : l10n.timingExternalWorkImportAction,
                          onPressed: viewModel.canConfirm ? _confirm : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PreviewSummary extends StatelessWidget {
  const _PreviewSummary({required this.preview, required this.l10n});

  final ExternalWorkImportPreview preview;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final duplicateSummary = preview.duplicateSummary;
    return DecoratedBox(
      decoration: _panelDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.externalWorkImportPreviewSectionTitle,
              style: AppTypography.sectionTitle(context),
            ),
            const SizedBox(height: AppSpace.sm),
            _SummaryRow(
              label: l10n.externalWorkImportPreviewSenderLabel,
              value: preview.senderName,
            ),
            _SummaryRow(
              label: l10n.externalWorkImportPreviewRecordLabel,
              value: l10n.externalWorkImportPreviewRecordCount(
                preview.recordCount,
              ),
            ),
            _SummaryRow(
              label: l10n.externalWorkImportPreviewSiteLabel,
              value: preview.siteSummary,
            ),
            _SummaryRow(
              label: l10n.externalWorkImportPreviewTotalHoursLabel,
              value: _formatHoursMilli(preview.totalHoursMilli, l10n),
            ),
            _SummaryRow(
              label: l10n.externalWorkImportPreviewTotalAmountLabel,
              value: _formatFen(preview.totalAmountFen),
            ),
            if (duplicateSummary.hasBlockingDuplicates ||
                duplicateSummary.hasSuspiciousDuplicates) ...[
              const SizedBox(height: AppSpace.sm),
              _DuplicateSummary(summary: duplicateSummary, l10n: l10n),
            ],
          ],
        ),
      ),
    );
  }
}

class _PreviewLines extends StatelessWidget {
  const _PreviewLines({required this.lines, required this.copy});

  final List<ExternalWorkImportPreviewLine> lines;
  final ExternalWorkImportPreviewCopy copy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          copy.l10n.externalWorkImportPreviewLinesTitle,
          style: AppTypography.sectionTitle(context),
        ),
        const SizedBox(height: AppSpace.sm),
        for (final line in lines) ...[
          _PreviewLineCard(line: line, copy: copy),
          const SizedBox(height: AppSpace.sm),
        ],
      ],
    );
  }
}

class _PreviewLineCard extends StatelessWidget {
  const _PreviewLineCard({required this.line, required this.copy});

  final ExternalWorkImportPreviewLine line;
  final ExternalWorkImportPreviewCopy copy;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _panelDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${line.contactSnapshot} · ${line.siteSnapshot}',
                    style: AppTypography.body(
                      context,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                _StatusChip(status: line.duplicateStatus, copy: copy),
              ],
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              '${_formatYmd(line.workDate)}  ${_formatHoursMilli(line.hoursMilli, copy.l10n)}  ${_formatFen(line.amountFen)}',
              style: AppTypography.caption(
                context,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if ((line.equipmentBrand ?? '').isNotEmpty ||
                (line.equipmentModel ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpace.xs),
              Text(
                [
                  line.equipmentBrand,
                  line.equipmentModel,
                ].where((item) => (item ?? '').trim().isNotEmpty).join(' '),
                style: AppTypography.caption(context),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.copy});

  final ExternalWorkDuplicateStatus status;
  final ExternalWorkImportPreviewCopy copy;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ExternalWorkDuplicateStatus.none => Colors.green,
      ExternalWorkDuplicateStatus.sameOriginFingerprintAlreadyImported =>
        AppColors.brand,
      ExternalWorkDuplicateStatus.sameShareAlreadyImported ||
      ExternalWorkDuplicateStatus.sameSourceRecordAlreadyImported => Colors.red,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          copy.duplicateStatusLabel(status),
          style: AppTypography.caption(context, color: color),
        ),
      ),
    );
  }
}

class _DuplicateSummary extends StatelessWidget {
  const _DuplicateSummary({required this.summary, required this.l10n});

  final ExternalWorkDuplicateSummary summary;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final labels = <String>[];
    if (summary.sameShareAlreadyImported) {
      labels.add(l10n.externalWorkImportPreviewStatusImported);
    }
    if (summary.sameSourceRecordCount > 0) {
      labels.add(
        l10n.externalWorkImportPreviewSameSourceCount(
          summary.sameSourceRecordCount,
        ),
      );
    }
    if (summary.sameOriginFingerprintCount > 0) {
      labels.add(
        l10n.externalWorkImportPreviewSuspiciousCount(
          summary.sameOriginFingerprintCount,
        ),
      );
    }
    return Text(
      labels.join('，'),
      style: AppTypography.body(context, color: Colors.red),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: AppTypography.caption(
                context,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: AppTypography.body(context))),
        ],
      ),
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner({required this.message, required this.l10n});

  final String message;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.sm,
        ),
        child: Text(
          l10n.externalWorkImportPreviewSuccessBanner(message),
          style: AppTypography.body(context, color: Colors.green.shade700),
        ),
      ),
    );
  }
}

BoxDecoration _panelDecoration(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return BoxDecoration(
    color: colorScheme.surface,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: colorScheme.outlineVariant),
  );
}

String _formatHoursMilli(int milliHours, AppLocalizations l10n) {
  final whole = milliHours ~/ 1000;
  final fraction = milliHours.remainder(1000);
  if (fraction == 0) return l10n.externalWorkImportPreviewHoursValue('$whole');
  final fractionText = fraction
      .toString()
      .padLeft(3, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return l10n.externalWorkImportPreviewHoursValue('$whole.$fractionText');
}

String _formatFen(int fen) {
  final yuan = fen ~/ 100;
  final cent = fen.remainder(100).abs().toString().padLeft(2, '0');
  return '¥$yuan.$cent';
}

String _formatYmd(int ymd) {
  final text = ymd.toString().padLeft(8, '0');
  return '${text.substring(0, 4)}-${text.substring(4, 6)}-${text.substring(6)}';
}
