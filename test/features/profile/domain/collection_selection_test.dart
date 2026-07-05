import 'package:featgg/src/features/profile/domain/collection_selection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CollectionSelection', () {
    test('empty is empty with no games and no title', () {
      expect(CollectionSelection.empty.isEmpty, isTrue);
      expect(CollectionSelection.empty.gameRefs, isEmpty);
      expect(CollectionSelection.empty.titleKey, isNull);
    });

    test('toggle adds an absent ref at the end', () {
      final sel = CollectionSelection.empty.toggle('730');
      expect(sel.isEmpty, isFalse);
      expect(sel.gameRefs, ['730']);
    });

    test('toggle removes a present ref', () {
      final sel = const CollectionSelection(
        gameRefs: ['730', '570'],
      ).toggle('730');
      expect(sel.gameRefs, ['570']);
    });

    test('toggle preserves add order', () {
      final sel = CollectionSelection.empty
          .toggle('730')
          .toggle('570')
          .toggle('440');
      expect(sel.gameRefs, ['730', '570', '440']);
    });

    test('toggling twice returns to the prior membership', () {
      final once = CollectionSelection.empty.toggle('730');
      final twice = once.toggle('730');
      expect(twice.gameRefs, isEmpty);
    });

    test('removing a middle ref keeps the order of the rest', () {
      final sel = const CollectionSelection(
        gameRefs: ['a', 'b', 'c'],
      ).toggle('b');
      expect(sel.gameRefs, ['a', 'c']);
    });

    test('toggle preserves the title key', () {
      final sel = const CollectionSelection(
        gameRefs: ['730'],
        titleKey: 'collectionTitleFavorites',
      ).toggle('570');
      expect(sel.titleKey, 'collectionTitleFavorites');
      expect(sel.gameRefs, ['730', '570']);
    });

    test('withTitle sets and clears the title key without touching games', () {
      final sel = const CollectionSelection(gameRefs: ['730']);
      final titled = sel.withTitle('collectionTitleBacklog');
      expect(titled.titleKey, 'collectionTitleBacklog');
      expect(titled.gameRefs, ['730']);
      expect(titled.withTitle(null).titleKey, isNull);
    });

    test('equality is by ordered game refs + title (Equatable)', () {
      expect(
        const CollectionSelection(gameRefs: ['a', 'b'], titleKey: 't'),
        const CollectionSelection(gameRefs: ['a', 'b'], titleKey: 't'),
      );
      expect(
        const CollectionSelection(gameRefs: ['a', 'b']),
        isNot(const CollectionSelection(gameRefs: ['b', 'a'])),
      );
    });
  });

  group('creation bounds', () {
    test('min is 3 and max is 5', () {
      expect(kCollectionMinGames, 3);
      expect(kCollectionMaxGames, 5);
    });
  });
}
