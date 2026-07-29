import 'package:json_annotation/json_annotation.dart';

import '../../connections/domain/connection.dart';
import '../../connections/domain/platform_descriptor.dart';
import '../domain/art_selection.dart';
import '../domain/collection_selection.dart';
import '../domain/profile_widget.dart';
import '../domain/showcase_selection.dart';

part 'profile_widget_dto.g.dart';

/// Wire DTO for a `profile_widgets` row. The `settings` column is a free JSON
/// object, parsed leniently by [profileWidgetFromDto] (like `widget_data`),
/// not by `json_serializable`.
@JsonSerializable(createToJson: false)
final class ProfileWidgetDto {
  const ProfileWidgetDto({
    required this.id,
    required this.platform,
    required this.type,
    required this.position,
    required this.isEnabled,
    this.settings,
  });

  final String id;

  /// Wire platform token; null for non-platform widget kinds.
  final String? platform;

  /// Wire widget-kind token.
  final String type;
  final int position;
  @JsonKey(name: 'is_enabled')
  final bool isEnabled;

  /// Versioned presentation envelope. Null when absent.
  final Map<String, dynamic>? settings;

  factory ProfileWidgetDto.fromJson(Map<String, dynamic> json) =>
      _$ProfileWidgetDtoFromJson(json);
}

/// Converts a [ProfileWidgetDto] into a [ProfileWidget], applying soft
/// resolution. Returns null — so the repository omits the row — when:
///
/// - the `type` token is an unknown / unwired kind,
/// - the `settings` envelope is a version other than
///   [kProfileWidgetSettingsVersion],
/// - a `platform`-, `showcase`-, `game_collector`-, or `completionist`-kind row
///   carries an unknown / absent platform token.
///
/// An unknown or absent `settings.size` token degrades to
/// [ProfileWidgetSize.small] rather than omitting the row.
ProfileWidget? profileWidgetFromDto(ProfileWidgetDto dto) {
  final kind = _kindFromWire(dto.type);
  if (kind == null) return null;

  final settings = dto.settings;
  // Hard-code against v1; omit any other version. A bumped version signals a
  // breaking change, so the strict v1 read below cannot be trusted for it.
  if (settings != null &&
      settings['schema_version'] != kProfileWidgetSettingsVersion) {
    return null;
  }

  final size = _sizeFromWire(settings?['size']);

  Platform? platform;
  if (kind == ProfileWidgetKind.platform ||
      kind == ProfileWidgetKind.showcase ||
      kind == ProfileWidgetKind.gameCollector ||
      kind == ProfileWidgetKind.completionist ||
      kind == ProfileWidgetKind.rank ||
      kind == ProfileWidgetKind.main) {
    platform = dto.platform == null ? null : _platformFromWire(dto.platform!);
    if (platform == null) return null;
  }

  return ProfileWidget(
    id: dto.id,
    kind: kind,
    platform: platform,
    position: dto.position,
    isEnabled: dto.isEnabled,
    size: size,
    showcaseSelection: showcaseSelectionFromSettings(settings),
    collectionSelection: collectionSelectionFromSettings(settings),
    artSelection: artSelectionFromSettings(settings),
  );
}

/// Stable `settings` key the showcase selection is stored under. Additive
/// beside `size` in the same `schema_version: 1` envelope. Shape:
/// `{ "game": "<gameKey>", "hero": "<stat>", "meta"?: "<stat>" }`. The single
/// source platform lives in the row's `platform` column, not here.
const String _showcaseKey = 'showcase';

/// Reads the showcase selection leniently from a `settings` envelope. A
/// non-object value or a missing/empty `game` yields [ShowcaseSelection.empty];
/// an unknown `hero` token defaults to hours and an unknown/absent `meta` token
/// resolves to null (forward-compatible, never drops the row).
ShowcaseSelection showcaseSelectionFromSettings(
  Map<String, dynamic>? settings,
) {
  final raw = settings?[_showcaseKey];
  if (raw is! Map) return ShowcaseSelection.empty;
  final game = raw['game'];
  if (game is! String || game.isEmpty) return ShowcaseSelection.empty;
  return ShowcaseSelection(
    gameRef: game,
    hero: showcaseHeroStatFromWire(raw['hero']) ?? ShowcaseHeroStat.hours,
    meta: showcaseHeroStatFromWire(raw['meta']),
  );
}

/// Stable `settings` key the art source is stored under. Additive beside `size`
/// in the same `schema_version: 1` envelope.
const String _artKey = 'art';

/// Reads the art source leniently. An absent key, a malformed sub-object, or a
/// platform token this build does not know all read as "not pointed anywhere
/// yet" — the card renders the theme ground rather than failing the profile.
ArtSelection artSelectionFromSettings(Map<String, dynamic>? settings) {
  final raw = settings?[_artKey];
  if (raw is! Map) return ArtSelection.empty;
  final source = raw['source'];
  if (source is! String) return ArtSelection.empty;
  return ArtSelection(source: _platformFromWire(source));
}

/// Builds the full `settings` envelope to write for an art change: preserves
/// `schema_version` and `size` and sets the `art` sub-object from [sel]. An
/// empty selection omits the key.
Map<String, dynamic> mergeArtSelectionIntoSettings(
  ProfileWidgetSize size,
  ArtSelection sel,
) => {
  'schema_version': kProfileWidgetSettingsVersion,
  'size': profileWidgetSizeToWire(size),
  if (sel.source case final source?)
    _artKey: {'source': platformDescriptors[source]!.wireValue},
};

/// Builds the full `settings` envelope to write for a showcase change: preserves
/// `schema_version` and `size` and sets the `showcase` sub-object from [sel].
/// Additive — never bumps the version. An empty selection omits the key; `meta`
/// is written only when set.
Map<String, dynamic> mergeShowcaseSelectionIntoSettings(
  ProfileWidgetSize size,
  ShowcaseSelection sel,
) => {
  'schema_version': kProfileWidgetSettingsVersion,
  'size': profileWidgetSizeToWire(size),
  if (!sel.isEmpty)
    _showcaseKey: {
      'game': sel.gameRef,
      'hero': showcaseHeroStatToWire(sel.hero),
      if (sel.meta != null) 'meta': showcaseHeroStatToWire(sel.meta!),
    },
};

/// Stable `settings` key the collection selection is stored under. Additive
/// beside `size` in the same `schema_version: 1` envelope. Shape:
/// `{ "games": ["<gameKey>", ...], "title"?: "<titleKey>" }`. A collection spans
/// multiple games, so — unlike the showcase — it has no single source platform
/// in the row's `platform` column; its games live here.
const String _collectionKey = 'collection';

/// Reads the collection selection leniently from a `settings` envelope. A
/// non-object value or a missing / non-list / empty `games` yields
/// [CollectionSelection.empty]; non-string and empty entries are dropped, the
/// order-preserving remainder is de-duplicated (mirrors the composed read), and
/// `title` is kept only when a non-empty String (else null). Never drops the row.
CollectionSelection collectionSelectionFromSettings(
  Map<String, dynamic>? settings,
) {
  final raw = settings?[_collectionKey];
  if (raw is! Map) return CollectionSelection.empty;
  final games = raw['games'];
  if (games is! List) return CollectionSelection.empty;
  final refs = <String>[];
  for (final entry in games) {
    if (entry is String && entry.isNotEmpty && !refs.contains(entry)) {
      refs.add(entry);
    }
  }
  if (refs.isEmpty) return CollectionSelection.empty;
  final title = raw['title'];
  return CollectionSelection(
    gameRefs: refs,
    titleKey: title is String && title.isNotEmpty ? title : null,
  );
}

/// Builds the full `settings` envelope to write for a collection change:
/// preserves `schema_version` and `size` and sets the `collection` sub-object
/// from [sel]. Additive — never bumps the version. An empty selection omits the
/// key; `title` is written only when non-null.
Map<String, dynamic> mergeCollectionSelectionIntoSettings(
  ProfileWidgetSize size,
  CollectionSelection sel,
) => {
  'schema_version': kProfileWidgetSettingsVersion,
  'size': profileWidgetSizeToWire(size),
  if (!sel.isEmpty)
    _collectionKey: {
      'games': sel.gameRefs,
      if (sel.titleKey != null) 'title': sel.titleKey,
    },
};

/// Serializes a [ShowcaseHeroStat] to its stable wire token.
String showcaseHeroStatToWire(ShowcaseHeroStat s) => switch (s) {
  ShowcaseHeroStat.hours => 'hours',
  ShowcaseHeroStat.achievements => 'achievements',
};

/// Parses a wire hero-stat token; null on an unknown/absent token (lenient).
ShowcaseHeroStat? showcaseHeroStatFromWire(Object? v) => switch (v) {
  'hours' => ShowcaseHeroStat.hours,
  'achievements' => ShowcaseHeroStat.achievements,
  _ => null,
};

/// Serializes [size] to its stable wire token.
String profileWidgetSizeToWire(ProfileWidgetSize size) => switch (size) {
  ProfileWidgetSize.small => 'small',
  ProfileWidgetSize.wide => 'wide',
  ProfileWidgetSize.large => 'large',
};

/// Serializes [kind] to its stable wire token.
String profileWidgetKindToWire(ProfileWidgetKind kind) => switch (kind) {
  ProfileWidgetKind.platform => 'platform',
  ProfileWidgetKind.showcase => 'showcase',
  ProfileWidgetKind.collection => 'collection',
  ProfileWidgetKind.gameCollector => 'game_collector',
  ProfileWidgetKind.completionist => 'completionist',
  ProfileWidgetKind.passport => 'passport',
  ProfileWidgetKind.rank => 'rank',
  ProfileWidgetKind.main => 'main',
  ProfileWidgetKind.art => 'art',
};

/// The retired tokens (`template`, `composed_card`, `data_menu`) are absent on
/// purpose: an unrecognized token yields null and the row is omitted, which is
/// how a profile still holding one renders without it and without a migration.
ProfileWidgetKind? _kindFromWire(String value) => switch (value) {
  'platform' => ProfileWidgetKind.platform,
  'showcase' => ProfileWidgetKind.showcase,
  'collection' => ProfileWidgetKind.collection,
  'game_collector' => ProfileWidgetKind.gameCollector,
  'completionist' => ProfileWidgetKind.completionist,
  'passport' => ProfileWidgetKind.passport,
  'rank' => ProfileWidgetKind.rank,
  'main' => ProfileWidgetKind.main,
  'art' => ProfileWidgetKind.art,
  _ => null,
};

ProfileWidgetSize _sizeFromWire(Object? value) => switch (value) {
  'small' => ProfileWidgetSize.small,
  'wide' => ProfileWidgetSize.wide,
  'large' => ProfileWidgetSize.large,
  _ => ProfileWidgetSize.small,
};

/// Reverse lookup over [platformDescriptors] by wire value. Null on an unknown
/// token (soft resolution).
Platform? _platformFromWire(String value) {
  for (final descriptor in platformDescriptors.values) {
    if (descriptor.wireValue == value) return descriptor.platform;
  }
  return null;
}
