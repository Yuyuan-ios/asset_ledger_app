import 'package:flutter/material.dart';

class DevicePageLayoutTokens {
  const DevicePageLayoutTokens._();

  static const double contentWidth = 393;
  static const double horizontalPadding = 8;
  static const double bottomPadding = 95;
  static const double loadErrorTopGap = 8;
  static const double headerToSearchGap = 2;
  static const double searchFieldHeight = 40;
  static const double searchFieldRadius = 8;
  static const double searchFieldHorizontalPadding = 4;
  static const double searchIconSize = 24;
  static const double searchIconGap = 10;
  static const double searchTextFontSize = 16;
  static const FontWeight searchTextFontWeight = FontWeight.w300;
}

class DeviceSectionTokens {
  const DeviceSectionTokens._();

  static const double topGap = 10;
  static const double titleToCardGap = 4;
  static const double horizontalInset = 2;
  static const double titleFontSize = 16;
  static const FontWeight titleFontWeight = FontWeight.w300;
  static const double titleAlpha = 0.7;
}

class DeviceActionCardTokens {
  const DeviceActionCardTokens._();

  static const double height = 48;
  static const double radius = 8;
  static const double horizontalPadding = 4;
  static const double leadingGap = 10;
  static const double titleFontSize = 16;
  static const FontWeight titleFontWeight = FontWeight.w700;
  static const double trailingIconSize = 24;
  static const Color backgroundColor = Color(0xFFFFFFFF);
  static const Color titleColor = Color(0xFF000000);
  static const Color trailingIconColor = Color(0xFF8E8E93);
  static const double premiumBadgeSize = 34;
  static const double premiumBadgeRadius = 8;
  static const double premiumBadgeIconSize = 20;
  static const double addDeviceLeadingIconSize = 28;
}

class DeviceManagementGridTokens {
  const DeviceManagementGridTokens._();

  static const double height = 164;
  static const int slots = 8;
  static const int columns = 4;
  static const double crossSpacing = 20;
  static const double mainSpacing = 10;
  static const double aspectRatio = 0.67;
  static const double padLeft = 16;
  static const double padTop = 14;
  static const double padRight = 16;
  static const double padBottom = 8;
  static const double avatarSize = 45;
  static const double avatarRadius = 22.5;
  static const double labelTopGap = 2;
  static const double labelFontSize = 14;
  static const FontWeight labelFontWeight = FontWeight.w700;
  static const double labelAlpha = 0.7;
  static const double placeholderAlpha = 0.72;
  static const double placeholderRadius = 4;
  static const double placeholderLabelFontSize = 11;
  static const double borderRadius = 8;
  static const Color backgroundColor = Color(0xFFFFFFFF);
  static const Color borderColor = Color(0x33000000);
  static const Color labelColor = Color(0xFF000000);
  static const Color placeholderColor = Color(0xFFFFFFFF);
}

class DeviceAvatarPickerTokens {
  const DeviceAvatarPickerTokens._();

  static const int forwardDurationMs = 500;
  static const int reverseDurationMs = 320;
  static const double titleFontSize = 22;
  static const FontWeight titleFontWeight = FontWeight.w700;
  static const double pickerPadLeft = 16;
  static const double pickerPadTop = 8;
  static const double pickerPadRight = 16;
  static const double pickerPadBottom = 8;
  static const double emptyTextFontSize = 14;
  static const double emptyTextAlpha = 0.6;
  static const double segmentHeight = 44;
  static const double segmentPadding = 2;
  static const double segmentItemHeight = 40;
  static const double segmentRadius = 10;
  static const double segmentItemFontSize = 15;
  static const FontWeight segmentItemSelectedWeight = FontWeight.w700;
  static const FontWeight segmentItemUnselectedWeight = FontWeight.w500;
  static const Color segmentBackground = Color(0xFFE5E5EA);
  static const Color segmentBorderColor = Color(0x33000000);
}

class DeviceEditorBrandRowTokens {
  const DeviceEditorBrandRowTokens._();

  static const double brandTextFontSize = 16;
  static const FontWeight brandTextFontWeight = FontWeight.w500;
  static const double selectorTextFontSize = 16;
  static const FontWeight selectorTextFontWeight = FontWeight.w500;
  static const double customRowTopGap = 2;
  static const double customInfoFontSize = 13;
  static const double customInfoAlpha = 0.6;
}

class DeviceBrandPickerTokens {
  const DeviceBrandPickerTokens._();

  static const int defaultCrossAxisCount = 5;
  static const double defaultAvatarRadius = 22;
  static const double defaultGridSpacing = 10;

  static const double listPadHorizontal = 16;
  static const double listPadVertical = 8;
  static const double countryHeaderBottomGap = 8;
  static const double countryGroupBottomGap = 16;
  static const double countryMarkerWidth = 4;
  static const double countryMarkerHeight = 16;
  static const double countryMarkerRadius = 8;
  static const double countryMarkerToTitleGap = 8;
  static const FontWeight countryTitleWeight = FontWeight.w700;

  static const double itemInkRadius = 16;
  static const double itemOuterPad = 4;
  static const double itemSelectedBorderWidth = 2.2;
  static const double itemUnselectedBorderWidth = 1;
  static const double itemLabelTopGap = 6;
  static const double itemLabelBoxHeight = 34;
  static const double itemLabelLineHeight = 1.1;
  static const FontWeight itemLabelSelectedWeight = FontWeight.w700;
  static const FontWeight itemLabelUnselectedWeight = FontWeight.w500;
}

class DeviceTokens {
  const DeviceTokens._();

  // Device page layout
  static const double pageContentWidth = DevicePageLayoutTokens.contentWidth;
  static const double pageHorizontalPadding =
      DevicePageLayoutTokens.horizontalPadding;
  static const double pageBottomPadding = DevicePageLayoutTokens.bottomPadding;
  static const double loadErrorTopGap = DevicePageLayoutTokens.loadErrorTopGap;

  // Section title + card rhythm
  static const double headerToSearchGap =
      DevicePageLayoutTokens.headerToSearchGap;
  static const double searchFieldHeight =
      DevicePageLayoutTokens.searchFieldHeight;
  static const double searchFieldRadius =
      DevicePageLayoutTokens.searchFieldRadius;
  static const double searchFieldHorizontalPadding =
      DevicePageLayoutTokens.searchFieldHorizontalPadding;
  static const double searchIconSize = DevicePageLayoutTokens.searchIconSize;
  static const double searchIconGap = DevicePageLayoutTokens.searchIconGap;
  static const double searchTextFontSize =
      DevicePageLayoutTokens.searchTextFontSize;
  static const FontWeight searchTextFontWeight =
      DevicePageLayoutTokens.searchTextFontWeight;
  static const double sectionTopGap = DeviceSectionTokens.topGap;
  static const double sectionTitleToCardGap =
      DeviceSectionTokens.titleToCardGap;
  static const double sectionHorizontalInset =
      DeviceSectionTokens.horizontalInset;

  // Section title style
  static const double sectionTitleFontSize = DeviceSectionTokens.titleFontSize;
  static const FontWeight sectionTitleFontWeight =
      DeviceSectionTokens.titleFontWeight;
  static const double sectionTitleAlpha = DeviceSectionTokens.titleAlpha;

  // Action card
  static const double actionCardHeight = DeviceActionCardTokens.height;
  static const double actionCardRadius = DeviceActionCardTokens.radius;
  static const double actionCardHorizontalPadding =
      DeviceActionCardTokens.horizontalPadding;
  static const double actionCardLeadingGap = DeviceActionCardTokens.leadingGap;
  static const double actionCardTitleFontSize =
      DeviceActionCardTokens.titleFontSize;
  static const FontWeight actionCardTitleFontWeight =
      DeviceActionCardTokens.titleFontWeight;
  static const double actionCardTrailingIconSize =
      DeviceActionCardTokens.trailingIconSize;
  static const Color actionCardBackgroundColor =
      DeviceActionCardTokens.backgroundColor;
  static const Color actionCardTitleColor = DeviceActionCardTokens.titleColor;
  static const Color actionCardTrailingIconColor =
      DeviceActionCardTokens.trailingIconColor;
  static const double premiumBadgeSize =
      DeviceActionCardTokens.premiumBadgeSize;
  static const double premiumBadgeRadius =
      DeviceActionCardTokens.premiumBadgeRadius;
  static const double premiumBadgeIconSize =
      DeviceActionCardTokens.premiumBadgeIconSize;
  static const double addDeviceLeadingIconSize =
      DeviceActionCardTokens.addDeviceLeadingIconSize;

  // Management grid
  static const double managementGridHeight = DeviceManagementGridTokens.height;
  static const int managementGridSlots = DeviceManagementGridTokens.slots;
  static const int managementGridColumns = DeviceManagementGridTokens.columns;
  static const double managementGridCrossSpacing =
      DeviceManagementGridTokens.crossSpacing;
  static const double managementGridMainSpacing =
      DeviceManagementGridTokens.mainSpacing;
  static const double managementGridAspectRatio =
      DeviceManagementGridTokens.aspectRatio;
  static const double managementGridPadLeft =
      DeviceManagementGridTokens.padLeft;
  static const double managementGridPadTop = DeviceManagementGridTokens.padTop;
  static const double managementGridPadRight =
      DeviceManagementGridTokens.padRight;
  static const double managementGridPadBottom =
      DeviceManagementGridTokens.padBottom;
  static const double managementGridAvatarSize =
      DeviceManagementGridTokens.avatarSize;
  static const double managementGridAvatarRadius =
      DeviceManagementGridTokens.avatarRadius;
  static const double managementGridLabelTopGap =
      DeviceManagementGridTokens.labelTopGap;
  static const double managementGridLabelFontSize =
      DeviceManagementGridTokens.labelFontSize;
  static const FontWeight managementGridLabelFontWeight =
      DeviceManagementGridTokens.labelFontWeight;
  static const double managementGridLabelAlpha =
      DeviceManagementGridTokens.labelAlpha;
  static const double managementGridPlaceholderAlpha =
      DeviceManagementGridTokens.placeholderAlpha;
  static const double managementGridPlaceholderRadius =
      DeviceManagementGridTokens.placeholderRadius;
  static const double managementGridPlaceholderLabelFontSize =
      DeviceManagementGridTokens.placeholderLabelFontSize;
  static const double managementGridBorderRadius =
      DeviceManagementGridTokens.borderRadius;
  static const Color managementGridBackgroundColor =
      DeviceManagementGridTokens.backgroundColor;
  static const Color managementGridBorderColor =
      DeviceManagementGridTokens.borderColor;
  static const Color managementGridLabelColor =
      DeviceManagementGridTokens.labelColor;
  static const Color managementGridPlaceholderColor =
      DeviceManagementGridTokens.placeholderColor;

  // Avatar picker route + segment
  static const int avatarPickerForwardDurationMs =
      DeviceAvatarPickerTokens.forwardDurationMs;
  static const int avatarPickerReverseDurationMs =
      DeviceAvatarPickerTokens.reverseDurationMs;
  static const double avatarTypeSegmentHeight =
      DeviceAvatarPickerTokens.segmentHeight;
  static const double avatarTypeSegmentPadding =
      DeviceAvatarPickerTokens.segmentPadding;
  static const double avatarTypeSegmentItemHeight =
      DeviceAvatarPickerTokens.segmentItemHeight;
  static const double avatarTypeSegmentRadius =
      DeviceAvatarPickerTokens.segmentRadius;
  static const double avatarTypeSegmentItemFontSize =
      DeviceAvatarPickerTokens.segmentItemFontSize;
  static const FontWeight avatarTypeSegmentItemSelectedWeight =
      DeviceAvatarPickerTokens.segmentItemSelectedWeight;
  static const FontWeight avatarTypeSegmentItemUnselectedWeight =
      DeviceAvatarPickerTokens.segmentItemUnselectedWeight;
  static const Color avatarTypeSegmentBackgroundColor =
      DeviceAvatarPickerTokens.segmentBackground;
  static const Color avatarTypeSegmentBorderColor =
      DeviceAvatarPickerTokens.segmentBorderColor;
  static const double avatarPickerTitleFontSize =
      DeviceAvatarPickerTokens.titleFontSize;
  static const FontWeight avatarPickerTitleFontWeight =
      DeviceAvatarPickerTokens.titleFontWeight;
  static const double avatarPickerPadLeft =
      DeviceAvatarPickerTokens.pickerPadLeft;
  static const double avatarPickerPadTop =
      DeviceAvatarPickerTokens.pickerPadTop;
  static const double avatarPickerPadRight =
      DeviceAvatarPickerTokens.pickerPadRight;
  static const double avatarPickerPadBottom =
      DeviceAvatarPickerTokens.pickerPadBottom;
  static const double avatarPickerEmptyTextFontSize =
      DeviceAvatarPickerTokens.emptyTextFontSize;
  static const double avatarPickerEmptyTextAlpha =
      DeviceAvatarPickerTokens.emptyTextAlpha;

  // Device editor brand row
  static const double editorBrandTextFontSize =
      DeviceEditorBrandRowTokens.brandTextFontSize;
  static const FontWeight editorBrandTextFontWeight =
      DeviceEditorBrandRowTokens.brandTextFontWeight;
  static const double editorBrandSelectorTextFontSize =
      DeviceEditorBrandRowTokens.selectorTextFontSize;
  static const FontWeight editorBrandSelectorTextFontWeight =
      DeviceEditorBrandRowTokens.selectorTextFontWeight;
  static const double editorBrandCustomRowTopGap =
      DeviceEditorBrandRowTokens.customRowTopGap;
  static const double editorBrandCustomInfoFontSize =
      DeviceEditorBrandRowTokens.customInfoFontSize;
  static const double editorBrandCustomInfoAlpha =
      DeviceEditorBrandRowTokens.customInfoAlpha;

  // Brand picker
  static const int brandPickerDefaultCrossAxisCount =
      DeviceBrandPickerTokens.defaultCrossAxisCount;
  static const double brandPickerDefaultAvatarRadius =
      DeviceBrandPickerTokens.defaultAvatarRadius;
  static const double brandPickerDefaultGridSpacing =
      DeviceBrandPickerTokens.defaultGridSpacing;
  static const double brandPickerListPadHorizontal =
      DeviceBrandPickerTokens.listPadHorizontal;
  static const double brandPickerListPadVertical =
      DeviceBrandPickerTokens.listPadVertical;
  static const double brandPickerCountryHeaderBottomGap =
      DeviceBrandPickerTokens.countryHeaderBottomGap;
  static const double brandPickerCountryGroupBottomGap =
      DeviceBrandPickerTokens.countryGroupBottomGap;
  static const double brandPickerCountryMarkerWidth =
      DeviceBrandPickerTokens.countryMarkerWidth;
  static const double brandPickerCountryMarkerHeight =
      DeviceBrandPickerTokens.countryMarkerHeight;
  static const double brandPickerCountryMarkerRadius =
      DeviceBrandPickerTokens.countryMarkerRadius;
  static const double brandPickerCountryMarkerToTitleGap =
      DeviceBrandPickerTokens.countryMarkerToTitleGap;
  static const FontWeight brandPickerCountryTitleWeight =
      DeviceBrandPickerTokens.countryTitleWeight;
  static const double brandPickerItemInkRadius =
      DeviceBrandPickerTokens.itemInkRadius;
  static const double brandPickerItemOuterPad =
      DeviceBrandPickerTokens.itemOuterPad;
  static const double brandPickerItemSelectedBorderWidth =
      DeviceBrandPickerTokens.itemSelectedBorderWidth;
  static const double brandPickerItemUnselectedBorderWidth =
      DeviceBrandPickerTokens.itemUnselectedBorderWidth;
  static const double brandPickerItemLabelTopGap =
      DeviceBrandPickerTokens.itemLabelTopGap;
  static const double brandPickerItemLabelBoxHeight =
      DeviceBrandPickerTokens.itemLabelBoxHeight;
  static const double brandPickerItemLabelLineHeight =
      DeviceBrandPickerTokens.itemLabelLineHeight;
  static const FontWeight brandPickerItemLabelSelectedWeight =
      DeviceBrandPickerTokens.itemLabelSelectedWeight;
  static const FontWeight brandPickerItemLabelUnselectedWeight =
      DeviceBrandPickerTokens.itemLabelUnselectedWeight;

  // Upgrade page
  static const Color upgradeHeaderBg = Color(0xFFEDEAFF);
  static const Color upgradePageBg = Color(0xFFFF7F2A);
  static const Color upgradeSurface = Color(0xFFFFFFFF);
  static const Color upgradeAccent = Color(0xFF5B3FDE);
  static const Color upgradeHeaderTitleColor = Color(0xFF000000);
  static const Color upgradeSubText = Color(0xFF5A5A5A);
  static const Color upgradeBadgeBg = Color(0xFFB5E61D);
  static const Color upgradeBadgeText = Color(0xFF1C1C1E);
  static const Color upgradeFooterTextColor = Color(0xFFFFFFFF);
  static const double upgradeHeaderPadLeft = 8;
  static const double upgradeHeaderPadRight = 12;
  static const double upgradeHeaderPadBottom = 10;
  static const double upgradeHeaderDividerHeight = 1;
  static const double upgradeHeaderDividerAlpha = 0.08;
  static const double upgradeBackIconSize = 22;
  static const double upgradeBackLabelSize = 18;
  static const FontWeight upgradeBackLabelWeight = FontWeight.w500;
  static const double upgradeHeaderTitleSize = 24;
  static const double upgradeHeaderTitleLineHeight = 1.2;
  static const FontWeight upgradeHeaderTitleWeight = FontWeight.w700;
  static const double upgradeHeaderTrailingSpacer = 88;
  static const double upgradeListPadH = 24;
  static const double upgradeListPadTop = 8;
  static const double upgradeListPadBottom = 24;
  static const double upgradeHeroTopGap = 6;
  static const double upgradeHeroHeight = 158;
  static const double upgradeHeroToBenefitsGap = 58;
  static const double upgradePlanGap = 14;
  static const double upgradeContinueTopGap = 20;
  static const double upgradeContinueHeight = 50;
  static const double upgradeContinueRadius = 30;
  static const double upgradeContinueTextSize = 20;
  static const FontWeight upgradeContinueTextWeight = FontWeight.w700;
  static const double upgradeFooterTopGap = 22;
  static const double upgradeFooterBottomPadding = 18;
  static const double upgradeBenefitBottom = 18;
  static const double upgradeBenefitIconRadius = 18;
  static const double upgradeBenefitIconGap = 18;
  static const double upgradeBenefitTextSize = 20;
  static const FontWeight upgradeBenefitTextWeight = FontWeight.w500;
  static const double upgradePlanRadius = 24;
  static const double upgradePlanBorderEmphasized = 3;
  static const double upgradePlanBorderNormal = 1;
  static const double upgradePlanPadLeft = 18;
  static const double upgradePlanPadTop = 18;
  static const double upgradePlanPadRight = 18;
  static const double upgradePlanPadBottom = 16;
  static const double upgradePlanTitleSize = 22;
  static const FontWeight upgradePlanTitleWeight = FontWeight.w700;
  static const double upgradePlanSubtitle1Size = 14;
  static const double upgradePlanSubtitle2TopGap = 6;
  static const double upgradePlanSubtitle2Size = 18;
  static const double upgradePlanTitleSubtitleGap = 6;
  static const double upgradeBadgePadH = 18;
  static const double upgradeBadgePadV = 10;
  static const double upgradeBadgeRadius = 12;
  static const double upgradeBadgeTextSize = 18;
  static const FontWeight upgradeBadgeTextWeight = FontWeight.w700;
  static const double upgradeFooterTextSize = 16;
}

class DeviceLegalTokens {
  const DeviceLegalTokens._();

  static const double appBarTitleSize = 22;
  static const FontWeight appBarTitleWeight = FontWeight.w700;

  static const double pagePadLeft = 20;
  static const double pagePadTop = 8;
  static const double pagePadRight = 20;
  static const double pagePadBottom = 24;
  static const double effectiveTopGap = 8;

  static const double sectionBottomGap = 16;
  static const double sectionTitleSize = 16;
  static const FontWeight sectionTitleWeight = FontWeight.w700;
  static const double sectionBodyTopGap = 6;
  static const double sectionBodySize = 14;
  static const double sectionBodyLineHeight = 1.45;
  static const double sectionBodyAlpha = 0.7;

  static const double effectiveFontSize = 13;
  static const double effectiveAlpha = 0.55;
}
