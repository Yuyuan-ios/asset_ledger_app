import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../components/buttons/app_primary_button.dart';
import '../../../../components/feedback/store_error_banner.dart';
import '../../../../core/foundation/spacing.dart';
import '../../../../core/foundation/typography.dart';
import '../../../../data/share/jztshare/project_external_work_import_preview.dart';
import '../use_cases/confirm_external_work_import_use_case.dart';
import '../use_cases/prepare_external_work_import_preview_use_case.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('外协项目记录')),
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
                        _SuccessBanner(message: viewModel.successMessage!),
                      if (viewModel.preview != null) ...[
                        _PreviewSummary(preview: viewModel.preview!),
                        const SizedBox(height: AppSpace.md),
                        _PreviewLines(lines: viewModel.preview!.lines),
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
                          child: const Text('取消'),
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
                              ? '导入中'
                              : '导入',
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
  const _PreviewSummary({required this.preview});

  final ExternalWorkImportPreview preview;

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
            Text('预览', style: AppTypography.sectionTitle(context)),
            const SizedBox(height: AppSpace.sm),
            _SummaryRow(label: '来自', value: preview.senderName),
            _SummaryRow(label: '记录', value: '${preview.recordCount} 条'),
            _SummaryRow(label: '地点', value: preview.siteSummary),
            _SummaryRow(
              label: '总工时',
              value: _formatHoursMilli(preview.totalHoursMilli),
            ),
            _SummaryRow(
              label: '总金额',
              value: _formatFen(preview.totalAmountFen),
            ),
            if (duplicateSummary.hasBlockingDuplicates ||
                duplicateSummary.hasSuspiciousDuplicates) ...[
              const SizedBox(height: AppSpace.sm),
              _DuplicateSummary(summary: duplicateSummary),
            ],
          ],
        ),
      ),
    );
  }
}

class _PreviewLines extends StatelessWidget {
  const _PreviewLines({required this.lines});

  final List<ExternalWorkImportPreviewLine> lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('记录明细', style: AppTypography.sectionTitle(context)),
        const SizedBox(height: AppSpace.sm),
        for (final line in lines) ...[
          _PreviewLineCard(line: line),
          const SizedBox(height: AppSpace.sm),
        ],
      ],
    );
  }
}

class _PreviewLineCard extends StatelessWidget {
  const _PreviewLineCard({required this.line});

  final ExternalWorkImportPreviewLine line;

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
                _StatusChip(status: line.duplicateStatus),
              ],
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              '${_formatYmd(line.workDate)}  ${_formatHoursMilli(line.hoursMilli)}  ${_formatFen(line.amountFen)}',
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
  const _StatusChip({required this.status});

  final ExternalWorkDuplicateStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ExternalWorkDuplicateStatus.none => Colors.green,
      ExternalWorkDuplicateStatus.sameOriginFingerprintAlreadyImported =>
        Colors.orange,
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
          externalWorkDuplicateStatusLabel(status),
          style: AppTypography.caption(context, color: color),
        ),
      ),
    );
  }
}

class _DuplicateSummary extends StatelessWidget {
  const _DuplicateSummary({required this.summary});

  final ExternalWorkDuplicateSummary summary;

  @override
  Widget build(BuildContext context) {
    final labels = <String>[];
    if (summary.sameShareAlreadyImported) {
      labels.add('已导入过');
    }
    if (summary.sameSourceRecordCount > 0) {
      labels.add('存在相同来源记录 ${summary.sameSourceRecordCount} 条');
    }
    if (summary.sameOriginFingerprintCount > 0) {
      labels.add('存在可疑重复记录 ${summary.sameOriginFingerprintCount} 条');
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
  const _SuccessBanner({required this.message});

  final String message;

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
          '$message，可在外协项目记录中查看',
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

String _formatHoursMilli(int milliHours) {
  final whole = milliHours ~/ 1000;
  final fraction = milliHours.remainder(1000);
  if (fraction == 0) return '$whole小时';
  final fractionText = fraction
      .toString()
      .padLeft(3, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return '$whole.$fractionText小时';
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
