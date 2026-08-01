import 'package:equatable/equatable.dart';

import '../../connections/domain/connection.dart';
import '../../connections/domain/game_card.dart';

/// A resolved recent activity ready to render: the game [title], the headline
/// [stats] (recent hours first, all-time hours when the same game is also in the
/// library), and the game's cover art.
final class ResolvedRecent extends Equatable {
  const ResolvedRecent({
    required this.title,
    this.stats = const [],
    this.heroImage,
  });

  /// The game's name. Never null — a card whose subject cannot be named does
  /// not resolve at all.
  final String title;

  /// Stable-keyed stats: `hours_2weeks` first, then `hours_played`.
  final List<CardStat> stats;

  /// The recent entry's own cover art url; null when it publishes none (the
  /// card then renders framed).
  final String? heroImage;

  @override
  List<Object?> get props => [title, stats, heroImage];
}

/// The platforms a Recent card is offered for: only Steam publishes a
/// recent-activity entry carrying playtime, which is the question this card
/// answers.
const Set<Platform> kRecentPlatforms = {Platform.steam};

/// Resolves the Recent card's render-ready values from [card], or null
/// (soft-omit) when the payload publishes no recent activity. Pure: switches on
/// the typed data block; imports only connections `domain`.
ResolvedRecent? resolveRecent(GameCard? card) {
  if (card == null) return null;
  final data = card.data;
  if (data is! SteamCardData) return null;

  // A game the payload cannot name is not a subject, so it is not a candidate.
  RecentGameEntry? top;
  for (final entry in data.recentGames) {
    if (entry.title.isEmpty) continue;
    // No order is documented for the recent list, so the greatest recent
    // playtime is read rather than assumed to be first; the first of a tie wins.
    if (top == null || entry.hours2Weeks > top.hours2Weeks) top = entry;
  }
  if (top == null) return null;

  final stats = <CardStat>[
    CardStat(key: 'hours_2weeks', value: top.hours2Weeks),
  ];
  // The all-time figure explains the hero only when it belongs to the same
  // game; for any other game it explains nothing.
  for (final entry in data.libraryShowcase) {
    if (entry.appId == top.appId) {
      stats.add(CardStat(key: 'hours_played', value: entry.hours));
      break;
    }
  }

  return ResolvedRecent(
    title: top.title,
    stats: stats,
    heroImage: top.heroImage,
  );
}
