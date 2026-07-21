import 'package:equatable/equatable.dart';

import '../../connections/domain/connection.dart';
import '../../connections/domain/game_card.dart';

/// A resolved rank ready to render: a nameable [heading] (the tier line, e.g.
/// League "GOLD IV"), a data-derived [scope] sub-label (e.g. the Chess mode
/// token), and the headline [stats]. The presentation layer maps each stat key
/// to a localized label via the shared stat-label map and formats the value.
final class ResolvedRank extends Equatable {
  const ResolvedRank({this.heading, this.scope, this.stats = const []});

  /// Nameable tier line (League "GOLD IV"); null when the platform has none.
  final String? heading;

  /// Data-derived sub-label (Chess primary-mode token); null otherwise.
  final String? scope;

  /// Stable-keyed headline stats resolved by the shared stat-label map.
  final List<CardStat> stats;

  bool get isEmpty => heading == null && scope == null && stats.isEmpty;

  @override
  List<Object?> get props => [heading, scope, stats];
}

/// The platforms a Rank card is offered for: only these publish a competitive
/// rank/rating the card can render (the offer is further gated on the payload
/// actually carrying it — [resolveRank] non-null).
const Set<Platform> kRankPlatforms = {
  Platform.leagueOfLegends,
  Platform.wowRetail,
  Platform.chess,
  Platform.retroachievements,
};

/// Resolves the Rank card's render-ready values from [card], or null (soft-omit)
/// when the payload carries no rank/rating — the raison d'être of the card. Pure:
/// switches on the typed data block; imports only connections `domain`. A card on
/// an unsupported platform (or with an absent rating) resolves to null so the
/// card renders its neutral no-data state, never a fallback.
ResolvedRank? resolveRank(GameCard? card) {
  switch (card?.data) {
    case LeagueOfLegendsCardData(:final rank?):
      final stats = <CardStat>[
        CardStat(key: 'rank_lp', value: rank.lp, unit: 'lp'),
      ];
      final games = rank.wins + rank.losses;
      if (games > 0) {
        // Guard the divide-by-zero: an unplayed placement has no winrate.
        stats.add(
          CardStat(
            key: 'winrate',
            value: (rank.wins * 100 / games).round(),
            unit: 'percent',
          ),
        );
      }
      return ResolvedRank(
        heading: '${rank.tier} ${rank.division}',
        stats: stats,
      );
    case WowRetailCardData(
      :final profile,
      mythicPlus: WowMythicPlus(rating: final rating?),
    ):
      return ResolvedRank(
        stats: [
          CardStat(key: 'mythic_plus_rating', value: rating),
          CardStat(key: 'item_level', value: profile.ilvlAvg),
        ],
      );
    case ChessCardData(
      :final primaryMode,
      :final ratings,
      :final puzzleRushScore,
    ):
      final mode = ratings[primaryMode.toLowerCase()];
      if (mode == null) return null;
      final stats = <CardStat>[CardStat(key: 'rating', value: mode.current)];
      if (puzzleRushScore != null) {
        stats.add(CardStat(key: 'puzzle_rush', value: puzzleRushScore));
      }
      return ResolvedRank(scope: primaryMode, stats: stats);
    case RetroAchievementsCardData(:final profile):
      return ResolvedRank(
        stats: [
          CardStat(key: 'retro_rank', value: profile.rank),
          CardStat(key: 'total_achievement_points', value: profile.totalPoints),
        ],
      );
    default:
      return null;
  }
}
