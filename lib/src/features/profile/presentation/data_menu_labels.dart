import '../../../core/l10n/l10n.dart';
import '../domain/data_menu_catalog.dart';

/// Resolves a [DataMenuItem.labelKey] / [DataMenuCategory] to its localized
/// string. This is the single place the stable string keys map to
/// [AppLocalizations] getters, keeping copy out of `domain` and tests. A key
/// not handled here returns null so the totality test fails loudly rather than
/// shipping an item with no label.
String? dataMenuItemLabel(
  AppLocalizations l10n,
  String labelKey,
) => switch (labelKey) {
  'connectionsStatRating' => l10n.connectionsStatRating,
  'connectionsStatMythicPlusRating' => l10n.connectionsStatMythicPlusRating,
  'connectionsStatWvwRank' => l10n.connectionsStatWvwRank,
  'connectionsStatHoursPlayed' => l10n.connectionsStatHoursPlayed,
  'connectionsStatVeterancyYears' => l10n.connectionsStatVeterancyYears,
  'connectionsStatTotalAchievementPoints' =>
    l10n.connectionsStatTotalAchievementPoints,
  'connectionsStatAchievementPoints' => l10n.connectionsStatAchievementPoints,
  'connectionsStatTotalAp' => l10n.connectionsStatTotalAp,
  'connectionsStatNetworkLevel' => l10n.connectionsStatNetworkLevel,
  'connectionsStatItemLevel' => l10n.connectionsStatItemLevel,
  'connectionsStatSummonerLevel' => l10n.connectionsStatSummonerLevel,
  'dataMenuItemLeagueRank' => l10n.dataMenuItemLeagueRank,
  'dataMenuItemSteamLibraryShowcase' => l10n.dataMenuItemSteamLibraryShowcase,
  'dataMenuItemLeagueTopMastery' => l10n.dataMenuItemLeagueTopMastery,
  'dataMenuItemWowClassRace' => l10n.dataMenuItemWowClassRace,
  _ => null,
};

/// Localized heading for a [DataMenuCategory] section.
String dataMenuCategoryLabel(
  AppLocalizations l10n,
  DataMenuCategory category,
) => switch (category) {
  DataMenuCategory.ranksCompetitive => l10n.dataMenuCategoryRanksCompetitive,
  DataMenuCategory.hoursDedication => l10n.dataMenuCategoryHoursDedication,
  DataMenuCategory.achievements => l10n.dataMenuCategoryAchievements,
  DataMenuCategory.gamesCharacters => l10n.dataMenuCategoryGamesCharacters,
  DataMenuCategory.levelsIdentity => l10n.dataMenuCategoryLevelsIdentity,
};
