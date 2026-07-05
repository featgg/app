import 'package:equatable/equatable.dart';

import '../../connections/domain/game_card.dart';
import 'collection_selection.dart';

/// One resolved panel of a collection panorama: the game's title plus its art
/// url. A null [heroImage] renders a neutral surface, never a broken glyph
/// (feed image rules).
final class ResolvedCollectionPanel extends Equatable {
  const ResolvedCollectionPanel({required this.title, required this.heroImage});

  final String title;

  /// Per-game art url, or null (feed image rules — never a placeholder/partial).
  final String? heroImage;

  @override
  List<Object?> get props => [title, heroImage];
}

/// Resolves a collection's ordered game refs against the current Steam
/// `library_showcase`: keeps the stored order, skips refs no longer in the
/// library (rotated out), and caps at [kCollectionMaxGames]. Returns empty when
/// [data] is null, [sel] is empty, or nothing resolves — the view degrades
/// softly (owner placeholder, nothing for a visitor). Pure: reads only
/// [SteamCardData] fields; imports only connections `domain`.
List<ResolvedCollectionPanel> resolveCollection(
  SteamCardData? data,
  CollectionSelection sel,
) {
  if (data == null || sel.isEmpty) return const [];
  final byAppId = <String, LibraryShowcaseEntry>{
    for (final entry in data.libraryShowcase) entry.appId.toString(): entry,
  };
  final panels = <ResolvedCollectionPanel>[];
  for (final ref in sel.gameRefs) {
    final entry = byAppId[ref];
    if (entry == null) continue;
    panels.add(
      ResolvedCollectionPanel(title: entry.title, heroImage: entry.heroImage),
    );
    if (panels.length >= kCollectionMaxGames) break;
  }
  return panels;
}
