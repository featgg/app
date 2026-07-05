import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/collection_selection.dart';
import 'package:featgg/src/features/profile/domain/collection_value_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

SteamCardData _steam(List<LibraryShowcaseEntry> entries) =>
    SteamCardData(libraryShowcase: entries, recentGames: const []);

LibraryShowcaseEntry _entry(int appId, {String? hero}) => LibraryShowcaseEntry(
  appId: appId,
  title: 'Game $appId',
  hours: 100,
  heroImage: hero,
);

void main() {
  group('resolveCollection', () {
    test('resolves the selected games in stored order', () {
      final panels = resolveCollection(
        _steam([_entry(730), _entry(570), _entry(440)]),
        const CollectionSelection(gameRefs: ['570', '730', '440']),
      );

      expect(panels.map((p) => p.title), ['Game 570', 'Game 730', 'Game 440']);
    });

    test('passes through the per-game art url (null included)', () {
      final panels = resolveCollection(
        _steam([_entry(730, hero: 'https://cdn.example/730.jpg'), _entry(570)]),
        const CollectionSelection(gameRefs: ['730', '570']),
      );

      expect(panels[0].heroImage, 'https://cdn.example/730.jpg');
      expect(panels[1].heroImage, isNull);
    });

    test('skips a ref no longer in the library (rotated out)', () {
      final panels = resolveCollection(
        _steam([_entry(730), _entry(440)]),
        // 570 rotated out — only 730 and 440 resolve.
        const CollectionSelection(gameRefs: ['730', '570', '440']),
      );

      expect(panels.map((p) => p.title), ['Game 730', 'Game 440']);
    });

    test('caps at kCollectionMaxGames even when more resolve', () {
      final library = [for (var i = 1; i <= 7; i++) _entry(i)];
      final panels = resolveCollection(
        _steam(library),
        CollectionSelection(gameRefs: [for (var i = 1; i <= 7; i++) '$i']),
      );

      expect(panels, hasLength(kCollectionMaxGames));
      expect(panels.map((p) => p.title), [
        'Game 1',
        'Game 2',
        'Game 3',
        'Game 4',
        'Game 5',
      ]);
    });

    test('returns empty for null data', () {
      expect(
        resolveCollection(null, const CollectionSelection(gameRefs: ['730'])),
        isEmpty,
      );
    });

    test('returns empty for an empty selection', () {
      expect(
        resolveCollection(_steam([_entry(730)]), CollectionSelection.empty),
        isEmpty,
      );
    });

    test('returns empty when no referenced game matches', () {
      expect(
        resolveCollection(
          _steam([_entry(730)]),
          const CollectionSelection(gameRefs: ['999', '888']),
        ),
        isEmpty,
      );
    });
  });
}
