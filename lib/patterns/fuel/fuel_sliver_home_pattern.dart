import 'package:flutter/material.dart';

import '../../components/feedback/store_error_banner.dart';
import '../../components/layout/pinned_header_delegate.dart';
import '../../data/models/fuel_log.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/fuel_tokens.dart';
import '../layout/phone_page_layout.dart';
import '../timing/records_title_pattern.dart';
import 'fuel_pinned_records_control_header.dart';
import 'fuel_recent_records_pattern.dart';

class FuelSliverHomePattern extends StatefulWidget {
  const FuelSliverHomePattern({
    super.key,
    required this.header,
    required this.summary,
    required this.filter,
    required this.logs,
    required this.leadingBuilder,
    required this.titleBuilder,
    required this.subtitleBuilder,
    required this.onTap,
    this.onConfirmDelete,
    this.onDelete,
    required this.loading,
    this.error,
    this.onRetry,
  });

  final Widget header;
  final Widget summary;
  final Widget filter;
  final List<FuelLog> logs;
  final Widget Function(FuelLog log) leadingBuilder;
  final String Function(FuelLog log) titleBuilder;
  final String Function(FuelLog log) subtitleBuilder;
  final ValueChanged<FuelLog> onTap;
  final Future<bool> Function(FuelLog log)? onConfirmDelete;
  final DeleteFuelRecordCallback? onDelete;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;

  @override
  State<FuelSliverHomePattern> createState() => _FuelSliverHomePatternState();
}

class _FuelSliverHomePatternState extends State<FuelSliverHomePattern> {
  final Set<String> _locallyRemovedKeys = <String>{};

  @override
  void didUpdateWidget(covariant FuelSliverHomePattern oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentKeys = fuelRecentRecordKeys(widget.logs);
    _locallyRemovedKeys.removeWhere((key) => !currentKeys.contains(key));
  }

  Future<void> _deleteWithOptimisticRemove(FuelLog log) async {
    if (widget.onDelete == null) return;
    final key = fuelRecentRecordKey(log);
    setState(() => _locallyRemovedKeys.add(key));
    final ok = await widget.onDelete!(log);
    if (!ok && mounted) {
      setState(() => _locallyRemovedKeys.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleLogs = widget.logs
        .where((log) => !_locallyRemovedKeys.contains(fuelRecentRecordKey(log)))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding =
                  PhonePageLayout.resolveHorizontalPadding(
                    constraints.maxWidth,
                    basePadding: FuelTokens.homePageHorizontalPadding,
                  );

              return Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  children: [
                    widget.header,
                    const SizedBox(height: FuelTokens.homeHeaderBottomGap),
                    Expanded(
                      child: CustomScrollView(
                        slivers: [
                          if (widget.loading)
                            const SliverToBoxAdapter(
                              child: Column(
                                children: [
                                  LinearProgressIndicator(),
                                  SizedBox(
                                    height: FuelTokens.homeLoadingBottomGap,
                                  ),
                                ],
                              ),
                            ),
                          if (widget.error != null &&
                              widget.error!.trim().isNotEmpty)
                            SliverToBoxAdapter(
                              child: Column(
                                children: [
                                  StoreErrorBanner(
                                    message: widget.error!,
                                    onRetry: widget.loading
                                        ? null
                                        : widget.onRetry,
                                  ),
                                  const SizedBox(
                                    height: FuelTokens.homeErrorBottomGap,
                                  ),
                                ],
                              ),
                            ),
                          SliverToBoxAdapter(child: widget.summary),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: FuelTokens.homeSectionGap),
                          ),
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: PinnedHeaderDelegate(
                              height: FuelTokens.pinnedRecordsHeaderHeight,
                              child: FuelPinnedRecordsControlHeader(
                                filter: widget.filter,
                                recordsTitle: RecordsTitle(
                                  count: visibleLogs.length,
                                ),
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: FuelRecordsListContent(
                              logs: visibleLogs,
                              leadingBuilder: widget.leadingBuilder,
                              titleBuilder: widget.titleBuilder,
                              subtitleBuilder: widget.subtitleBuilder,
                              onTap: widget.onTap,
                              onConfirmDelete: widget.onConfirmDelete,
                              onDelete: _deleteWithOptimisticRemove,
                            ),
                          ),
                          const SliverToBoxAdapter(
                            child: SizedBox(
                              height: FuelTokens.homeListBottomGap,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
