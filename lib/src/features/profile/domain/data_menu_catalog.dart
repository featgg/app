import 'package:equatable/equatable.dart';

import '../../connections/domain/connection.dart';

/// The semantic categories the data menu groups items by (platform is a
/// filter, not the grouping). Adding a category is one value here plus its
/// items in [dataMenuCatalog]; no other code changes.
enum DataMenuCategory {
  ranksCompetitive,
  hoursDedication,
  achievements,
  gamesCharacters,
  levelsIdentity,
}

/// Reusable value formatters, selected by type — never per-item code. A new
/// value shape is one enum value plus its formatter; existing items keep their
/// type. Rendering (honoring the selection on the card) is a follow-up slice,
/// so these only tag the value's shape today.
enum DataMenuValueType { integer, percent, hours, rank, showcaseList, identity }

/// A stable pointer into the frozen game-card contract. Sealed so a
/// pointer is either a scalar stat (a `stats[].key` or a scalar field in
/// `widget_data.data`) or a showcase list (a `widget_data.data` list field),
/// both keyed by [Platform].
sealed class DataMenuPointer extends Equatable {
  const DataMenuPointer(this.platform);

  final Platform platform;
}

/// Points at a scalar value: a `stats[].key` when [dataPath] is null (e.g.
/// steam `hours_played`), or a `widget_data.data` field path when [dataPath]
/// is non-null (e.g. league `data.rank`, wow `data.profile`).
final class StatPointer extends DataMenuPointer {
  const StatPointer(super.platform, {required this.statKey, this.dataPath});

  /// Stable contract token. Names the `stats[].key` when [dataPath] is null,
  /// otherwise the leaf of the `data` path (kept for a stable, readable id).
  final String statKey;

  /// The `widget_data.data` field path when the value lives only in the `data`
  /// block (not in `stats`). Null for an envelope `stats` key.
  final List<String>? dataPath;

  @override
  List<Object?> get props => [platform, statKey, dataPath];
}

/// Points at a showcase list in `widget_data.data` (steam `library_showcase`,
/// league `top_mastery`). Carries the top-N cap.
final class ShowcasePointer extends DataMenuPointer {
  const ShowcasePointer(
    super.platform, {
    required this.dataField,
    this.topN = 3,
  });

  /// The `widget_data.data` field path of the list (e.g. `['library_showcase']`).
  final List<String> dataField;

  /// How many entries the card surfaces.
  final int topN;

  @override
  List<Object?> get props => [platform, dataField, topN];
}

/// One catalog entry. [id] is the stable selection token persisted in the
/// widget's `settings`; [labelKey] names an l10n key resolved in presentation
/// (no copy lives in domain). Adding an item is appending one const entry to
/// [dataMenuCatalog].
final class DataMenuItem extends Equatable {
  const DataMenuItem({
    required this.id,
    required this.category,
    required this.pointer,
    required this.labelKey,
    required this.valueType,
  });

  final String id;
  final DataMenuCategory category;
  final DataMenuPointer pointer;
  final String labelKey;
  final DataMenuValueType valueType;

  Platform get platform => pointer.platform;

  @override
  List<Object?> get props => [id, category, pointer, labelKey, valueType];
}

/// The v1 data menu catalog. Every pointer maps to a stat key or showcase
/// field already in the frozen game-card data contract; nothing here invents a
/// contract. Adding an item = appending ONE const entry; the iterating tests
/// need no new case for a conformant addition.
const List<DataMenuItem> dataMenuCatalog = [
  // ── Ranks & competitive ──────────────────────────────────────────────────
  DataMenuItem(
    id: 'chess.rating',
    category: DataMenuCategory.ranksCompetitive,
    pointer: StatPointer(Platform.chess, statKey: 'rating'),
    labelKey: 'connectionsStatRating',
    valueType: DataMenuValueType.integer,
  ),
  DataMenuItem(
    id: 'league_of_legends.rank',
    category: DataMenuCategory.ranksCompetitive,
    pointer: StatPointer(
      Platform.leagueOfLegends,
      statKey: 'rank',
      dataPath: ['rank'],
    ),
    labelKey: 'dataMenuItemLeagueRank',
    valueType: DataMenuValueType.rank,
  ),
  DataMenuItem(
    id: 'wow_retail.mythic_plus_rating',
    category: DataMenuCategory.ranksCompetitive,
    pointer: StatPointer(Platform.wowRetail, statKey: 'mythic_plus_rating'),
    labelKey: 'connectionsStatMythicPlusRating',
    valueType: DataMenuValueType.integer,
  ),
  DataMenuItem(
    id: 'gw2.wvw_rank',
    category: DataMenuCategory.ranksCompetitive,
    pointer: StatPointer(Platform.gw2, statKey: 'wvw_rank'),
    labelKey: 'connectionsStatWvwRank',
    valueType: DataMenuValueType.integer,
  ),
  // ── Hours & dedication ───────────────────────────────────────────────────
  DataMenuItem(
    id: 'steam.hours_played',
    category: DataMenuCategory.hoursDedication,
    pointer: StatPointer(Platform.steam, statKey: 'hours_played'),
    labelKey: 'connectionsStatHoursPlayed',
    valueType: DataMenuValueType.hours,
  ),
  DataMenuItem(
    id: 'gw2.veterancy_years',
    category: DataMenuCategory.hoursDedication,
    pointer: StatPointer(Platform.gw2, statKey: 'veterancy_years'),
    labelKey: 'connectionsStatVeterancyYears',
    valueType: DataMenuValueType.integer,
  ),
  // ── Achievements ─────────────────────────────────────────────────────────
  DataMenuItem(
    id: 'retroachievements.total_achievement_points',
    category: DataMenuCategory.achievements,
    pointer: StatPointer(
      Platform.retroachievements,
      statKey: 'total_achievement_points',
    ),
    labelKey: 'connectionsStatTotalAchievementPoints',
    valueType: DataMenuValueType.integer,
  ),
  DataMenuItem(
    id: 'wow_retail.achievement_points',
    category: DataMenuCategory.achievements,
    pointer: StatPointer(Platform.wowRetail, statKey: 'achievement_points'),
    labelKey: 'connectionsStatAchievementPoints',
    valueType: DataMenuValueType.integer,
  ),
  DataMenuItem(
    id: 'gw2.total_ap',
    category: DataMenuCategory.achievements,
    pointer: StatPointer(Platform.gw2, statKey: 'total_ap'),
    labelKey: 'connectionsStatTotalAp',
    valueType: DataMenuValueType.integer,
  ),
  // ── Games & characters ───────────────────────────────────────────────────
  DataMenuItem(
    id: 'steam.library_showcase',
    category: DataMenuCategory.gamesCharacters,
    pointer: ShowcasePointer(Platform.steam, dataField: ['library_showcase']),
    labelKey: 'dataMenuItemSteamLibraryShowcase',
    valueType: DataMenuValueType.showcaseList,
  ),
  DataMenuItem(
    id: 'league_of_legends.top_mastery',
    category: DataMenuCategory.gamesCharacters,
    pointer: ShowcasePointer(
      Platform.leagueOfLegends,
      dataField: ['top_mastery'],
    ),
    labelKey: 'dataMenuItemLeagueTopMastery',
    valueType: DataMenuValueType.showcaseList,
  ),
  DataMenuItem(
    id: 'wow_retail.profile',
    category: DataMenuCategory.gamesCharacters,
    pointer: StatPointer(
      Platform.wowRetail,
      statKey: 'profile',
      dataPath: ['profile'],
    ),
    labelKey: 'dataMenuItemWowClassRace',
    valueType: DataMenuValueType.identity,
  ),
  // ── Levels & identity ────────────────────────────────────────────────────
  DataMenuItem(
    id: 'minecraft_hypixel.network_level',
    category: DataMenuCategory.levelsIdentity,
    pointer: StatPointer(Platform.minecraftHypixel, statKey: 'network_level'),
    labelKey: 'connectionsStatNetworkLevel',
    valueType: DataMenuValueType.integer,
  ),
  DataMenuItem(
    id: 'wow_retail.item_level',
    category: DataMenuCategory.levelsIdentity,
    pointer: StatPointer(Platform.wowRetail, statKey: 'item_level'),
    labelKey: 'connectionsStatItemLevel',
    valueType: DataMenuValueType.integer,
  ),
  DataMenuItem(
    id: 'league_of_legends.summoner_level',
    category: DataMenuCategory.levelsIdentity,
    pointer: StatPointer(Platform.leagueOfLegends, statKey: 'summoner_level'),
    labelKey: 'connectionsStatSummonerLevel',
    valueType: DataMenuValueType.integer,
  ),
];
