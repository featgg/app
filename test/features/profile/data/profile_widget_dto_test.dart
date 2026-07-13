import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/profile/data/profile_widget_dto.dart';
import 'package:featgg/src/features/profile/domain/collection_selection.dart';
import 'package:featgg/src/features/profile/domain/composed_card.dart';
import 'package:featgg/src/features/profile/domain/data_menu_selection.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/domain/showcase_selection.dart';
import 'package:featgg/src/features/profile/domain/template_catalog.dart';
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
}) {
  final settings = <String, dynamic>{};
  if (schemaVersion != null) settings['schema_version'] = schemaVersion;
  if (size != null) settings['size'] = size;
  if (dataMenuItems != null) settings['data_menu_items'] = dataMenuItems;
  if (template != null) settings['template'] = template;
  if (composed != null) settings['composed'] = composed;
  if (showcase != null) settings['showcase'] = showcase;
  if (collection != null) settings['collection'] = collection;
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

    test('reserved (unwired) kind tokens all degrade to null (omit)', () {
      // The reserved kinds are named in the wire taxonomy but not yet wired on
      // read; an older client must omit a row a newer client writes, never
      // crash. `template` and `composed_card` are now wired kinds, so they
      // leave this set.
      for (final token in const ['data_menu']) {
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
      expect(profileWidgetKindToWire(ProfileWidgetKind.dataMenu), 'data_menu');
      expect(profileWidgetKindToWire(ProfileWidgetKind.template), 'template');
      expect(
        profileWidgetKindToWire(ProfileWidgetKind.composed),
        'composed_card',
      );
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
    });
  });

  group('data-menu selection round-trip (additive to the v1 envelope)', () {
    test('a row with data_menu_items parses selection AND keeps size', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(
          _row(
            size: 'wide',
            dataMenuItems: ['steam.hours_played', 'steam.library_showcase'],
          ),
        ),
      );

      expect(widget, isNotNull);
      expect(widget!.size, ProfileWidgetSize.wide);
      expect(widget.selection.selectedIds, {
        'steam.hours_played',
        'steam.library_showcase',
      });
    });

    test('a row with no data_menu_items → empty selection, size unchanged', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(_row(size: 'large')),
      );

      expect(widget!.selection, DataMenuSelection.empty);
      expect(widget.size, ProfileWidgetSize.large);
    });

    test('unknown / garbage ids are dropped on read', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(
          _row(
            dataMenuItems: [
              'steam.hours_played', // known
              'not.a.real.id', // unknown → dropped
              42, // non-string → dropped
            ],
          ),
        ),
      );

      expect(widget!.selection.selectedIds, {'steam.hours_played'});
    });

    test('a non-list data_menu_items → empty selection', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(_row(dataMenuItems: 'oops')),
      );
      expect(widget!.selection, DataMenuSelection.empty);
    });

    test('dataMenuSelectionFromSettings is lenient on a null envelope', () {
      expect(dataMenuSelectionFromSettings(null), DataMenuSelection.empty);
    });

    test('merge writer preserves schema_version + size and sets the ids', () {
      final merged = mergeDataMenuSelectionIntoSettings(
        ProfileWidgetSize.wide,
        const DataMenuSelection({'gw2.total_ap'}),
      );

      expect(merged['schema_version'], kProfileWidgetSettingsVersion);
      expect(merged['size'], 'wide');
      expect(merged['data_menu_items'], ['gw2.total_ap']);
    });

    test('merge writer omits data_menu_items for an empty selection', () {
      final merged = mergeDataMenuSelectionIntoSettings(
        ProfileWidgetSize.small,
        DataMenuSelection.empty,
      );

      expect(merged['schema_version'], kProfileWidgetSettingsVersion);
      expect(merged['size'], 'small');
      expect(merged.containsKey('data_menu_items'), isFalse);
    });
  });

  group('template fill round-trip (additive to the v1 envelope)', () {
    test('a template row maps to a template-kind widget with its fill', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(
          _row(
            type: 'template',
            platform: null,
            size: 'wide',
            template: {
              'id': 'my_ranks',
              'slots': {'slot_1': 'chess.rating'},
            },
          ),
        ),
      );

      expect(widget, isNotNull);
      expect(widget!.kind, ProfileWidgetKind.template);
      expect(widget.platform, isNull);
      expect(widget.size, ProfileWidgetSize.wide);
      expect(widget.templateFill.templateId, 'my_ranks');
      expect(widget.templateFill.itemIdFor('slot_1'), 'chess.rating');
    });

    test('a template row with no slots maps to an empty-slot fill', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(
          _row(type: 'template', platform: null, template: {'id': 'my_levels'}),
        ),
      );

      expect(widget!.templateFill.templateId, 'my_levels');
      expect(widget.templateFill.slotItemIds, isEmpty);
    });

    test(
      'a template row preserves size + leaves data-menu selection empty',
      () {
        final widget = profileWidgetFromDto(
          ProfileWidgetDto.fromJson(
            _row(
              type: 'template',
              platform: null,
              size: 'large',
              template: {'id': 'my_ranks'},
            ),
          ),
        );

        expect(widget!.size, ProfileWidgetSize.large);
        expect(widget.selection, DataMenuSelection.empty);
      },
    );

    test('a platform row carries an empty template fill (no disturbance)', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(
          _row(size: 'wide', dataMenuItems: ['steam.hours_played']),
        ),
      );

      expect(widget!.kind, ProfileWidgetKind.platform);
      expect(widget.templateFill, TemplateFill.empty);
      expect(widget.size, ProfileWidgetSize.wide);
      expect(widget.selection.selectedIds, {'steam.hours_played'});
    });

    test('unknown / garbage slot item ids are dropped on read', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(
          _row(
            type: 'template',
            platform: null,
            template: {
              'id': 'my_ranks',
              'slots': {
                'slot_1': 'chess.rating', // known → kept
                'slot_2': 'not.a.real.id', // unknown → dropped
                'slot_3': 42, // non-string → dropped
              },
            },
          ),
        ),
      );

      expect(widget!.templateFill.slotItemIds, {'slot_1': 'chess.rating'});
    });

    test('a stale template id is kept raw (renderer soft-resolves it)', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(
          _row(type: 'template', platform: null, template: {'id': 'gone'}),
        ),
      );

      expect(widget!.templateFill.templateId, 'gone');
    });

    test('a malformed template (non-object) → empty fill', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(
          _row(type: 'template', platform: null, template: 'oops'),
        ),
      );

      expect(widget!.templateFill, TemplateFill.empty);
    });

    test('a template with a non-string id → empty fill', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(
          _row(type: 'template', platform: null, template: {'id': 7}),
        ),
      );

      expect(widget!.templateFill, TemplateFill.empty);
    });

    test('templateFillFromSettings is lenient on a null envelope', () {
      expect(templateFillFromSettings(null), TemplateFill.empty);
    });

    test('merge writer preserves schema_version + size and sets the fill', () {
      final merged = mergeTemplateFillIntoSettings(
        ProfileWidgetSize.wide,
        const TemplateFill('my_ranks', {'slot_1': 'chess.rating'}),
      );

      expect(merged['schema_version'], kProfileWidgetSettingsVersion);
      expect(merged['size'], 'wide');
      final template = merged['template'] as Map<String, dynamic>;
      expect(template['id'], 'my_ranks');
      expect(template['slots'], {'slot_1': 'chess.rating'});
    });

    test('merge writer omits slots for an empty-slot fill', () {
      final merged = mergeTemplateFillIntoSettings(
        ProfileWidgetSize.small,
        const TemplateFill('my_ranks', {}),
      );

      final template = merged['template'] as Map<String, dynamic>;
      expect(template['id'], 'my_ranks');
      expect(template.containsKey('slots'), isFalse);
    });

    test('merge writer omits the template key for an un-chosen template', () {
      final merged = mergeTemplateFillIntoSettings(
        ProfileWidgetSize.small,
        TemplateFill.empty,
      );

      expect(merged['schema_version'], kProfileWidgetSettingsVersion);
      expect(merged['size'], 'small');
      expect(merged.containsKey('template'), isFalse);
    });
  });

  group('composed fill round-trip (additive to the v1 envelope)', () {
    test(
      'a composed_card row maps to a composed-kind widget with its fill',
      () {
        final widget = profileWidgetFromDto(
          ProfileWidgetDto.fromJson(
            _row(
              type: 'composed_card',
              platform: null,
              size: 'wide',
              composed: {
                'items': ['chess.rating', 'wow_retail.profile'],
              },
            ),
          ),
        );

        expect(widget, isNotNull);
        expect(widget!.kind, ProfileWidgetKind.composed);
        expect(widget.platform, isNull);
        expect(widget.size, ProfileWidgetSize.wide);
        // Order is preserved from the stored list.
        expect(widget.composedFill.itemIds, [
          'chess.rating',
          'wow_retail.profile',
        ]);
      },
    );

    test('unknown / garbage / duplicate item ids are dropped on read', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(
          _row(
            type: 'composed_card',
            platform: null,
            composed: {
              'items': [
                'chess.rating', // known → kept
                'chess.rating', // duplicate → dropped
                'not.a.real.id', // unknown → dropped
                42, // non-string → dropped
              ],
            },
          ),
        ),
      );

      expect(widget!.composedFill.itemIds, ['chess.rating']);
    });

    test('a non-object composed → empty fill', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(
          _row(type: 'composed_card', platform: null, composed: 'oops'),
        ),
      );

      expect(widget!.composedFill, ComposedFill.empty);
    });

    test('a composed with a non-list items → empty fill', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(
          _row(
            type: 'composed_card',
            platform: null,
            composed: {'items': 'oops'},
          ),
        ),
      );

      expect(widget!.composedFill, ComposedFill.empty);
    });

    test('a platform row carries an empty composed fill (no disturbance)', () {
      final widget = profileWidgetFromDto(
        ProfileWidgetDto.fromJson(
          _row(size: 'wide', dataMenuItems: ['steam.hours_played']),
        ),
      );

      expect(widget!.kind, ProfileWidgetKind.platform);
      expect(widget.composedFill, ComposedFill.empty);
    });

    test('composedFillFromSettings is lenient on a null envelope', () {
      expect(composedFillFromSettings(null), ComposedFill.empty);
    });

    test('merge writer preserves schema_version + size and sets the items', () {
      final merged = mergeComposedFillIntoSettings(
        ProfileWidgetSize.wide,
        const ComposedFill(['chess.rating', 'wow_retail.profile']),
      );

      expect(merged['schema_version'], kProfileWidgetSettingsVersion);
      expect(merged['size'], 'wide');
      final composed = merged['composed'] as Map<String, dynamic>;
      expect(composed['items'], ['chess.rating', 'wow_retail.profile']);
    });

    test('merge writer omits the composed key for an empty fill', () {
      final merged = mergeComposedFillIntoSettings(
        ProfileWidgetSize.small,
        ComposedFill.empty,
      );

      expect(merged['schema_version'], kProfileWidgetSettingsVersion);
      expect(merged['size'], 'small');
      expect(merged.containsKey('composed'), isFalse);
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
}
