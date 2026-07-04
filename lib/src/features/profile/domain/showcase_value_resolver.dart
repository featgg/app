import 'package:equatable/equatable.dart';

import '../../connections/domain/game_card.dart';
import 'showcase_selection.dart';

/// A resolved showcase ready to render: the game's identity (title + art) plus
/// the hero stat's value and its descriptor pointer. The presentation layer
/// uppercases the title for the label, formats [heroValue], and maps [hero] to a
/// localized meta descriptor.
final class ResolvedShowcase extends Equatable {
  const ResolvedShowcase({
    required this.title,
    required this.heroImage,
    required this.heroValue,
    required this.hero,
    this.achieved,
    this.total,
  });

  /// Raw game title; the view uppercases it for the label.
  final String title;

  /// Per-game art url, or null (feed image rules — never a placeholder/partial).
  final String? heroImage;

  /// Hours value; used by the view when the effective [hero] is hours.
  final num heroValue;

  /// The effective hero stat after fallback, mapped by presentation to its
  /// localized descriptor.
  final ShowcaseHeroStat hero;

  /// The achievement pair, non-null only when the effective [hero] is
  /// achievements.
  final int? achieved;
  final int? total;

  @override
  List<Object?> get props => [
    title,
    heroImage,
    heroValue,
    hero,
    achieved,
    total,
  ];
}

/// Resolves the single showcased game to its render-ready values, or null
/// (soft-omit) when [data] is null, [sel] is empty, or the referenced game is
/// not in the current `library_showcase` list (rotated out). The effective hero
/// falls back to hours when the achievements hero is chosen for a game that
/// lacks the pair, so a stale/rotated-out choice never renders empty or 0/0.
/// Pure: reads only [SteamCardData] fields; imports only connections `domain`.
ResolvedShowcase? resolveShowcase(SteamCardData? data, ShowcaseSelection sel) {
  if (data == null || sel.isEmpty) return null;
  for (final entry in data.libraryShowcase) {
    if (entry.appId.toString() == sel.gameRef) {
      final useAchievements =
          sel.hero == ShowcaseHeroStat.achievements && entry.hasAchievements;
      return ResolvedShowcase(
        title: entry.title,
        heroImage: entry.heroImage,
        heroValue: entry.hours,
        hero: useAchievements
            ? ShowcaseHeroStat.achievements
            : ShowcaseHeroStat.hours,
        achieved: useAchievements ? entry.achieved : null,
        total: useAchievements ? entry.total : null,
      );
    }
  }
  return null;
}

/// Formats a hero stat number for display: a whole number renders without a
/// trailing `.0`; a fractional value keeps its decimals.
String formatShowcaseHeroValue(num value) =>
    value == value.truncate() ? value.toInt().toString() : value.toString();

/// Structural number format for the achievements hero: "achieved/total".
/// Pure, mirrors [formatShowcaseHeroValue] — not localized copy.
String formatShowcaseAchievements(int achieved, int total) =>
    '$achieved/$total';

/// Whether the achievements hero is currently selectable for [sel]'s game.
bool showcaseAchievementsAvailable(SteamCardData? data, ShowcaseSelection sel) {
  if (data == null || sel.isEmpty) return false;
  for (final entry in data.libraryShowcase) {
    if (entry.appId.toString() == sel.gameRef) return entry.hasAchievements;
  }
  return false;
}
