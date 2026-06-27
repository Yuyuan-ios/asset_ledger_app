import 'package:flutter/material.dart';

import '../../core/foundation/typography.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../timing/section_header_pattern.dart';

class DevicePageHeaderSearch extends StatelessWidget {
  const DevicePageHeaderSearch({
    super.key,
    this.title,
    this.searchHint,
    this.showTitle = true,
  });

  final String? title;
  final String? searchHint;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final resolvedTitle = title ?? l10n.devicePageTitle;
    final resolvedSearchHint = searchHint ?? l10n.deviceSearchHint;
    return Column(
      children: [
        if (showTitle)
          SectionHeader(title: resolvedTitle, showAddButton: false),
        const SizedBox(height: DevicePageLayoutTokens.headerToSearchGap),
        Container(
          height: DevicePageLayoutTokens.searchFieldHeight,
          decoration: BoxDecoration(
            color: const Color(0xFFE5E5EA),
            borderRadius: BorderRadius.circular(
              DevicePageLayoutTokens.searchFieldRadius,
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: DevicePageLayoutTokens.searchFieldHorizontalPadding,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.search,
                size: DevicePageLayoutTokens.searchIconSize,
                color: Color(0xFF8E8E93),
              ),
              const SizedBox(width: DevicePageLayoutTokens.searchIconGap),
              Text(
                resolvedSearchHint,
                style: AppTypography.body(
                  context,
                  fontSize: DevicePageLayoutTokens.searchTextFontSize,
                  fontWeight: DevicePageLayoutTokens.searchTextFontWeight,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
