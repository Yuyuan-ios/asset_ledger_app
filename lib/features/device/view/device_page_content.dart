import 'package:flutter/material.dart';

import '../../../components/feedback/store_error_banner.dart';
import '../../../patterns/device/device_page_header_search_pattern.dart';
import '../../../patterns/layout/phone_page_layout.dart';
import '../../../tokens/mapper/core_tokens.dart';

class DevicePageContent extends StatelessWidget {
  const DevicePageContent({
    super.key,
    required this.errorMessage,
    required this.isLoading,
    required this.onRetryLoad,
    required this.sections,
  });

  final String? errorMessage;
  final bool isLoading;
  final VoidCallback onRetryLoad;
  final List<Widget> sections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = PhonePageLayout.resolveHorizontalPadding(
              constraints.maxWidth,
              basePadding: DeviceTokens.pageHorizontalPadding,
            );

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: ListView(
                padding: const EdgeInsets.only(
                  top: 0,
                  bottom: DeviceTokens.pageBottomPadding,
                ),
                children: [
                  const DevicePageHeaderSearch(),
                  if (errorMessage != null) ...[
                    const SizedBox(height: DeviceTokens.loadErrorTopGap),
                    StoreErrorBanner(
                      message: errorMessage!,
                      onRetry: isLoading ? null : onRetryLoad,
                    ),
                  ],
                  ...sections,
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
