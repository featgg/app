import 'package:equatable/equatable.dart';

import '../../connections/domain/game_card.dart';

/// A resolved completionist ready to render: the perfect-games count (the hero),
/// the games-owned count (the meta denominator, null when the card omits the
/// stat), and the top-game cover art. The presentation layer formats the numbers
/// and renders [heroImage] behind the fixed `COMPLETIONIST` label.
final class ResolvedCompletionist extends Equatable {
  const ResolvedCompletionist({
    required this.gamesPerfect,
    required this.gamesOwned,
    required this.heroImage,
  });

  /// Perfect-games count — the hero number.
  final num gamesPerfect;

  /// Games-owned count — the meta denominator; null when the card omits the stat.
  final num? gamesOwned;

  /// Top-game cover art url, or null (feed image rules — the view renders a
  /// neutral surface, never a broken glyph).
  final String? heroImage;

  @override
  List<Object?> get props => [gamesPerfect, gamesOwned, heroImage];
}

/// Resolves the completionist card's render-ready values, or null (soft-omit)
/// when [card] is null or carries no numeric `games_perfect` stat — the raison
/// d'être of the card. Owned count and cover degrade gracefully. Steam-first in
/// effect: only the Steam card publishes `games_perfect`/`games_owned`, so a
/// non-Steam card resolves to null → unavailable. A `games_perfect` of 0 is a
/// valid resolved state (the user has no perfect games), not an absent one.
/// Pure: reads only the envelope stats and [SteamCardData]; imports only
/// connections `domain`.
ResolvedCompletionist? resolveCompletionist(GameCard? card) {
  if (card == null) return null;
  final gamesPerfect = _statValue(card, 'games_perfect');
  if (gamesPerfect == null) return null;
  final data = card.data;
  final steam = data is SteamCardData ? data : null;
  return ResolvedCompletionist(
    gamesPerfect: gamesPerfect,
    gamesOwned: _statValue(card, 'games_owned'),
    heroImage: _topCover(steam),
  );
}

/// The numeric value of the [key] envelope stat, or null when absent or
/// non-numeric (defensive — a non-numeric value reads as absent).
num? _statValue(GameCard card, String key) {
  for (final s in card.stats) {
    if (s.key == key && s.value is num) return s.value as num;
  }
  return null;
}

/// The cover art of the library's top game by hours, or null when the library
/// is empty or the top entry has no art (feed image rules).
String? _topCover(SteamCardData? data) {
  if (data == null || data.libraryShowcase.isEmpty) return null;
  var top = data.libraryShowcase.first;
  for (final e in data.libraryShowcase) {
    if (e.hours > top.hours) top = e;
  }
  return top.heroImage;
}
