import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/core.dart';
import '../../../connections/domain/connection.dart';
import '../../../connections/domain/game_card.dart';
import '../../../connections/domain/platform_descriptor.dart';
import '../../domain/completionist_value_resolver.dart';
import '../../domain/game_collector_value_resolver.dart';
import '../../domain/showcase_selection.dart';
import '../../domain/showcase_value_resolver.dart';
import '../personalization_card_shell.dart';
import '../profile_owner_cards_provider.dart';

/// A number as a card shows it. Spelled out while it still fits the narrowest
/// card the column supports, and compact past that — which bounds how wide any
/// value can get, so a card's layout does not depend on how large a number an
/// upstream account happens to hold. Compact notation differs by language, so
/// it comes from the reader's locale rather than a suffix written here.
String formatCardValue(num value, AppLocalizations l10n) {
  // Rounded, not truncated to the integer part: a fraction is width the card
  // cannot promise — a four-digit value carrying one decimal reads seven
  // characters wide, which is the ellipsis this exists to prevent. A card
  // answers with a figure, not a measurement.
  final whole = value.round();
  if (whole.abs() < PersonalizationLayout.compactValueThreshold) {
    return NumberFormat.decimalPattern(l10n.localeName).format(whole);
  }
  return NumberFormat.compact(locale: l10n.localeName).format(whole);
}

/// The current card for [platform] from the injected [source] (owner default is
/// [ownerCardProvider]; the visitor render injects a public source). An errored
/// read resolves as absent so a single failing platform never errors the card.
GameCard? resolveCard(WidgetRef ref, CardSource? source, Platform platform) {
  final state = source == null
      ? ref.watch(ownerCardProvider(platform))
      : ref.watch(source(platform));
  return state.hasError ? null : state.value;
}

/// The first [cap] of the card's envelope stats whose key resolves to a label.
List<PersonalizationStat> cardStats(
  GameCard? card,
  AppLocalizations l10n,
  int cap, {
  String? platform,
}) => statsFromResolved(card?.stats ?? const [], l10n, cap, platform: platform);

/// The platform a card should name beside its numbers, or null where the card
/// carries real art: the picture already says what the numbers are about, and
/// repeating it spends width the noun needs.
String? cardLabelPlatform(Platform? platform, {required bool hasArt}) =>
    hasArt || platform == null
    ? null
    : platformDescriptors[platform]?.shortName;

/// The first [cap] [stats] whose key resolves to a label, formatted for the
/// datum. A stat with an unrecognized key or non-numeric value is skipped rather
/// than rendered raw. Shared by the envelope-stat cards (Platform / Fallback) and
/// the resolver-driven cards (Rank / Main) so every datum formats identically.
List<PersonalizationStat> statsFromResolved(
  List<CardStat> stats,
  AppLocalizations l10n,
  int cap, {
  String? platform,
}) {
  final out = <PersonalizationStat>[];
  for (final stat in stats) {
    final noun = cardStatLabel(l10n, stat.key);
    if (noun == null) continue;
    // Only the first entry — the one the card answers with — carries the
    // platform. The rest explain that number, so the card has already said
    // which platform they belong to, and repeating it would spend width they
    // do not have: beside a hero and each other they get a third of the row.
    final label =
        out.isEmpty && platform != null && cardStatNeedsPlatform(stat.key)
        ? '$platform $noun'
        : noun;
    out.add(
      PersonalizationStat(value: formatStatValue(stat, l10n), label: label),
    );
    if (out.length == cap) break;
  }
  return out;
}

List<PersonalizationStat> milestoneStats(
  ResolvedShowcase? resolved,
  AppLocalizations l10n,
) {
  if (resolved == null) return const [];
  final stats = <PersonalizationStat>[
    PersonalizationStat(
      value: formatCardValue(resolved.heroValue, l10n),
      label: l10n.connectionsStatHoursPlayed,
    ),
  ];
  if (resolved.hero == ShowcaseHeroStat.achievements &&
      resolved.achieved != null &&
      resolved.total != null) {
    stats.add(
      PersonalizationStat(
        value: formatShowcaseAchievements(resolved.achieved!, resolved.total!),
        label: l10n.showcaseHeroAchievements,
      ),
    );
  }
  return stats;
}

/// The Collector datum: games-owned (the hero), plus hours-played when the card
/// carries it. Empty for a null resolve (the neutral no-data emblem).
List<PersonalizationStat> collectorStats(
  ResolvedGameCollector? resolved,
  AppLocalizations l10n,
) {
  if (resolved == null) return const [];
  return [
    PersonalizationStat(
      value: formatCardValue(resolved.gamesOwned, l10n),
      label: l10n.connectionsStatGamesOwned,
    ),
    if (resolved.hoursPlayed case final hours?)
      PersonalizationStat(
        value: formatCardValue(hours, l10n),
        label: l10n.connectionsStatHoursPlayed,
      ),
  ];
}

/// The Achievement Grid datum: perfect-games (the hero, honest at 0), plus
/// games-owned when the card carries it. Empty for a null resolve (the no-data
/// grid of two diamonds).
List<PersonalizationStat> completionistStats(
  ResolvedCompletionist? resolved,
  AppLocalizations l10n,
) {
  if (resolved == null) return const [];
  return [
    PersonalizationStat(
      value: formatCardValue(resolved.gamesPerfect, l10n),
      label: l10n.personalizationStatPerfect,
    ),
    if (resolved.gamesOwned case final owned?)
      PersonalizationStat(
        value: formatCardValue(owned, l10n),
        label: l10n.connectionsStatGamesOwned,
      ),
  ];
}

/// The uppercased first character of a perfect-game [title] for its letter tile,
/// or null for an empty title (that tile is skipped). Reads the first Unicode
/// code point so an astral leading character is not split mid-surrogate.
String? letterGlyph(String title) {
  if (title.isEmpty) return null;
  return String.fromCharCode(title.runes.first).toUpperCase();
}

/// Formats a stat value with its stable unit suffix (mirrors the passport chip
/// rule): `%` for percent, ` LP` for lp; every other unit renders the bare
/// number, its label already naming it.
String formatStatValue(CardStat stat, AppLocalizations l10n) {
  final value = stat.value;
  final base = value is num ? formatCardValue(value, l10n) : value.toString();
  return switch (stat.unit) {
    'percent' => '$base%',
    'lp' => '$base LP',
    _ => base,
  };
}

/// Every stat key a card can label. Enumerable so the width guard can measure
/// all of them rather than a sample, and so a key added without card copy is
/// caught there instead of shipping as a number with no subject.
const List<String> cardStatKeys = [
  'rating',
  'games_owned',
  'hours_played',
  'network_level',
  'bedwars_wins',
  'bedwars_kills',
  'karma',
  'achievement_points',
  'total_achievement_points',
  'retro_rank',
  'completion_pct',
  'rank_lp',
  'winrate',
  'mastery_points',
  'challenge_points',
  'summoner_level',
  'item_level',
  'mythic_plus_rating',
  'followers',
  'puzzle_rush',
  'wvw_rank',
  'fractal_level',
  'total_ap',
  'account_age_hours',
  'veterancy_years',
];

/// A card's label for [key]: the terse noun, without the platform. Distinct
/// from the shared stat copy, which the feed and the connections screen were
/// written around and which is too long to sit beside a platform name.
String? cardStatLabel(AppLocalizations l10n, String key) => switch (key) {
  'rating' => l10n.cardStatRating,
  'games_owned' => l10n.cardStatGamesOwned,
  'hours_played' => l10n.cardStatHoursPlayed,
  'network_level' => l10n.cardStatNetworkLevel,
  'bedwars_wins' => l10n.cardStatBedwarsWins,
  'bedwars_kills' => l10n.cardStatBedwarsKills,
  'karma' => l10n.cardStatKarma,
  'achievement_points' => l10n.cardStatAchievementPoints,
  'total_achievement_points' => l10n.cardStatTotalAchievementPoints,
  'retro_rank' => l10n.cardStatRetroRank,
  'completion_pct' => l10n.cardStatCompletionPct,
  'rank_lp' => l10n.cardStatRankLp,
  'winrate' => l10n.cardStatWinrate,
  'mastery_points' => l10n.cardStatMasteryPoints,
  'challenge_points' => l10n.cardStatChallengePoints,
  'summoner_level' => l10n.cardStatSummonerLevel,
  'item_level' => l10n.cardStatItemLevel,
  'mythic_plus_rating' => l10n.cardStatMythicPlusRating,
  'followers' => l10n.cardStatFollowers,
  'puzzle_rush' => l10n.cardStatPuzzleRush,
  'wvw_rank' => l10n.cardStatWvwRank,
  'fractal_level' => l10n.cardStatFractalLevel,
  'total_ap' => l10n.cardStatTotalAp,
  'account_age_hours' => l10n.cardStatAccountAgeHours,
  'veterancy_years' => l10n.cardStatVeterancyYears,
  _ => null,
};

/// Whether [key] needs its platform named beside it. Jargon belonging to one
/// Whether [key] carries its platform. Naming it is the rule, because a card
/// with no art has nothing else that can: an unnamed number leaves a reader
/// guessing which account it came from. The exceptions are the handful whose
/// noun is long enough that the platform would not fit beside it — and those
/// are the ones that need it least, being jargon a single platform owns. Bed
/// Wars, Puzzle Rush and Summoner name their own; hours could be anyone's.
bool cardStatNeedsPlatform(String key) => const {
  'rating',
  'games_owned',
  'hours_played',
  'network_level',
  'karma',
  'achievement_points',
  'total_achievement_points',
  'retro_rank',
  'completion_pct',
  'rank_lp',
  'winrate',
  'mastery_points',
  'item_level',
  'mythic_plus_rating',
  'followers',
  'wvw_rank',
  'total_ap',
  'account_age_hours',
}.contains(key);

/// Maps a raw envelope stat key (`GameCard.stats` carries the platform's own
/// tokens, e.g. `games_owned`) to its localized label, or null for a key with
/// no label. Shared by the Platform and Fallback cards — the single place these
/// keys resolve to copy for the personalization cards.
String? connectionsStatLabel(AppLocalizations l10n, String key) =>
    switch (key) {
      'rating' => l10n.connectionsStatRating,
      'games_owned' => l10n.connectionsStatGamesOwned,
      'hours_played' => l10n.connectionsStatHoursPlayed,
      'network_level' => l10n.connectionsStatNetworkLevel,
      'bedwars_wins' => l10n.connectionsStatBedwarsWins,
      'bedwars_kills' => l10n.connectionsStatBedwarsKills,
      'karma' => l10n.connectionsStatKarma,
      'achievement_points' => l10n.connectionsStatAchievementPoints,
      'total_achievement_points' => l10n.connectionsStatTotalAchievementPoints,
      'retro_rank' => l10n.connectionsStatRetroRank,
      'completion_pct' => l10n.connectionsStatCompletionPct,
      'rank_lp' => l10n.connectionsStatRankLp,
      'winrate' => l10n.connectionsStatWinrate,
      'mastery_points' => l10n.connectionsStatMasteryPoints,
      'challenge_points' => l10n.connectionsStatChallengePoints,
      'summoner_level' => l10n.connectionsStatSummonerLevel,
      'item_level' => l10n.connectionsStatItemLevel,
      'mythic_plus_rating' => l10n.connectionsStatMythicPlusRating,
      'followers' => l10n.connectionsStatFollowers,
      'puzzle_rush' => l10n.connectionsStatPuzzleRush,
      'wvw_rank' => l10n.connectionsStatWvwRank,
      'fractal_level' => l10n.connectionsStatFractalLevel,
      'total_ap' => l10n.connectionsStatTotalAp,
      'account_age_hours' => l10n.connectionsStatAccountAgeHours,
      'veterancy_years' => l10n.connectionsStatVeterancyYears,
      _ => null,
    };
