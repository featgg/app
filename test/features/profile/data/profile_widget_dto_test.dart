import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/profile/data/profile_widget_dto.dart';
import 'package:featgg/src/features/profile/domain/art_framing.dart';
import 'package:featgg/src/features/profile/domain/art_selection.dart';
import 'package:featgg/src/features/profile/domain/collection_selection.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/domain/showcase_selection.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _row({
  String id = 'w-1',
  String? platform = 'steam',
  String type = 'platform',
  int position = 0,
  bool isEnabled = true,
  Object? size = 'small',
  int? schemaVersion = kProfileWidgetSettingsVersion,
  bool includeSettings = true,
  Object? dataMenuItems,
  Object? template,
  Object? composed,
  Object? showcase,
  Object? collection,
  Object? art,
  Object? framing,
}) {
  final settings = <String, dynamic>{};
  if (schemaVersion != null) settings['schema_version'] = schemaVersion;
  if (size != null) settings['size'] = size;
  if (dataMenuItems != null) settings['data_menu_items'] = dataMenuItems;
  if (template != null) settings['template'] = template;
  if (composed != null) settings['composed'] = composed;
  if (showcase != null) settings['showcase'] = showcase;
  if (collection != null) settings['collection'] = collection;
  if (art != null) settings['art'] = art;
  if (framing != null) settings['framing'] = framing;
  return {
    'id': id,
    'platform': platform,
    'type': type,
    'position': position,
    'is_enabled': isEnabled,
    if (includeSettings) 'settings': settings,
  };
}

void main() {
  group('profileWidgetFromDto — v1 envelope', () {
    test('maps a platform widget with a size token', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(_row(size: 'wide', position: 3)),
      );

      expect(widget, isNotNull);
      expect(widget!.kind, ProfileWidgetKind.platform);
      expect(widget.platform, Platform.steam);
      expect(widget.position, 3);
      expect(widget.isEnabled, isTrue);
    });

    test('absent settings entirely → small', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(_row(includeSettings: false)),
      );
      expect(widget, isNotNull);
    });
  });

  group('profileWidgetFromDto — soft resolution', () {
    test('unknown type token → null (omit)', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(_row(type: 'data_menu')),
      );
      expect(widget, isNull);
    });

    test('the retired kind tokens all degrade to null (omit)', () {
      // These rows may still exist on a profile. Omitting them is how the
      // retired kinds leave: the row stops resolving, so nothing renders it
      // and no migration is needed to make it disappear.
      for (final token in const ['data_menu', 'template', 'composed_card']) {
        final widget = profileWidgetFromDto(
          ProfileWidgetDto.fromJson(_row(type: token)),
        );
        expect(widget, isNull, reason: token);
      }
    });

    test('schema_version != 1 → null (omit)', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(_row(schemaVersion: 2)),
      );
      expect(widget, isNull);
    });

    test('unknown platform token on a platform kind → null (omit)', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(_row(platform: 'not_a_platform')),
      );
      expect(widget, isNull);
    });

    test('null platform on a platform kind → null (omit)', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(_row(platform: null)),
      );
      expect(widget, isNull);
    });
  });

  group('serialization helpers', () {
    test('profileWidgetKindToWire maps every kind to its wire token', () {
      expect(profileWidgetKindToWire(ProfileWidgetKind.platform), 'platform');
      expect(profileWidgetKindToWire(ProfileWidgetKind.showcase), 'showcase');
      expect(
        profileWidgetKindToWire(ProfileWidgetKind.collection),
        'collection',
      );
      expect(
        profileWidgetKindToWire(ProfileWidgetKind.gameCollector),
        'game_collector',
      );
      expect(
        profileWidgetKindToWire(ProfileWidgetKind.completionist),
        'completionist',
      );
      expect(profileWidgetKindToWire(ProfileWidgetKind.passport), 'passport');
      expect(profileWidgetKindToWire(ProfileWidgetKind.rank), 'rank');
      expect(profileWidgetKindToWire(ProfileWidgetKind.main), 'main');
      expect(profileWidgetKindToWire(ProfileWidgetKind.art), 'art');
    });
  });

  group('rank binding (platform-BOUND, size-only envelope)', () {
    test('a non-null rank row round-trips to the kind with its platform', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(
          _row(type: 'rank', platform: 'league_of_legends'),
        ),
      );

      expect(widget, isNotNull);
      expect(widget!.kind, ProfileWidgetKind.rank);
      // Platform-bound: the source platform lives in the row's `platform` column.
      expect(widget.platform, Platform.leagueOfLegends);
    });

    test('a null-platform rank row → null (binding rule)', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(_row(type: 'rank', platform: null)),
      );
      expect(widget, isNull);
    });

    test('an unknown-platform rank row → null (binding rule)', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(
          _row(type: 'rank', platform: 'not_a_platform'),
        ),
      );
      expect(widget, isNull);
    });
  });

  group('main binding (platform-BOUND, size-only envelope)', () {
    test('a non-null main row round-trips to the kind with its platform', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(_row(type: 'main', platform: 'steam')),
      );

      expect(widget, isNotNull);
      expect(widget!.kind, ProfileWidgetKind.main);
      expect(widget.platform, Platform.steam);
    });

    test('a null-platform main row → null (binding rule)', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(_row(type: 'main', platform: null)),
      );
      expect(widget, isNull);
    });

    test('an unknown-platform main row → null (binding rule)', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(
          _row(type: 'main', platform: 'not_a_platform'),
        ),
      );
      expect(widget, isNull);
    });
  });

  group('showcase selection round-trip (additive to the v1 envelope)', () {
    test(
      'a showcase row maps to a showcase kind with platform + selection',
      () {
        final widget = profileWidgetFromDto(
          ProfileWidgetDto.fromJson(
            _row(
              type: 'showcase',
              platform: 'steam',
              size: 'large',
              showcase: {'game': '730', 'hero': 'hours'},
            ),
          ),
        );

        expect(widget, isNotNull);
        expect(widget!.kind, ProfileWidgetKind.showcase);
        // The source platform is the row's `platform` column, non-null per the
        // binding rule — not duplicated inside settings.
        expect(widget.platform, Platform.steam);
        expect(widget.showcaseSelection.gameRef, '730');
        expect(widget.showcaseSelection.hero, ShowcaseHeroStat.hours);
        expect(widget.showcaseSelection.meta, isNull);
      },
    );

    test('a showcase row with a null platform → null (binding rule)', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(
          _row(type: 'showcase', platform: null, showcase: {'game': '730'}),
        ),
      );
      expect(widget, isNull);
    });

    test(
      'a showcase row with an unknown platform token → null (binding rule)',
      () {
        final widget = profileWidgetFromDto(
          ProfileWidgetDto.fromJson(
            _row(
              type: 'showcase',
              platform: 'not_a_platform',
              showcase: {'game': '730'},
            ),
          ),
        );
        expect(widget, isNull);
      },
    );

    test(
      'an unknown hero token → default hours (lenient, forward-compatible)',
      () {
        final sel = showcaseSelectionFromSettings({
          'showcase': {'game': '730', 'hero': 'bananas'},
        });
        expect(sel.gameRef, '730');
        expect(sel.hero, ShowcaseHeroStat.hours);
        expect(sel.meta, isNull);
      },
    );

    test(
      'showcaseSelectionFromSettings is lenient on null/non-map/missing game',
      () {
        expect(showcaseSelectionFromSettings(null), ShowcaseSelection.empty);
        expect(
          showcaseSelectionFromSettings({'showcase': 'oops'}),
          ShowcaseSelection.empty,
        );
        expect(
          showcaseSelectionFromSettings({
            'showcase': {'hero': 'hours'},
          }),
          ShowcaseSelection.empty,
        );
        expect(
          showcaseSelectionFromSettings({
            'showcase': {'game': ''},
          }),
          ShowcaseSelection.empty,
        );
      },
    );

    test(
      'a platform row carries an empty showcase selection (no disturbance)',
      () {
        final widget = profileWidgetFromDto(ProfileWidgetDto.fromJson(_row()));

        expect(widget!.kind, ProfileWidgetKind.platform);
        expect(widget.showcaseSelection, ShowcaseSelection.empty);
      },
    );

    test('merge writer preserves schema_version + size and sets game/hero', () {
      final merged = mergeShowcaseSelectionIntoSettings(
        const ShowcaseSelection(gameRef: '730'),
      );

      expect(merged['schema_version'], kProfileWidgetSettingsVersion);
      final showcase = merged['showcase'] as Map<String, dynamic>;
      expect(showcase['game'], '730');
      expect(showcase['hero'], 'hours');
      expect(showcase.containsKey('meta'), isFalse);
    });

    test('merge writer omits the showcase key for an empty selection', () {
      final merged = mergeShowcaseSelectionIntoSettings(
        ShowcaseSelection.empty,
      );

      expect(merged['schema_version'], kProfileWidgetSettingsVersion);
      expect(merged.containsKey('showcase'), isFalse);
    });

    test('round-trips merge → fromDto with non-null platform + selection', () {
      final merged = mergeShowcaseSelectionIntoSettings(
        const ShowcaseSelection(gameRef: '730'),
      );
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson({
          'id': 'w-showcase',
          'platform': 'steam',
          'type': 'showcase',
          'position': 0,
          'is_enabled': true,
          'settings': merged,
        }),
      );

      expect(widget, isNotNull);
      expect(widget!.kind, ProfileWidgetKind.showcase);
      expect(widget.platform, Platform.steam);
      expect(widget.showcaseSelection.gameRef, '730');
      expect(widget.showcaseSelection.hero, ShowcaseHeroStat.hours);
    });

    test('an achievements hero token maps to the achievements stat', () {
      final sel = showcaseSelectionFromSettings({
        'showcase': {'game': '730', 'hero': 'achievements'},
      });
      expect(sel.gameRef, '730');
      expect(sel.hero, ShowcaseHeroStat.achievements);
    });

    test('round-trips an achievements hero through merge → fromDto', () {
      final merged = mergeShowcaseSelectionIntoSettings(
        const ShowcaseSelection(
          gameRef: '730',
          hero: ShowcaseHeroStat.achievements,
        ),
      );
      expect(
        (merged['showcase'] as Map<String, dynamic>)['hero'],
        'achievements',
      );

      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson({
          'id': 'w-showcase',
          'platform': 'steam',
          'type': 'showcase',
          'position': 0,
          'is_enabled': true,
          'settings': merged,
        }),
      );

      expect(widget!.showcaseSelection.hero, ShowcaseHeroStat.achievements);
    });

    test('hero-stat wire helpers round-trip both tokens', () {
      expect(showcaseHeroStatToWire(ShowcaseHeroStat.hours), 'hours');
      expect(
        showcaseHeroStatToWire(ShowcaseHeroStat.achievements),
        'achievements',
      );
      expect(showcaseHeroStatFromWire('hours'), ShowcaseHeroStat.hours);
      expect(
        showcaseHeroStatFromWire('achievements'),
        ShowcaseHeroStat.achievements,
      );
      expect(showcaseHeroStatFromWire('bananas'), isNull);
    });
  });

  group('collection selection round-trip (additive to the v1 envelope)', () {
    test(
      'a collection row maps to the kind with a null platform + selection',
      () {
        final widget = profileWidgetFromDto(
          ProfileWidgetDto.fromJson(
            _row(
              type: 'collection',
              platform: null,
              size: 'wide',
              collection: {
                'games': ['730', '570', '440'],
                'title': 'collectionTitleFavorites',
              },
            ),
          ),
        );

        expect(widget, isNotNull);
        expect(widget!.kind, ProfileWidgetKind.collection);
        // A collection spans multiple games — the binding rule keeps platform
        // null.
        expect(widget.platform, isNull);
        expect(widget.collectionSelection.gameRefs, ['730', '570', '440']);
        expect(widget.collectionSelection.titleKey, 'collectionTitleFavorites');
      },
    );

    test(
      'a collection row with a stray platform still maps with null (lenient)',
      () {
        final widget = profileWidgetFromDto(
          ProfileWidgetDto.fromJson(
            _row(
              type: 'collection',
              platform: 'steam',
              collection: {
                'games': ['730'],
              },
            ),
          ),
        );

        expect(widget, isNotNull);
        expect(widget!.kind, ProfileWidgetKind.collection);
        expect(widget.platform, isNull);
        expect(widget.collectionSelection.gameRefs, ['730']);
        expect(widget.collectionSelection.titleKey, isNull);
      },
    );

    test('duplicate / garbage game refs are dropped on read', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(
          _row(
            type: 'collection',
            platform: null,
            collection: {
              'games': ['730', '730', '', 42, '570'],
            },
          ),
        ),
      );

      expect(widget!.collectionSelection.gameRefs, ['730', '570']);
    });

    test('a non-object collection → empty selection', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(
          _row(type: 'collection', platform: null, collection: 'oops'),
        ),
      );

      expect(widget!.collectionSelection, CollectionSelection.empty);
    });

    test('a non-list games → empty selection', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(
          _row(
            type: 'collection',
            platform: null,
            collection: {'games': 'oops'},
          ),
        ),
      );

      expect(widget!.collectionSelection, CollectionSelection.empty);
    });

    test('a platform row carries an empty collection selection', () {
      final widget = profileWidgetFromDto(ProfileWidgetDto.fromJson(_row()));

      expect(widget!.kind, ProfileWidgetKind.platform);
      expect(widget.collectionSelection, CollectionSelection.empty);
    });

    test('collectionSelectionFromSettings is lenient on a null envelope', () {
      expect(collectionSelectionFromSettings(null), CollectionSelection.empty);
    });

    test(
      'merge writer preserves schema_version + size and sets games/title',
      () {
        final merged = mergeCollectionSelectionIntoSettings(
          const CollectionSelection(
            gameRefs: ['730', '570'],
            titleKey: 'collectionTitleBacklog',
          ),
        );

        expect(merged['schema_version'], kProfileWidgetSettingsVersion);
        final collection = merged['collection'] as Map<String, dynamic>;
        expect(collection['games'], ['730', '570']);
        expect(collection['title'], 'collectionTitleBacklog');
      },
    );

    test('merge writer omits the title when none is set', () {
      final merged = mergeCollectionSelectionIntoSettings(
        const CollectionSelection(gameRefs: ['730']),
      );

      final collection = merged['collection'] as Map<String, dynamic>;
      expect(collection['games'], ['730']);
      expect(collection.containsKey('title'), isFalse);
    });

    test('merge writer omits the collection key for an empty selection', () {
      final merged = mergeCollectionSelectionIntoSettings(
        CollectionSelection.empty,
      );

      expect(merged['schema_version'], kProfileWidgetSettingsVersion);
      expect(merged.containsKey('collection'), isFalse);
    });

    test('round-trips merge → fromDto with a null platform + selection', () {
      final merged = mergeCollectionSelectionIntoSettings(
        const CollectionSelection(
          gameRefs: ['730', '570', '440'],
          titleKey: 'collectionTitleMostPlayed',
        ),
      );
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson({
          'id': 'w-collection',
          'platform': null,
          'type': 'collection',
          'position': 0,
          'is_enabled': true,
          'settings': merged,
        }),
      );

      expect(widget, isNotNull);
      expect(widget!.kind, ProfileWidgetKind.collection);
      expect(widget.platform, isNull);
      expect(widget.collectionSelection.gameRefs, ['730', '570', '440']);
      expect(widget.collectionSelection.titleKey, 'collectionTitleMostPlayed');
    });
  });

  group('game_collector binding (platform-BOUND, size-only envelope)', () {
    test('a non-null Steam game_collector row round-trips to the kind', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(
          _row(type: 'game_collector', platform: 'steam'),
        ),
      );

      expect(widget, isNotNull);
      expect(widget!.kind, ProfileWidgetKind.gameCollector);
      // Platform-bound: the source platform lives in the row's `platform` column.
      expect(widget.platform, Platform.steam);
    });

    test('a null-platform game_collector row → null (binding rule)', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(_row(type: 'game_collector', platform: null)),
      );
      expect(widget, isNull);
    });

    test('an unknown-platform game_collector row → null (binding rule)', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(
          _row(type: 'game_collector', platform: 'not_a_platform'),
        ),
      );
      expect(widget, isNull);
    });

    test('the row carries no selection sub-object (size-only envelope)', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(
          _row(type: 'game_collector', platform: 'steam'),
        ),
      );

      // A game collector has no per-widget choice; the empty defaults hold.
      expect(widget!.showcaseSelection, ShowcaseSelection.empty);
      expect(widget.collectionSelection, CollectionSelection.empty);
    });
  });

  group('completionist binding (platform-BOUND, size-only envelope)', () {
    test('a non-null Steam completionist row round-trips to the kind', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(
          _row(type: 'completionist', platform: 'steam'),
        ),
      );

      expect(widget, isNotNull);
      expect(widget!.kind, ProfileWidgetKind.completionist);
      // Platform-bound: the source platform lives in the row's `platform` column.
      expect(widget.platform, Platform.steam);
    });

    test('a null-platform completionist row → null (binding rule)', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(_row(type: 'completionist', platform: null)),
      );
      expect(widget, isNull);
    });

    test('an unknown-platform completionist row → null (binding rule)', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(
          _row(type: 'completionist', platform: 'not_a_platform'),
        ),
      );
      expect(widget, isNull);
    });

    test('the row carries no selection sub-object (size-only envelope)', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(
          _row(type: 'completionist', platform: 'steam'),
        ),
      );

      // A completionist has no per-widget choice; the empty defaults hold.
      expect(widget!.showcaseSelection, ShowcaseSelection.empty);
      expect(widget.collectionSelection, CollectionSelection.empty);
    });
  });

  group('passport binding (platform-NULL, size-only envelope)', () {
    test('a null-platform passport row round-trips to the kind with its '
        'size', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(_row(type: 'passport', platform: null)),
      );

      expect(widget, isNotNull);
      expect(widget!.kind, ProfileWidgetKind.passport);
      // A passport aggregates every linked platform — the binding rule keeps
      // platform null.
      expect(widget.platform, isNull);
    });

    test('a passport row with a stray platform still maps with null '
        '(lenient)', () {
      // Passport is not in the platform-required block, so a stray platform
      // token does not drop the row; the entity platform stays null.
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(_row(type: 'passport', platform: 'steam')),
      );

      expect(widget, isNotNull);
      expect(widget!.kind, ProfileWidgetKind.passport);
      expect(widget.platform, isNull);
    });

    test('the row carries no selection sub-object (size-only envelope)', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(_row(type: 'passport', platform: null)),
      );

      // A passport has no per-widget choice; the empty defaults hold.
      expect(widget!.showcaseSelection, ShowcaseSelection.empty);
      expect(widget.collectionSelection, CollectionSelection.empty);
    });
  });

  group('art selection round-trip (platform-NULL, source in the envelope)', () {
    test('a null-platform art row round-trips to the kind with its '
        'source', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(
          _row(
            type: 'art',
            platform: null,
            size: 'wide',
            art: {'source': 'league_of_legends'},
          ),
        ),
      );

      expect(widget, isNotNull);
      expect(widget!.kind, ProfileWidgetKind.art);
      // An art card reads no account data, so its row carries no binding; the
      // picture it points at is the envelope's business.
      expect(widget.platform, isNull);
      expect(widget.artSelection.source, Platform.leagueOfLegends);
    });

    test('an art row with no source maps to the empty selection', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(_row(type: 'art', platform: null)),
      );

      expect(widget!.kind, ProfileWidgetKind.art);
      expect(widget.artSelection, ArtSelection.empty);
    });

    test('artSelectionFromSettings is lenient on a null, non-map, missing, '
        'non-string, or unknown source', () {
      expect(artSelectionFromSettings(null), ArtSelection.empty);
      expect(artSelectionFromSettings({'art': 'oops'}), ArtSelection.empty);
      expect(
        artSelectionFromSettings({'art': <String, dynamic>{}}),
        ArtSelection.empty,
      );
      expect(
        artSelectionFromSettings({
          'art': {'source': 42},
        }),
        ArtSelection.empty,
      );
      expect(
        artSelectionFromSettings({
          'art': {'source': 'nintendo'},
        }),
        ArtSelection.empty,
      );
    });

    test('mergeArtSelectionIntoSettings writes the v1 envelope with the wire '
        'source', () {
      final merged = mergeArtSelectionIntoSettings(
        const ArtSelection(source: Platform.wowRetail),
      );

      expect(merged['schema_version'], kProfileWidgetSettingsVersion);
      expect((merged['art']! as Map)['source'], 'wow_retail');
    });

    test('an empty selection writes no art sub-object', () {
      final merged = mergeArtSelectionIntoSettings(ArtSelection.empty);

      expect(merged.containsKey('art'), isFalse);
    });

    test('serialize → parse preserves the source', () {
      const selection = ArtSelection(source: Platform.steam);

      expect(
        artSelectionFromSettings(mergeArtSelectionIntoSettings(selection)),
        selection,
      );
    });
  });

  group('art framing', () {
    test('a row with no framing key reads as the centre', () {
      final w = profileWidgetFromDto(ProfileWidgetDto.fromJson(_row()));

      expect(w!.framing, ArtFraming.center);
    });

    test('a stored point is read back', () {
      final w = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(_row(framing: {'x': 0.25, 'y': 0.75})),
      );

      expect(w!.framing, const ArtFraming(x: 0.25, y: 0.75));
    });

    test('an integer coordinate is read, not rejected', () {
      // JSON carries 0 and 1 as ints; a framing pushed to an edge is exactly
      // where those turn up, so a num-blind read would silently drop the
      // framings most likely to matter.
      final w = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(_row(framing: {'x': 0, 'y': 1})),
      );

      expect(w!.framing, const ArtFraming(x: 0, y: 1));
    });

    test('a coordinate outside the picture is pulled back into it', () {
      final w = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(_row(framing: {'x': -3.0, 'y': 9.0})),
      );

      expect(w!.framing, const ArtFraming(x: 0, y: 1));
    });

    for (final bad in <Object>[
      'middle',
      <Object>[0.5, 0.5],
      {'x': 'left', 'y': 0.5},
      {'y': 0.5},
    ]) {
      test('a malformed framing ($bad) costs the framing, not the card', () {
        final w = profileWidgetFromDto(
          ProfileWidgetDto.fromJson(_row(framing: bad)),
        );

        expect(w, isNotNull);
        expect(w!.framing, ArtFraming.center);
      });
    }

    test('the centre writes no framing key', () {
      const w = ProfileWidget(
        id: 'w-1',
        kind: ProfileWidgetKind.art,
        platform: null,
        position: 0,
        isEnabled: true,
      );

      expect(
        settingsWithFraming(w, ArtFraming.center).containsKey('framing'),
        isFalse,
      );
    });

    test('reframing back to the centre drops the key it wrote', () {
      const w = ProfileWidget(
        id: 'w-1',
        kind: ProfileWidgetKind.art,
        platform: null,
        position: 0,
        isEnabled: true,
        framing: ArtFraming(x: 0.1, y: 0.9),
        storedSettings: {
          'schema_version': 1,
          'framing': {'x': 0.1, 'y': 0.9},
        },
      );

      expect(
        settingsWithFraming(w, ArtFraming.center).containsKey('framing'),
        isFalse,
      );
    });

    test('a framing write keeps the kind sub-object beside it', () {
      // The two live in one envelope. A write that emitted only its own key
      // would take the card's picture with it.
      const w = ProfileWidget(
        id: 'w-1',
        kind: ProfileWidgetKind.art,
        platform: null,
        position: 0,
        isEnabled: true,
        artSelection: ArtSelection(source: Platform.steam),
        storedSettings: {
          'schema_version': 1,
          'art': {'source': 'steam'},
        },
      );

      final written = settingsWithFraming(w, const ArtFraming(x: 0.1, y: 0.9));

      expect((written['art']! as Map)['source'], 'steam');
      expect(written['framing'], {'x': 0.1, 'y': 0.9});
      expect(written['schema_version'], kProfileWidgetSettingsVersion);
    });

    test('a framing write keeps a key this build does not understand', () {
      // The envelope is additive under one schema version, so another build
      // can have written a field this one has no reading for. Rebuilding the
      // envelope from what this build parses would delete it — the same
      // profile losing content by being opened on the wrong version.
      const w = ProfileWidget(
        id: 'w-1',
        kind: ProfileWidgetKind.art,
        platform: null,
        position: 0,
        isEnabled: true,
        storedSettings: {
          'schema_version': 1,
          'something_a_later_build_wrote': {'keep': 'me'},
        },
      );

      final written = settingsWithFraming(w, const ArtFraming(x: 0.2, y: 0.3));

      expect(written['something_a_later_build_wrote'], {'keep': 'me'});
    });

    test('the write does not mutate the envelope it was given', () {
      const stored = {'schema_version': 1};
      const w = ProfileWidget(
        id: 'w-1',
        kind: ProfileWidgetKind.art,
        platform: null,
        position: 0,
        isEnabled: true,
        storedSettings: stored,
      );

      settingsWithFraming(w, const ArtFraming(x: 0.2, y: 0.3));

      expect(stored.containsKey('framing'), isFalse);
    });

    test('serialize -> parse preserves the point', () {
      const w = ProfileWidget(
        id: 'w-1',
        kind: ProfileWidgetKind.art,
        platform: null,
        position: 0,
        isEnabled: true,
      );
      const framing = ArtFraming(x: 0.2, y: 0.4);

      expect(artFramingFromSettings(settingsWithFraming(w, framing)), framing);
    });
  });
}
