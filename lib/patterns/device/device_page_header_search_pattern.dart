import 'package:flutter/material.dart';

import '../../core/foundation/typography.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/timing_tokens.dart';

class DevicePageHeaderSearch extends StatelessWidget {
  const DevicePageHeaderSearch({
    super.key,
    this.title = '设备',
    this.searchHint = '搜索',
  });

  final String title;
  final String searchHint;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TimingTokens.headerHorizontalPadding,
            0,
            TimingTokens.headerHorizontalPadding,
            TimingTokens.headerBottomPadding,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: AppTypography.pageTitle(
                context,
                fontSize: TimingTokens.headerTitleSize,
                fontWeight: FontWeight.w700,
                height: TimingTokens.headerTitleLineHeight,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
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
                searchHint,
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
