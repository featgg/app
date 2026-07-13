import 'package:equatable/equatable.dart';

import '../../connections/domain/connection.dart';
import '../../connections/domain/game_card.dart';

/// One linked platform's line in the passport: the [platform], its headline
/// stat's stable label key ([statLabelKey], an existing `connectionsStat*` key)
/// and raw [value] + [unit], or all-null for an identity-only chip (the platform
/// is linked but publishes no headline number). Presentation maps the label key
/// to copy and formats [value] with [unit]; no copy or clock lives here.
final class PassportEntry extends Equatable {
  const PassportEntry({
    required this.platform,
    this.statLabelKey,
    this.value,
    this.unit,
    this.artImage,
  });

  final Platform platform;

  /// An existing `connectionsStat*` l10n key, or null for an identity-only chip.
  final String? statLabelKey;

  /// Raw headline number, or null (identity-only).
  final num? value;

  /// Stable unit token (`percent`, `lp`, …) carried verbatim from the stat, or
  /// null; presentation appends the display suffix.
  final String? unit;

  /// Absolute https URL to the platform card's hero (preferred) or icon art, or
  /// null when it publishes neither. Orthogonal to the headline stat; the
  /// presentation collage draws it as a background band.
  final String? artImage;

  @override
  List<Object?> get props => [platform, statLabelKey, value, unit, artImage];
}

/// The resolved passport ready to render: one [PassportEntry] per linked
/// platform in [Platform.values] order. [linkedCount] is the hero — the number
/// of linked platforms (identity-only chips included).
final class ResolvedPassport extends Equatable {
  const ResolvedPassport({required this.entries});

  final List<PassportEntry> entries;

  int get linkedCount => entries.length;

  @override
  List<Object?> get props => [entries];
}

/// Aggregates the owner's per-platform [cards] into the passport, or null
/// (soft-omit) when no platform has a card. One entry per platform whose card is
/// non-null, in [Platform.values] order; each entry carries that platform's
/// documented headline stat (or is identity-only when none is published). Pure:
/// reads only the envelope `stats` and the typed data block where the feed
/// contract makes a stat ambiguous (League ranked/unranked); imports only
/// connections `domain`.
ResolvedPassport? resolvePassport(Map<Platform, GameCard?> cards) {
  final entries = <PassportEntry>[];
  for (final platform in Platform.values) {
    final card = cards[platform];
    if (card == null) continue;
    entries.add(_entryFor(platform, card));
  }
  if (entries.isEmpty) return null;
  return ResolvedPassport(entries: entries);
}

/// Resolves one platform's headline entry, falling back down the platform's
/// documented order to an identity-only chip when no headline stat is present.
PassportEntry _entryFor(Platform platform, GameCard card) {
  switch (platform) {
    case Platform.chess:
      return _fromStat(platform, card, 'rating', 'connectionsStatRating') ??
          _identity(platform, card);
    case Platform.steam:
      return _fromStat(
            platform,
            card,
            'games_owned',
            'connectionsStatGamesOwned',
          ) ??
          _fromStat(
            platform,
            card,
            'hours_played',
            'connectionsStatHoursPlayed',
          ) ??
          _identity(platform, card);
    case Platform.minecraftHypixel:
      return _fromStat(
            platform,
            card,
            'network_level',
            'connectionsStatNetworkLevel',
          ) ??
          _identity(platform, card);
    case Platform.retroachievements:
      return _fromStat(
            platform,
            card,
            'total_achievement_points',
            'connectionsStatTotalAchievementPoints',
          ) ??
          _fromStat(platform, card, 'retro_rank', 'connectionsStatRetroRank') ??
          _identity(platform, card);
    case Platform.wowRetail:
      return _fromStat(
            platform,
            card,
            'item_level',
            'connectionsStatItemLevel',
          ) ??
          _identity(platform, card);
    case Platform.leagueOfLegends:
      // `data.rank` is the authoritative unranked signal: only a ranked summoner
      // shows `rank_lp` as the headline, so an unranked `rank_lp: 0` never
      // renders as a fake rank. Unranked (or missing lp) falls to winrate.
      final data = card.data;
      if (data is LeagueOfLegendsCardData && data.rank != null) {
        final lp = _fromStat(
          platform,
          card,
          'rank_lp',
          'connectionsStatRankLp',
        );
        if (lp != null) return lp;
      }
      return _fromStat(platform, card, 'winrate', 'connectionsStatWinrate') ??
          _identity(platform, card);
    case Platform.gw2:
      // Scope-gated stats arrive absent (never 0), so a missing key falls
      // through to the next candidate, ending at veterancy_years / identity.
      return _fromStat(platform, card, 'wvw_rank', 'connectionsStatWvwRank') ??
          _fromStat(
            platform,
            card,
            'fractal_level',
            'connectionsStatFractalLevel',
          ) ??
          _fromStat(
            platform,
            card,
            'veterancy_years',
            'connectionsStatVeterancyYears',
          ) ??
          _identity(platform, card);
  }
}

/// A headline entry from the [key] envelope stat, or null when the stat is
/// absent or non-numeric (defensive — a non-numeric value reads as absent, and
/// an absent scope-gated stat is never read as 0).
PassportEntry? _fromStat(
  Platform platform,
  GameCard card,
  String key,
  String labelKey,
) {
  for (final stat in card.stats) {
    if (stat.key == key && stat.value is num) {
      return PassportEntry(
        platform: platform,
        statLabelKey: labelKey,
        value: stat.value as num,
        unit: stat.unit,
        artImage: _artOf(card),
      );
    }
  }
  return null;
}

/// An identity-only chip: the platform is linked but publishes no headline
/// number. Still counts toward [ResolvedPassport.linkedCount] and still carries
/// the card's art for the collage.
PassportEntry _identity(Platform platform, GameCard card) =>
    PassportEntry(platform: platform, artImage: _artOf(card));

/// The card's collage art: the hero/cover when present, else the icon/avatar,
/// else null. Orthogonal to the headline stat.
String? _artOf(GameCard card) => card.heroImage ?? card.iconImage;
