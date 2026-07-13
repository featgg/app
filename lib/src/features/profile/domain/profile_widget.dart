import 'package:equatable/equatable.dart';

import '../../connections/domain/connection.dart';
import 'collection_selection.dart';
import 'composed_card.dart';
import 'data_menu_selection.dart';
import 'showcase_selection.dart';
import 'template_catalog.dart';

/// Forward-compatible widget kinds. Only [platform] is implemented today; the
/// others are reserved for later personalization phases and degrade to
/// "unknown → omit" on read. The full set is listed up front so later phases
/// add no enum churn.
enum ProfileWidgetKind {
  platform,
  dataMenu,
  template,
  composed,
  showcase,
  collection,
  gameCollector,
  completionist,
  passport,
}

/// Grid footprint a widget occupies. Maps to row-layout spans in
/// presentation: small→1x1, wide→2x1, large→2x2. Unknown wire tokens degrade
/// to [small].
enum ProfileWidgetSize { small, wide, large }

/// Schema version of the `settings` JSON envelope. v1 from day one; the data
/// layer omits any row whose envelope is a different version. Mirrors the
/// `game_cards.widget_data` version gate.
const int kProfileWidgetSettingsVersion = 1;

/// A profile-layout widget read from `profile_widgets`. The widget row carries
/// the layout (position, size, enabled state) and the kind/identity; the card
/// content for a [ProfileWidgetKind.platform] widget still comes from the
/// `game_cards` surface.
final class ProfileWidget extends Equatable {
  const ProfileWidget({
    required this.id,
    required this.kind,
    required this.platform,
    required this.position,
    required this.isEnabled,
    required this.size,
    this.selection = DataMenuSelection.empty,
    this.templateFill = TemplateFill.empty,
    this.composedFill = ComposedFill.empty,
    this.showcaseSelection = ShowcaseSelection.empty,
    this.collectionSelection = CollectionSelection.empty,
  });

  final String id;
  final ProfileWidgetKind kind;

  /// Non-null for [ProfileWidgetKind.platform], [ProfileWidgetKind.showcase],
  /// [ProfileWidgetKind.gameCollector], and [ProfileWidgetKind.completionist]
  /// (the single source platform whose library the card draws from); null
  /// otherwise.
  final Platform? platform;
  final int position;
  final bool isEnabled;
  final ProfileWidgetSize size;

  /// The owner's data-menu curation for this widget. Empty (default) for a
  /// widget that has not been customized.
  final DataMenuSelection selection;

  /// The owner's template choice + per-slot fills for a
  /// [ProfileWidgetKind.template] widget. Empty (default) otherwise.
  final TemplateFill templateFill;

  /// The owner's freely-picked item set for a [ProfileWidgetKind.composed]
  /// widget. Empty (default) otherwise.
  final ComposedFill composedFill;

  /// The owner's per-game choice for a [ProfileWidgetKind.showcase] widget.
  /// Empty (default) otherwise.
  final ShowcaseSelection showcaseSelection;

  /// The owner's multi-game choice for a [ProfileWidgetKind.collection] widget.
  /// Empty (default) otherwise.
  final CollectionSelection collectionSelection;

  ProfileWidget copyWith({
    int? position,
    bool? isEnabled,
    ProfileWidgetSize? size,
    DataMenuSelection? selection,
    TemplateFill? templateFill,
    ComposedFill? composedFill,
    ShowcaseSelection? showcaseSelection,
    CollectionSelection? collectionSelection,
  }) => ProfileWidget(
    id: id,
    kind: kind,
    platform: platform,
    position: position ?? this.position,
    isEnabled: isEnabled ?? this.isEnabled,
    size: size ?? this.size,
    selection: selection ?? this.selection,
    templateFill: templateFill ?? this.templateFill,
    composedFill: composedFill ?? this.composedFill,
    showcaseSelection: showcaseSelection ?? this.showcaseSelection,
    collectionSelection: collectionSelection ?? this.collectionSelection,
  );

  @override
  List<Object?> get props => [
    id,
    kind,
    platform,
    position,
    isEnabled,
    size,
    selection,
    templateFill,
    composedFill,
    showcaseSelection,
    collectionSelection,
  ];
}
