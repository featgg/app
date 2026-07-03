import 'package:equatable/equatable.dart';

/// Which per-game stat a showcase card surfaces. Forward-compatible: only
/// [hours] exists today; `achievements` (and others) land as one enum value plus
/// one resolver case once the backend ships the per-game datum.
enum ShowcaseHeroStat { hours }

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

  @override
  List<Object?> get props => [gameRef, hero, meta];
}
