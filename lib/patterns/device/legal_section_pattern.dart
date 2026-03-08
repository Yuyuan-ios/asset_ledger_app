import 'package:flutter/material.dart';

import '../../core/foundation/typography.dart';
import '../../tokens/mapper/core_tokens.dart';

class LegalSectionContent {
  const LegalSectionContent({required this.title, required this.body});

  final String title;
  final String body;
}

class LegalDocumentPage extends StatelessWidget {
  const LegalDocumentPage({
    super.key,
    required this.title,
    required this.sections,
    required this.effectiveDateText,
  });

  final String title;
  final List<LegalSectionContent> sections;
  final String effectiveDateText;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          title,
          style: AppTypography.sectionTitle(
            context,
            fontSize: DeviceLegalTokens.appBarTitleSize,
            fontWeight: DeviceLegalTokens.appBarTitleWeight,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          DeviceLegalTokens.pagePadLeft,
          DeviceLegalTokens.pagePadTop,
          DeviceLegalTokens.pagePadRight,
          DeviceLegalTokens.pagePadBottom,
        ),
        children: [
          for (final section in sections)
            LegalSectionItem(section.title, section.body),
          const SizedBox(height: DeviceLegalTokens.effectiveTopGap),
          LegalEffectiveDateText(text: effectiveDateText),
        ],
      ),
    );
  }
}

class LegalSectionItem extends StatelessWidget {
  const LegalSectionItem(this.title, this.body, {super.key});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: DeviceLegalTokens.sectionBottomGap,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.body(
              context,
              fontSize: DeviceLegalTokens.sectionTitleSize,
              fontWeight: DeviceLegalTokens.sectionTitleWeight,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: DeviceLegalTokens.sectionBodyTopGap),
          Text(
            body,
            style: AppTypography.body(
              context,
              fontSize: DeviceLegalTokens.sectionBodySize,
              height: DeviceLegalTokens.sectionBodyLineHeight,
              color: Colors.black.withValues(
                alpha: DeviceLegalTokens.sectionBodyAlpha,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LegalEffectiveDateText extends StatelessWidget {
  const LegalEffectiveDateText({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style:
          AppTypography.bodySecondary(
            context,
            fontSize: DeviceLegalTokens.effectiveFontSize,
            color: Colors.black.withValues(
              alpha: DeviceLegalTokens.effectiveAlpha,
            ),
          ) ??
          TextStyle(
            fontSize: DeviceLegalTokens.effectiveFontSize,
            color: Colors.black.withValues(
              alpha: DeviceLegalTokens.effectiveAlpha,
            ),
          ),
    );
  }
}
