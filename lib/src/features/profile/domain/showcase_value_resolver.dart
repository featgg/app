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
  });

  /// Raw game title; the view uppercases it for the label.
  final String title;

  /// Per-game art url, or null (feed image rules — never a placeholder/partial).
  final String? heroImage;

  /// Resolved hero stat value (hours in slice 1).
  final num heroValue;

  /// The hero stat, mapped by presentation to its localized descriptor.
  final ShowcaseHeroStat hero;

  @override
  List<Object?> get props => [title, heroImage, heroValue, hero];
}

/// Resolves the single showcased game to its render-ready values, or null
/// (soft-omit) when [data] is null, [sel] is empty, or the referenced game is
/// not in the current `library_showcase` list (rotated out). Pure: reads only
/// [SteamCardData] fields; imports only connections `domain`.
ResolvedShowcase? resolveShowcase(SteamCardData? data, ShowcaseSelection sel) {
  if (data == null || sel.isEmpty) return null;
  for (final entry in data.libraryShowcase) {
    if (entry.appId.toString() == sel.gameRef) {
      return ResolvedShowcase(
        title: entry.title,
        heroImage: entry.heroImage,
        heroValue: _heroValueFor(sel.hero, entry),
        hero: sel.hero,
      );
    }
  }
  return null;
}

num _heroValueFor(ShowcaseHeroStat hero, LibraryShowcaseEntry entry) =>
    switch (hero) {
      ShowcaseHeroStat.hours => entry.hours,
    };

/// Formats a hero stat number for display: a whole number renders without a
/// trailing `.0`; a fractional value keeps its decimals.
String formatShowcaseHeroValue(num value) =>
    value == value.truncate() ? value.toInt().toString() : value.toString();
