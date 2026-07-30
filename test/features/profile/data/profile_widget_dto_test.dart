import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/profile/data/profile_widget_dto.dart';
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
      expect(widget.size, ProfileWidgetSize.wide);
      expect(widget.position, 3);
      expect(widget.isEnabled, isTrue);
    });

    test('round-trips the three size tokens', () {
      const cases = {
        'small': ProfileWidgetSize.small,
        'wide': ProfileWidgetSize.wide,
        'large': ProfileWidgetSize.large,
      };
      for (final entry in cases.entries) {
        final widget = profileWidgetFromDto(
          ProfileWidgetDto.fromJson(_row(size: entry.key)),
        );
        expect(widget!.size, entry.value, reason: entry.key);
      }
    });

    test('unknown size token → small', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(_row(size: 'gigantic')),
      );
      expect(widget!.size, ProfileWidgetSize.small);
    });

    test('absent size key → small', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(_row(size: null)),
      );
      expect(widget!.size, ProfileWidgetSize.small);
    });

    test('absent settings entirely → small', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(_row(includeSettings: false)),
      );
      expect(widget, isNotNull);
      expect(widget!.size, ProfileWidgetSize.small);
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
    test('profileWidgetSizeToWire round-trips the size tokens', () {
      expect(profileWidgetSizeToWire(ProfileWidgetSize.small), 'small');
      expect(profileWidgetSizeToWire(ProfileWidgetSize.wide), 'wide');
      expect(profileWidgetSizeToWire(ProfileWidgetSize.large), 'large');
    });

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
          _row(type: 'rank', platform: 'league_of_legends', size: 'small'),
        ),
      );

      expect(widget, isNotNull);
      expect(widget!.kind, ProfileWidgetKind.rank);
      // Platform-bound: the source platform lives in the row's `platform` column.
      expect(widget.platform, Platform.leagueOfLegends);
      expect(widget.size, ProfileWidgetSize.small);
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
        ProfileWidgetDto.fromJson(
          _row(type: 'main', platform: 'steam', size: 'wide'),
        ),
      );

      expect(widget, isNotNull);
      expect(widget!.kind, ProfileWidgetKind.main);
      expect(widget.platform, Platform.steam);
      expect(widget.size, ProfileWidgetSize.wide);
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
        expect(widget.size, ProfileWidgetSize.large);
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
        final widget = profileWidgetFromDto(
          ProfileWidgetDto.fromJson(_row(size: 'wide')),
        );

        expect(widget!.kind, ProfileWidgetKind.platform);
        expect(widget.showcaseSelection, ShowcaseSelection.empty);
      },
    );

    test('merge writer preserves schema_version + size and sets game/hero', () {
      final merged = mergeShowcaseSelectionIntoSettings(
        ProfileWidgetSize.large,
        const ShowcaseSelection(gameRef: '730'),
      );

      expect(merged['schema_version'], kProfileWidgetSettingsVersion);
      expect(merged['size'], 'large');
      final showcase = merged['showcase'] as Map<String, dynamic>;
      expect(showcase['game'], '730');
      expect(showcase['hero'], 'hours');
      expect(showcase.containsKey('meta'), isFalse);
    });

    test('merge writer omits the showcase key for an empty selection', () {
      final merged = mergeShowcaseSelectionIntoSettings(
        ProfileWidgetSize.small,
        ShowcaseSelection.empty,
      );

      expect(merged['schema_version'], kProfileWidgetSettingsVersion);
      expect(merged['size'], 'small');
      expect(merged.containsKey('showcase'), isFalse);
    });

    test('round-trips merge → fromDto with non-null platform + selection', () {
      final merged = mergeShowcaseSelectionIntoSettings(
        ProfileWidgetSize.large,
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
        ProfileWidgetSize.large,
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
        expect(widget.size, ProfileWidgetSize.wide);
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
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(_row(size: 'wide')),
      );

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
          ProfileWidgetSize.wide,
          const CollectionSelection(
            gameRefs: ['730', '570'],
            titleKey: 'collectionTitleBacklog',
          ),
        );

        expect(merged['schema_version'], kProfileWidgetSettingsVersion);
        expect(merged['size'], 'wide');
        final collection = merged['collection'] as Map<String, dynamic>;
        expect(collection['games'], ['730', '570']);
        expect(collection['title'], 'collectionTitleBacklog');
      },
    );

    test('merge writer omits the title when none is set', () {
      final merged = mergeCollectionSelectionIntoSettings(
        ProfileWidgetSize.small,
        const CollectionSelection(gameRefs: ['730']),
      );

      final collection = merged['collection'] as Map<String, dynamic>;
      expect(collection['games'], ['730']);
      expect(collection.containsKey('title'), isFalse);
    });

    test('merge writer omits the collection key for an empty selection', () {
      final merged = mergeCollectionSelectionIntoSettings(
        ProfileWidgetSize.small,
        CollectionSelection.empty,
      );

      expect(merged['schema_version'], kProfileWidgetSettingsVersion);
      expect(merged['size'], 'small');
      expect(merged.containsKey('collection'), isFalse);
    });

    test('round-trips merge → fromDto with a null platform + selection', () {
      final merged = mergeCollectionSelectionIntoSettings(
        ProfileWidgetSize.wide,
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
      expect(widget.size, ProfileWidgetSize.wide);
    });
  });

  group('game_collector binding (platform-BOUND, size-only envelope)', () {
    test('a non-null Steam game_collector row round-trips to the kind', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(
          _row(type: 'game_collector', platform: 'steam', size: 'large'),
        ),
      );

      expect(widget, isNotNull);
      expect(widget!.kind, ProfileWidgetKind.gameCollector);
      // Platform-bound: the source platform lives in the row's `platform` column.
      expect(widget.platform, Platform.steam);
      expect(widget.size, ProfileWidgetSize.large);
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
          _row(type: 'completionist', platform: 'steam', size: 'large'),
        ),
      );

      expect(widget, isNotNull);
      expect(widget!.kind, ProfileWidgetKind.completionist);
      // Platform-bound: the source platform lives in the row's `platform` column.
      expect(widget.platform, Platform.steam);
      expect(widget.size, ProfileWidgetSize.large);
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
        ProfileWidgetDto.fromJson(
          _row(type: 'passport', platform: null, size: 'wide'),
        ),
      );

      expect(widget, isNotNull);
      expect(widget!.kind, ProfileWidgetKind.passport);
      // A passport aggregates every linked platform — the binding rule keeps
      // platform null.
      expect(widget.platform, isNull);
      expect(widget.size, ProfileWidgetSize.wide);
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
      expect(widget.size, ProfileWidgetSize.wide);
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
        ProfileWidgetSize.wide,
        const ArtSelection(source: Platform.wowRetail),
      );

      expect(merged['schema_version'], kProfileWidgetSettingsVersion);
      expect(merged['size'], 'wide');
      expect((merged['art']! as Map)['source'], 'wow_retail');
    });

    test('an empty selection writes no art sub-object', () {
      final merged = mergeArtSelectionIntoSettings(
        ProfileWidgetSize.wide,
        ArtSelection.empty,
      );

      expect(merged['size'], 'wide');
      expect(merged.containsKey('art'), isFalse);
    });

    test('serialize → parse preserves the source', () {
      const selection = ArtSelection(source: Platform.steam);

      expect(
        artSelectionFromSettings(
          mergeArtSelectionIntoSettings(ProfileWidgetSize.wide, selection),
        ),
        selection,
      );
    });
  });
}
