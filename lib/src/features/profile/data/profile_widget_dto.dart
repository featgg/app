import 'package:json_annotation/json_annotation.dart';

import '../../connections/domain/connection.dart';
import '../../connections/domain/platform_descriptor.dart';
import '../domain/collection_selection.dart';
import '../domain/composed_card.dart';
import '../domain/data_menu_catalog.dart';
import '../domain/data_menu_selection.dart';
import '../domain/profile_widget.dart';
import '../domain/showcase_selection.dart';
import '../domain/template_catalog.dart';

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
/// - a `platform`- or `showcase`-kind row carries an unknown / absent platform
///   token.
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
      kind == ProfileWidgetKind.showcase) {
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
    selection: dataMenuSelectionFromSettings(settings),
    templateFill: templateFillFromSettings(settings),
    composedFill: composedFillFromSettings(settings),
    showcaseSelection: showcaseSelectionFromSettings(settings),
    collectionSelection: collectionSelectionFromSettings(settings),
  );
}

/// Stable `settings` key the data-menu selection is stored under. Additive
/// beside `size` in the same `schema_version: 1` envelope.
const String _dataMenuItemsKey = 'data_menu_items';

/// The set of known catalog ids, for dropping unknown/stale tokens on read.
final Set<String> _knownCatalogIds = {
  for (final item in dataMenuCatalog) item.id,
};

/// Reads the data-menu selection leniently from a `settings` envelope. An
/// absent key, a non-list value, non-string entries, and ids not in the
/// current catalog are all dropped (soft resolution, mirroring the feed
/// compatibility rule); the result defaults to [DataMenuSelection.empty].
DataMenuSelection dataMenuSelectionFromSettings(
  Map<String, dynamic>? settings,
) {
  final raw = settings?[_dataMenuItemsKey];
  if (raw is! List) return DataMenuSelection.empty;
  final ids = <String>{
    for (final entry in raw)
      if (entry is String && _knownCatalogIds.contains(entry)) entry,
  };
  return ids.isEmpty ? DataMenuSelection.empty : DataMenuSelection(ids);
}

/// Builds the full `settings` envelope to write for a selection change:
/// preserves `schema_version` and `size` and sets `data_menu_items` to the
/// selected ids (an empty selection omits the key). Additive — never bumps the
/// version.
Map<String, dynamic> mergeDataMenuSelectionIntoSettings(
  ProfileWidgetSize size,
  DataMenuSelection selection,
) => {
  'schema_version': kProfileWidgetSettingsVersion,
  'size': profileWidgetSizeToWire(size),
  if (!selection.isDefault) _dataMenuItemsKey: selection.selectedIds.toList(),
};

/// Stable `settings` key the template fill is stored under. Additive beside
/// `size` and `data_menu_items` in the same `schema_version: 1` envelope. Shape:
/// `{ "id": "<templateId>", "slots": { "<slotId>": "<dataMenuItemId>" } }`.
const String _templateKey = 'template';

/// Reads the template fill leniently from a `settings` envelope. A non-object
/// value, a non-string `id`, or a non-map `slots` all yield [TemplateFill.empty].
/// Slot entries whose value is not a known catalog item id are dropped on read
/// (mirrors [dataMenuSelectionFromSettings]); an `id` not in the current catalog
/// is kept raw so a stale token soft-resolves at render.
TemplateFill templateFillFromSettings(Map<String, dynamic>? settings) {
  final raw = settings?[_templateKey];
  if (raw is! Map) return TemplateFill.empty;
  final id = raw['id'];
  if (id is! String) return TemplateFill.empty;
  final rawSlots = raw['slots'];
  final slots = <String, String>{
    if (rawSlots is Map)
      for (final entry in rawSlots.entries)
        if (entry.key is String &&
            entry.value is String &&
            _knownCatalogIds.contains(entry.value))
          entry.key as String: entry.value as String,
  };
  return TemplateFill(id, slots);
}

/// Builds the full `settings` envelope to write for a template change: preserves
/// `schema_version` and `size` and sets the `template` sub-object from [fill].
/// Additive — never bumps the version. A fill with a null `templateId` omits the
/// key (an un-chosen template carries nothing).
Map<String, dynamic> mergeTemplateFillIntoSettings(
  ProfileWidgetSize size,
  TemplateFill fill,
) => {
  'schema_version': kProfileWidgetSettingsVersion,
  'size': profileWidgetSizeToWire(size),
  if (fill.templateId != null)
    _templateKey: {
      'id': fill.templateId,
      if (fill.slotItemIds.isNotEmpty) 'slots': fill.slotItemIds,
    },
};

/// Stable `settings` key the composed-card fill is stored under. Additive
/// beside `size`, `data_menu_items`, and `template` in the same
/// `schema_version: 1` envelope. Shape: `{ "items": ["<dataMenuItemId>", ...] }`.
const String _composedKey = 'composed';

/// Reads the composed-card fill leniently from a `settings` envelope. A
/// non-object value, a missing/non-list `items`, non-string entries, ids not in
/// the current catalog, and duplicates are all dropped (mirrors
/// [dataMenuSelectionFromSettings] and [templateFillFromSettings]); the result
/// defaults to [ComposedFill.empty]. Order is preserved from the stored list.
ComposedFill composedFillFromSettings(Map<String, dynamic>? settings) {
  final raw = settings?[_composedKey];
  if (raw is! Map) return ComposedFill.empty;
  final items = raw['items'];
  if (items is! List) return ComposedFill.empty;
  final ids = <String>[];
  for (final entry in items) {
    if (entry is String &&
        _knownCatalogIds.contains(entry) &&
        !ids.contains(entry)) {
      ids.add(entry);
    }
  }
  return ids.isEmpty ? ComposedFill.empty : ComposedFill(ids);
}

/// Builds the full `settings` envelope to write for a composed-card change:
/// preserves `schema_version` and `size` and sets the `composed` sub-object from
/// [fill]. Additive — never bumps the version. An empty fill omits the key.
Map<String, dynamic> mergeComposedFillIntoSettings(
  ProfileWidgetSize size,
  ComposedFill fill,
) => {
  'schema_version': kProfileWidgetSettingsVersion,
  'size': profileWidgetSizeToWire(size),
  if (!fill.isEmpty) _composedKey: {'items': fill.itemIds},
};

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

/// Serializes [kind] to its stable wire token. [ProfileWidgetKind.platform] and
/// [ProfileWidgetKind.template] are written today; the other kinds are reserved
/// for later phases.
String profileWidgetKindToWire(ProfileWidgetKind kind) => switch (kind) {
  ProfileWidgetKind.platform => 'platform',
  ProfileWidgetKind.dataMenu => 'data_menu',
  ProfileWidgetKind.template => 'template',
  ProfileWidgetKind.composed => 'composed_card',
  ProfileWidgetKind.showcase => 'showcase',
  ProfileWidgetKind.collection => 'collection',
};

ProfileWidgetKind? _kindFromWire(String value) => switch (value) {
  'platform' => ProfileWidgetKind.platform,
  'template' => ProfileWidgetKind.template,
  'composed_card' => ProfileWidgetKind.composed,
  'showcase' => ProfileWidgetKind.showcase,
  'collection' => ProfileWidgetKind.collection,
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
