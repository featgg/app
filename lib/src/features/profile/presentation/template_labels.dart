import '../../../core/l10n/l10n.dart';

/// Resolves a [TemplateDefinition.titleKey] to its localized string. The single
/// place template title keys map to [AppLocalizations] getters, keeping copy out
/// of `domain` and tests. A key not handled here returns null so the totality
/// test fails loudly rather than shipping a template with no title.
String? templateTitleLabel(AppLocalizations l10n, String titleKey) =>
    switch (titleKey) {
      'templateMyRanksTitle' => l10n.templateMyRanksTitle,
      'templateMyAchievementsTitle' => l10n.templateMyAchievementsTitle,
      'templateMyLevelsTitle' => l10n.templateMyLevelsTitle,
      _ => null,
    };

/// Resolves a [TemplateSlot.labelKey] to its localized string. A key not handled
/// here returns null so the totality test fails loudly.
String? templateSlotLabel(AppLocalizations l10n, String labelKey) =>
    switch (labelKey) {
      'templateSlotRank1' => l10n.templateSlotRank1,
      'templateSlotRank2' => l10n.templateSlotRank2,
      'templateSlotRank3' => l10n.templateSlotRank3,
      'templateSlotAchievement1' => l10n.templateSlotAchievement1,
      'templateSlotAchievement2' => l10n.templateSlotAchievement2,
      'templateSlotAchievement3' => l10n.templateSlotAchievement3,
      'templateSlotLevel1' => l10n.templateSlotLevel1,
      'templateSlotLevel2' => l10n.templateSlotLevel2,
      'templateSlotLevel3' => l10n.templateSlotLevel3,
      _ => null,
    };
