import 'package:equatable/equatable.dart';

/// Which per-game stat a showcase card surfaces. [achievements] is available
/// only for a game that carries the per-game achievement pair; the resolver
/// falls back to [hours] when it does not.
enum ShowcaseHeroStat { hours, achievements }

/// The owner's per-game choice for a [ProfileWidgetKind.showcase] widget: which
/// game to render and which stat is the hero (with an optional second `meta`
/// stat). Empty (default) for a widget that has not picked a game yet.
final class ShowcaseSelection extends Equatable {
  const ShowcaseSelection({
    required this.gameRef,
    this.hero = ShowcaseHeroStat.hours,
    this.meta,
  });

  /// Stable per-game key. For Steam this is the app id as a string ("730").
  final String gameRef;

  /// The single hero stat rendered large. Defaults to hours.
  final ShowcaseHeroStat hero;

  /// Optional second stat rendered as whisper-quiet meta; null when the meta
  /// line derives from the hero descriptor (slice 1).
  final ShowcaseHeroStat? meta;

  static const empty = ShowcaseSelection(gameRef: '');

  bool get isEmpty => gameRef.isEmpty;

  /// Returns a copy with the given fields replaced. `meta` is preserved as-is —
  /// this feature does not touch the second-stat slot.
  ShowcaseSelection copyWith({String? gameRef, ShowcaseHeroStat? hero}) =>
      ShowcaseSelection(
        gameRef: gameRef ?? this.gameRef,
        hero: hero ?? this.hero,
        meta: meta,
      );

  @override
  List<Object?> get props => [gameRef, hero, meta];
}
