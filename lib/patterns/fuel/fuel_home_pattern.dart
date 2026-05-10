import 'package:flutter/material.dart';

import '../../components/feedback/store_error_banner.dart';
import '../layout/phone_page_layout.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/fuel_tokens.dart';

class FuelHomePattern extends StatelessWidget {
  const FuelHomePattern({
    super.key,
    required this.header,
    required this.summary,
    required this.filter,
    required this.records,
    required this.loading,
    this.hasFilter = true,
    this.error,
    this.onRetry,
  });

  final Widget header;
  final Widget summary;
  final Widget filter;
  final Widget records;
  final bool loading;
  final bool hasFilter;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
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
                    header,
                    const SizedBox(height: FuelTokens.homeHeaderBottomGap),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(
                            FuelTokens.homeContentPadding,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (loading) ...[
                                const LinearProgressIndicator(),
                                const SizedBox(
                                  height: FuelTokens.homeLoadingBottomGap,
                                ),
                              ],
                              if (error != null &&
                                  error!.trim().isNotEmpty) ...[
                                StoreErrorBanner(
                                  message: error!,
                                  onRetry: loading ? null : onRetry,
                                ),
                                const SizedBox(
                                  height: FuelTokens.homeErrorBottomGap,
                                ),
                              ],
                              summary,
                              if (hasFilter) ...[
                                const SizedBox(
                                  height: FuelTokens.homeSectionGap,
                                ),
                                filter,
                              ],
                              const SizedBox(height: FuelTokens.homeSectionGap),
                              records,
                              const SizedBox(
                                height: FuelTokens.homeListBottomGap,
                              ),
                            ],
                          ),
                        ),
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
