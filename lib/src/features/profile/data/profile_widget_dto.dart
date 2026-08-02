import 'package:json_annotation/json_annotation.dart';

import '../../connections/domain/connection.dart';
import '../../connections/domain/platform_descriptor.dart';
import '../domain/art_framing.dart';
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

  Platform? platform;
  if (kind == ProfileWidgetKind.platform ||
      kind == ProfileWidgetKind.showcase ||
      kind == ProfileWidgetKind.gameCollector ||
      kind == ProfileWidgetKind.completionist ||
      kind == ProfileWidgetKind.rank ||
      kind == ProfileWidgetKind.personalBest ||
      kind == ProfileWidgetKind.main ||
      kind == ProfileWidgetKind.recent ||
      kind == ProfileWidgetKind.rarestAchievement) {
    platform = dto.platform == null ? null : _platformFromWire(dto.platform!);
    if (platform == null) return null;
  }

  return ProfileWidget(
    id: dto.id,
    kind: kind,
    platform: platform,
    position: dto.position,
    isEnabled: dto.isEnabled,
    showcaseSelection: showcaseSelectionFromSettings(settings),
    collectionSelection: collectionSelectionFromSettings(settings),
    artSelection: artSelectionFromSettings(settings),
    framing: artFramingFromSettings(settings),
    storedSettings: settings ?? const {},
  );
}

/// Stable `settings` key the art framing is stored under. Additive in the
/// `schema_version: 1` envelope. Shape:
/// `{ "x": <0..1>, "y": <0..1>, "scale"?: <1..3> }`.
///
/// Top-level rather than inside a kind's sub-object because framing is not a
/// property of where the picture came from: every kind that renders art can
/// carry one, including the ones whose envelope holds nothing else.
const String _framingKey = 'framing';

/// Reads the framing leniently. An absent key, a malformed sub-object or a
/// non-numeric coordinate all read as the centre — which is what the renderer
/// has always done — so a bad value costs the owner their framing, never the
/// card. Out-of-range coordinates are pulled back into the picture rather than
/// discarded: they still name a direction the owner moved in.
///
/// The size is the same discipline one level down: a malformed one costs the
/// size and keeps the point, and one outside the range is pulled into it — so
/// no stored envelope can draw the picture below the size that covers its
/// frame.
ArtFraming artFramingFromSettings(Map<String, dynamic>? settings) {
  final raw = settings?[_framingKey];
  if (raw is! Map) return ArtFraming.center;
  final x = raw['x'];
  final y = raw['y'];
  if (x is! num || y is! num) return ArtFraming.center;
  final scale = raw['scale'];
  return ArtFraming.clamped(
    x.toDouble(),
    y.toDouble(),
    scale: scale is num ? scale.toDouble() : ArtFraming.coverScale,
  );
}

/// The envelope to write for a framing change: [widget]'s own, with the framing
/// replaced and everything else left exactly as it was read.
///
/// A merge rather than a rebuild. The envelope is additive under one schema
/// version, so it can hold keys this build does not parse — a build that knows
/// a field this one predates, or one it postdates. Rebuilding from the fields
/// this build understands would drop them, which is the same profile losing
/// content by being opened on the wrong version.
Map<String, dynamic> settingsWithFraming(
  ProfileWidget widget,
  ArtFraming framing,
) {
  final next = Map<String, dynamic>.of(widget.storedSettings);
  next['schema_version'] = kProfileWidgetSettingsVersion;
  if (framing.isDefault) {
    next.remove(_framingKey);
  } else {
    // The size is written only when it is not the covering one, so a profile
    // that was only panned keeps writing exactly the bytes it wrote before the
    // size existed.
    next[_framingKey] = {
      'x': framing.x,
      'y': framing.y,
      if (framing.scale != ArtFraming.coverScale) 'scale': framing.scale,
    };
  }
  return next;
}

/// Stable `settings` key the showcase selection is stored under. Additive
/// in the `schema_version: 1` envelope. Shape:
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

/// Stable `settings` key the art source is stored under. Additive in the
/// `schema_version: 1` envelope.
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
/// `schema_version` and sets the `art` sub-object from [sel]. An
/// empty selection omits the key.
Map<String, dynamic> mergeArtSelectionIntoSettings(ArtSelection sel) => {
  'schema_version': kProfileWidgetSettingsVersion,
  if (sel.source case final source?)
    _artKey: {'source': platformDescriptors[source]!.wireValue},
};

/// Builds the full `settings` envelope to write for a showcase change: preserves
/// `schema_version` and sets the `showcase` sub-object from [sel].
/// Additive — never bumps the version. An empty selection omits the key; `meta`
/// is written only when set.
Map<String, dynamic> mergeShowcaseSelectionIntoSettings(
  ShowcaseSelection sel,
) => {
  'schema_version': kProfileWidgetSettingsVersion,
  if (!sel.isEmpty)
    _showcaseKey: {
      'game': sel.gameRef,
      'hero': showcaseHeroStatToWire(sel.hero),
      if (sel.meta != null) 'meta': showcaseHeroStatToWire(sel.meta!),
    },
};

/// Stable `settings` key the collection selection is stored under. Additive
/// in the `schema_version: 1` envelope. Shape:
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
/// preserves `schema_version` and sets the `collection` sub-object
/// from [sel]. Additive — never bumps the version. An empty selection omits the
/// key; `title` is written only when non-null.
Map<String, dynamic> mergeCollectionSelectionIntoSettings(
  CollectionSelection sel,
) => {
  'schema_version': kProfileWidgetSettingsVersion,
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

/// Serializes [kind] to its stable wire token.
String profileWidgetKindToWire(ProfileWidgetKind kind) => switch (kind) {
  ProfileWidgetKind.platform => 'platform',
  ProfileWidgetKind.showcase => 'showcase',
  ProfileWidgetKind.collection => 'collection',
  ProfileWidgetKind.gameCollector => 'game_collector',
  ProfileWidgetKind.completionist => 'completionist',
  ProfileWidgetKind.passport => 'passport',
  ProfileWidgetKind.rank => 'rank',
  ProfileWidgetKind.personalBest => 'personal_best',
  ProfileWidgetKind.main => 'main',
  ProfileWidgetKind.recent => 'recent',
  ProfileWidgetKind.rarestAchievement => 'rarest_achievement',
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
  'personal_best' => ProfileWidgetKind.personalBest,
  'main' => ProfileWidgetKind.main,
  'recent' => ProfileWidgetKind.recent,
  'rarest_achievement' => ProfileWidgetKind.rarestAchievement,
  'art' => ProfileWidgetKind.art,
  _ => null,
};

/// Reverse lookup over [platformDescriptors] by wire value. Null on an unknown
/// token (soft resolution).
Platform? _platformFromWire(String value) {
  for (final descriptor in platformDescriptors.values) {
    if (descriptor.wireValue == value) return descriptor.platform;
  }
  return null;
}
