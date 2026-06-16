import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../patterns/device/legal_section_pattern.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  List<LegalSectionContent> _sections(AppLocalizations l10n) {
    return [
      LegalSectionContent(
        title: l10n.devicePrivacySection1Title,
        body: l10n.devicePrivacySection1Body,
      ),
      LegalSectionContent(
        title: l10n.devicePrivacySection2Title,
        body: l10n.devicePrivacySection2Body,
      ),
      LegalSectionContent(
        title: l10n.devicePrivacySection3Title,
        body: l10n.devicePrivacySection3Body,
      ),
      LegalSectionContent(
        title: l10n.devicePrivacySection4Title,
        body: l10n.devicePrivacySection4Body,
      ),
      LegalSectionContent(
        title: l10n.devicePrivacySection5Title,
        body: l10n.devicePrivacySection5Body,
      ),
      LegalSectionContent(
        title: l10n.devicePrivacySection6Title,
        body: l10n.devicePrivacySection6Body,
      ),
      LegalSectionContent(
        title: l10n.devicePrivacySection7Title,
        body: l10n.devicePrivacySection7Body,
      ),
      LegalSectionContent(
        title: l10n.devicePrivacySection8Title,
        body: l10n.devicePrivacySection8Body,
      ),
      LegalSectionContent(
        title: l10n.devicePrivacySection9Title,
        body: l10n.devicePrivacySection9Body,
      ),
      LegalSectionContent(
        title: l10n.devicePrivacySection10Title,
        body: l10n.devicePrivacySection10Body,
      ),
      LegalSectionContent(
        title: l10n.devicePrivacySection11Title,
        body: l10n.devicePrivacySection11Body,
      ),
      LegalSectionContent(
        title: l10n.devicePrivacySection12Title,
        body: l10n.devicePrivacySection12Body,
      ),
      LegalSectionContent(
        title: l10n.devicePrivacySection13Title,
        body: l10n.devicePrivacySection13Body,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LegalDocumentPage(
      title: l10n.devicePrivacyTitle,
      sections: _sections(l10n),
      effectiveDateText: l10n.devicePrivacyEffectiveDate,
    );
  }
}
