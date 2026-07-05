import 'package:equatable/equatable.dart';

/// Creation bounds for a collection card: at least [kCollectionMinGames] and at
/// most [kCollectionMaxGames] games. Enforced only at creation in the picker;
/// read/render stays lenient — a stored collection whose current library
/// resolves fewer games still renders that resolved subset.
const int kCollectionMinGames = 2;
const int kCollectionMaxGames = 5;

/// The owner's multi-game choice for a [ProfileWidgetKind.collection] widget: an
/// ordered set of per-game refs plus an optional catalog title key. Empty
/// (default) for a widget that has not picked its games yet. A pure carrier —
/// the 3–5 rule is a creation constraint enforced in the picker, never here.
final class CollectionSelection extends Equatable {
  const CollectionSelection({this.gameRefs = const [], this.titleKey});

  /// Ordered, de-duplicated per-game keys. For Steam this is the app id as a
  /// string ("730").
  final List<String> gameRefs;

  /// Stable catalog title key, or null when no title is chosen.
  final String? titleKey;

  static const empty = CollectionSelection();

  bool get isEmpty => gameRefs.isEmpty;

  /// Adds [gameRef] at the end when absent, removes it when present (free
  /// toggle — no min/max here; the picker enforces the creation bounds).
  CollectionSelection toggle(String gameRef) => gameRefs.contains(gameRef)
      ? CollectionSelection(
          gameRefs: [
            for (final ref in gameRefs)
              if (ref != gameRef) ref,
          ],
          titleKey: titleKey,
        )
      : CollectionSelection(
          gameRefs: [...gameRefs, gameRef],
          titleKey: titleKey,
        );

  /// Returns a copy with the title key replaced; a null [key] clears it.
  CollectionSelection withTitle(String? key) =>
      CollectionSelection(gameRefs: gameRefs, titleKey: key);

  @override
  List<Object?> get props => [gameRefs, titleKey];
}
