import 'package:equatable/equatable.dart';

import '../../connections/domain/connection.dart';
import '../../connections/domain/game_card.dart';

/// A resolved main ("what defines me") ready to render: the primary [title]
/// (game / character / mode name; null falls back to a generic in presentation),
/// a secondary [subtitle] token line, and the headline [stats]. The presentation
/// layer maps each stat key to a localized label and formats the value.
final class ResolvedMain extends Equatable {
  const ResolvedMain({this.title, this.subtitle, this.stats = const []});

  /// Main name (game / character / mode); null when only a generic is known.
  final String? title;

  /// Secondary token line (race + class, profession); null otherwise.
  final String? subtitle;

  /// Stable-keyed headline stats resolved by the shared stat-label map.
  final List<CardStat> stats;

  bool get isEmpty => title == null && subtitle == null && stats.isEmpty;

  @override
  List<Object?> get props => [title, subtitle, stats];
}

/// The platforms a Main card is offered for: only these publish a primary
/// game/character/mode the card can render (the offer is further gated on the
/// payload actually carrying it — [resolveMain] non-null).
const Set<Platform> kMainPlatforms = {
  Platform.steam,
  Platform.wowRetail,
  Platform.gw2,
  Platform.leagueOfLegends,
  Platform.chess,
};

/// Resolves the Main card's render-ready values from [card], or null (soft-omit)
/// when the payload carries no main — the raison d'être of the card. Pure:
/// switches on the typed data block; imports only connections `domain`. A card on
/// an unsupported platform (or with an absent main) resolves to null so the card
/// renders its neutral no-data state, never a fallback.
ResolvedMain? resolveMain(GameCard? card) {
  if (card == null) return null;
  switch (card.data) {
    case SteamCardData(:final libraryShowcase):
      if (libraryShowcase.isEmpty) return null;
      var top = libraryShowcase.first;
      for (final entry in libraryShowcase) {
        if (entry.hours > top.hours) top = entry;
      }
      return ResolvedMain(
        title: top.title,
        stats: [CardStat(key: 'hours_played', value: top.hours)],
      );
    case WowRetailCardData(:final profile, :final mythicPlus):
      final stats = <CardStat>[
        CardStat(key: 'item_level', value: profile.ilvlAvg),
      ];
      final rating = mythicPlus?.rating;
      if (rating != null) {
        stats.add(CardStat(key: 'mythic_plus_rating', value: rating));
      }
      return ResolvedMain(
        title: card.title,
        subtitle: '${profile.race} ${profile.className}',
        stats: stats,
      );
    case Gw2CardData(
      :final mainProfession,
      :final account,
      :final topCharacters,
    ):
      Gw2Character? main;
      for (final character in topCharacters) {
        if (character.isMain) {
          main = character;
          break;
        }
      }
      main ??= topCharacters.isEmpty ? null : topCharacters.first;
      final title = main?.name;
      final subtitle = main?.profession ?? mainProfession;
      final stats = <CardStat>[];
      final totalAp = account.totalAp;
      if (totalAp != null) stats.add(CardStat(key: 'total_ap', value: totalAp));
      final fractal = account.fractalLevel;
      if (fractal != null) {
        stats.add(CardStat(key: 'fractal_level', value: fractal));
      }
      if (title == null && subtitle == null && stats.isEmpty) return null;
      return ResolvedMain(title: title, subtitle: subtitle, stats: stats);
    case LeagueOfLegendsCardData(:final topMastery, :final summoner):
      if (topMastery.isEmpty) return null;
      // No champion-name map in v1, so the title is left null (presentation shows
      // a generic); mastery points are the honest headline number.
      final stats = <CardStat>[
        CardStat(key: 'mastery_points', value: topMastery.first.points),
      ];
      if (summoner != null) {
        stats.add(CardStat(key: 'summoner_level', value: summoner.level));
      }
      return ResolvedMain(stats: stats);
    case ChessCardData(:final primaryMode, :final ratings):
      final mode = ratings[primaryMode.toLowerCase()];
      return ResolvedMain(
        title: primaryMode,
        stats: [if (mode != null) CardStat(key: 'rating', value: mode.current)],
      );
    default:
      return null;
  }
}
