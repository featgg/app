import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/profile/domain/data_menu_catalog.dart';
import 'package:featgg/src/features/profile/presentation/data_menu_labels.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The stable stat keys frozen in `docs/integration/feed.md` § Per-platform
/// data and stats (v1) — mirrored here so a catalog pointer that drifts from
/// the contract fails. `StatPointer`s with a `dataPath` (scalars that live only
/// in the `data` block, e.g. league `rank`, wow `profile`) are not `stats`
/// keys and are excluded from this set.
const _knownStatKeys = {
  'hours_played',
  'games_owned',
  'rating',
  'followers',
  'network_level',
  'bedwars_wins',
  'total_achievement_points',
  'item_level',
  'achievement_points',
  'mythic_plus_rating',
  'summoner_level',
  'wvw_rank',
  'fractal_level',
  'total_ap',
  'veterancy_years',
};

/// Showcase list fields frozen in feed.md `widget_data.data`.
const _knownShowcaseFields = {'library_showcase', 'top_mastery'};

void main() {
  group('dataMenuCatalog — well-formedness (iterates, no per-item case)', () {
    test('the catalog is non-empty', () {
      expect(dataMenuCatalog, isNotEmpty);
    });

    test('every item has a unique, non-empty id', () {
      final ids = dataMenuCatalog.map((i) => i.id).toList();
      expect(ids.toSet(), hasLength(ids.length), reason: 'duplicate id');
      for (final id in ids) {
        expect(id, isNotEmpty);
      }
    });

    test('every item has a category, label key, value type, and a real '
        'platform pointer', () {
      for (final item in dataMenuCatalog) {
        expect(
          DataMenuCategory.values,
          contains(item.category),
          reason: item.id,
        );
        expect(
          DataMenuValueType.values,
          contains(item.valueType),
          reason: item.id,
        );
        expect(item.labelKey, isNotEmpty, reason: item.id);
        expect(Platform.values, contains(item.platform), reason: item.id);
        expect(item.pointer.platform, item.platform, reason: item.id);
      }
    });

    test('every pointer names a non-empty path/key', () {
      for (final item in dataMenuCatalog) {
        switch (item.pointer) {
          case StatPointer(:final statKey, :final dataPath):
            expect(statKey, isNotEmpty, reason: item.id);
            if (dataPath != null) {
              expect(dataPath, isNotEmpty, reason: item.id);
            }
          case ShowcasePointer(:final dataField, :final topN):
            expect(dataField, isNotEmpty, reason: item.id);
            expect(topN, greaterThan(0), reason: item.id);
        }
      }
    });
  });

  group('dataMenuCatalog — pointers match the frozen feed.md contract', () {
    test('every envelope StatPointer key is a known feed.md stat token', () {
      // Only `stats` keys (dataPath == null) are constrained to the stats
      // token set; data-block scalars are validated by their non-empty path
      // above and are not part of the `stats` inventory.
      final statKeys = {
        for (final item in dataMenuCatalog)
          if (item.pointer case StatPointer(:final statKey, dataPath: null))
            statKey,
      };
      expect(
        statKeys.difference(_knownStatKeys),
        isEmpty,
        reason: 'a StatPointer key is not in the frozen feed.md stats set',
      );
    });

    test('every showcase field is a known feed.md data list field', () {
      final fields = {
        for (final item in dataMenuCatalog)
          if (item.pointer case ShowcasePointer(:final dataField))
            dataField.last,
      };
      expect(
        fields.difference(_knownShowcaseFields),
        isEmpty,
        reason: 'a ShowcasePointer field is not in the frozen feed.md set',
      );
    });
  });

  group('label resolver totality', () {
    late AppLocalizations l10n;

    setUpAll(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('every catalog label key resolves to a non-empty string', () {
      for (final item in dataMenuCatalog) {
        final label = dataMenuItemLabel(l10n, item.labelKey);
        expect(label, isNotNull, reason: item.id);
        expect(label, isNotEmpty, reason: item.id);
      }
    });

    test('every category resolves to a non-empty heading', () {
      for (final category in DataMenuCategory.values) {
        expect(
          dataMenuCategoryLabel(l10n, category),
          isNotEmpty,
          reason: category.name,
        );
      }
    });
  });
}
