import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../patterns/device/legal_section_pattern.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  List<LegalSectionContent> _sections(AppLocalizations l10n) {
    return [
      LegalSectionContent(
        title: l10n.deviceTermsSection1Title,
        body: l10n.deviceTermsSection1Body,
      ),
      LegalSectionContent(
        title: l10n.deviceTermsSection2Title,
        body: l10n.deviceTermsSection2Body,
      ),
      LegalSectionContent(
        title: l10n.deviceTermsSection3Title,
        body: l10n.deviceTermsSection3Body,
      ),
      LegalSectionContent(
        title: l10n.deviceTermsSection4Title,
        body: l10n.deviceTermsSection4Body,
      ),
      LegalSectionContent(
        title: l10n.deviceTermsSection5Title,
        body: l10n.deviceTermsSection5Body,
      ),
      LegalSectionContent(
        title: l10n.deviceTermsSection6Title,
        body: l10n.deviceTermsSection6Body,
      ),
      LegalSectionContent(
        title: l10n.deviceTermsSection7Title,
        body: l10n.deviceTermsSection7Body,
      ),
      LegalSectionContent(
        title: l10n.deviceTermsSection8Title,
        body: l10n.deviceTermsSection8Body,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LegalDocumentPage(
      title: l10n.deviceTermsTitle,
      sections: _sections(l10n),
      effectiveDateText: l10n.deviceTermsEffectiveDate,
    );
  }
}
