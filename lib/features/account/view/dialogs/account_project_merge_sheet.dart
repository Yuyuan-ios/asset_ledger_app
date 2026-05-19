import 'package:flutter/material.dart';

import '../../../../core/foundation/typography.dart';
import '../../../../patterns/layout/bottom_sheet_shell_pattern.dart';
import '../../../../tokens/mapper/account_tokens.dart';
import '../../../../tokens/mapper/bottom_sheet_tokens.dart';
import '../../../../tokens/mapper/color_tokens.dart';
import 'account_project_merge_sheet_data.dart';
import 'account_project_merge_sheet_store.dart';

class MergeProjectSheetResult {
  final String contact;
  final List<String> projectIds;
  final List<String> projectKeys;

  const MergeProjectSheetResult({
    required this.contact,
    required this.projectIds,
    required this.projectKeys,
  });
}

typedef ConfirmMergeProjects =
    Future<void> Function(MergeProjectSheetResult result);

Future<MergeProjectSheetResult?> showAccountProjectMergeSheet(
  BuildContext context, {
  required List<MergeProjectSheetContactGroup> groups,
  required ConfirmMergeProjects onConfirmMerge,
  required ValueChanged<String> onError,
}) {
  return showAppBottomSheet<MergeProjectSheetResult>(
    context: context,
    builder: (_) => AccountProjectMergeSheet(
      groups: groups,
      onConfirmMerge: onConfirmMerge,
      onError: onError,
    ),
  );
}

class AccountProjectMergeSheet extends StatefulWidget {
  const AccountProjectMergeSheet({
    super.key,
    required this.groups,
    required this.onConfirmMerge,
    required this.onError,
  });

  final List<MergeProjectSheetContactGroup> groups;
  final ConfirmMergeProjects onConfirmMerge;
  final ValueChanged<String> onError;

  @override
  State<AccountProjectMergeSheet> createState() =>
      _AccountProjectMergeSheetState();
}

class _AccountProjectMergeSheetState extends State<AccountProjectMergeSheet> {
  late final MergeProjectSheetStore _store;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _store = MergeProjectSheetStore(groups: widget.groups);
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (!_store.canConfirm || _submitting) return;

    final result = MergeProjectSheetResult(
      contact: _store.selectedContact!,
      projectIds: _store.selectedProjectIds.toList(growable: false),
      projectKeys: _store.selectedProjectKeys.toList(growable: false),
    );

    setState(() => _submitting = true);
    try {
      await widget.onConfirmMerge(result);
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) return;
      widget.onError('合并失败：${_messageForError(error)}');
      setState(() => _submitting = false);
    }
  }

  String _messageForError(Object error) {
    if (error is ArgumentError && error.message != null) {
      return error.message.toString();
    }
    if (error is StateError) return error.message;
    return error.toString();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _store,
      builder: (context, _) {
        return AppBottomSheetShell(
          title: '合并项目',
          scrollable: true,
          contentPadding: const EdgeInsets.fromLTRB(
            BottomSheetTokens.outerHPadding,
            0,
            BottomSheetTokens.outerHPadding,
            BottomSheetTokens.shellContentBottomPadding,
          ),
          onCancel: () => Navigator.of(context).pop(),
          onConfirm: _store.canConfirm && !_submitting ? _confirm : null,
          confirmText: _submitting ? '合并中' : '确认',
          child: widget.groups.isEmpty
              ? const _MergeSheetEmptyState()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final group in widget.groups)
                      _MergeContactGroupView(
                        group: group,
                        selectedProjectKeys: _store.selectedProjectKeys,
                        onToggle: _submitting
                            ? null
                            : (item) =>
                                  _store.toggleProject(item, group.contact),
                      ),
                  ],
                ),
        );
      },
    );
  }
}

class _MergeSheetEmptyState extends StatelessWidget {
  const _MergeSheetEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          '暂无可合并项目',
          style: AppTypography.bodySecondary(
            context,
            fontSize: 14,
            color: TimingColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _MergeContactGroupView extends StatelessWidget {
  const _MergeContactGroupView({
    required this.group,
    required this.selectedProjectKeys,
    required this.onToggle,
  });

  final MergeProjectSheetContactGroup group;
  final Set<String> selectedProjectKeys;
  final ValueChanged<MergeProjectSheetItem>? onToggle;

  @override
  Widget build(BuildContext context) {
    final titleStyle = AppTypography.sectionTitle(
      context,
      fontSize: AccountTokens.projectTitleFontSize,
      fontWeight: AccountTokens.projectTitleWeight,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(group.contact, style: titleStyle),
          const SizedBox(height: 10),
          if (group.unmergedItems.isNotEmpty) ...[
            const _MergeSheetSectionLabel('未合并'),
            const SizedBox(height: 4),
            for (final item in group.unmergedItems)
              _MergeProjectRow(
                item: item,
                selected: selectedProjectKeys.contains(item.projectKey),
                onTap: onToggle == null ? null : () => onToggle!(item),
              ),
          ],
          if (group.mergedItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            const _MergeSheetSectionLabel('已合并'),
            const SizedBox(height: 4),
            for (final item in group.mergedItems)
              _MergeProjectRow(item: item, selected: true, onTap: null),
          ],
        ],
      ),
    );
  }
}

class _MergeSheetSectionLabel extends StatelessWidget {
  const _MergeSheetSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTypography.bodySecondary(
        context,
        fontSize: 13,
        color: TimingColors.textSecondary,
      ),
    );
  }
}

class _MergeProjectRow extends StatelessWidget {
  const _MergeProjectRow({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final MergeProjectSheetItem item;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = item.isMerged;
    final color = disabled ? TimingColors.textSecondary : AppColors.textPrimary;
    final textStyle = AppTypography.body(
      context,
      fontSize: 15,
      color: color,
      fontWeight: FontWeight.w400,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected && !disabled
            ? AppColors.brand.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AccountTokens.projectCardRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AccountTokens.projectCardRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Checkbox(
                  value: selected,
                  onChanged: disabled || onTap == null ? null : (_) => onTap!(),
                  visualDensity: VisualDensity.compact,
                ),
                Expanded(
                  child: Text(
                    item.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
