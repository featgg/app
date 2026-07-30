import 'package:equatable/equatable.dart';

import '../../connections/domain/connection.dart';
import 'art_framing.dart';
import 'art_selection.dart';
import 'collection_selection.dart';
import 'showcase_selection.dart';

/// The card kinds a profile can hold. A row whose wire token is not one of
/// these is omitted on read, which is also how the retired kinds leave: their
/// rows stop resolving rather than needing a migration to disappear.
enum ProfileWidgetKind {
  platform,
  showcase,
  collection,
  gameCollector,
  completionist,
  passport,
  rank,
  main,
  art,
}

/// Schema version of the `settings` JSON envelope. v1 from day one; the data
/// layer omits any row whose envelope is a different version. Mirrors the
/// `game_cards.widget_data` version gate.
const int kProfileWidgetSettingsVersion = 1;

/// A profile-layout widget read from `profile_widgets`. The widget row carries
/// its position and enabled state and the kind/identity; the card
/// content for a [ProfileWidgetKind.platform] widget still comes from the
/// `game_cards` surface.
final class ProfileWidget extends Equatable {
  const ProfileWidget({
    required this.id,
    required this.kind,
    required this.platform,
    required this.position,
    required this.isEnabled,
    this.showcaseSelection = ShowcaseSelection.empty,
    this.collectionSelection = CollectionSelection.empty,
    this.artSelection = ArtSelection.empty,
    this.framing = ArtFraming.center,
  });

  final String id;
  final ProfileWidgetKind kind;

  /// Non-null for [ProfileWidgetKind.platform], [ProfileWidgetKind.showcase],
  /// [ProfileWidgetKind.gameCollector], [ProfileWidgetKind.completionist],
  /// [ProfileWidgetKind.rank], and [ProfileWidgetKind.main] (the single source
  /// platform the card draws from); null otherwise.
  final Platform? platform;
  final int position;
  final bool isEnabled;

  /// The owner's per-game choice for a [ProfileWidgetKind.showcase] widget.
  /// Empty (default) otherwise.
  final ShowcaseSelection showcaseSelection;

  /// The owner's multi-game choice for a [ProfileWidgetKind.collection] widget.
  /// Empty (default) otherwise.
  final CollectionSelection collectionSelection;

  /// Where an art widget's picture comes from; empty for every other kind.
  final ArtSelection artSelection;

  /// How the owner framed whatever picture this widget shows. Kind-independent:
  /// the picture's source differs per kind, the framing of it does not.
  final ArtFraming framing;

  ProfileWidget copyWith({
    int? position,
    bool? isEnabled,
    ShowcaseSelection? showcaseSelection,
    CollectionSelection? collectionSelection,
    ArtSelection? artSelection,
    ArtFraming? framing,
  }) => ProfileWidget(
    id: id,
    kind: kind,
    platform: platform,
    position: position ?? this.position,
    isEnabled: isEnabled ?? this.isEnabled,
    showcaseSelection: showcaseSelection ?? this.showcaseSelection,
    collectionSelection: collectionSelection ?? this.collectionSelection,
    artSelection: artSelection ?? this.artSelection,
    framing: framing ?? this.framing,
  );

  @override
  List<Object?> get props => [
    id,
    kind,
    platform,
    position,
    isEnabled,
    showcaseSelection,
    collectionSelection,
    artSelection,
    framing,
  ];
}
