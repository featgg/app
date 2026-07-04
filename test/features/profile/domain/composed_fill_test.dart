import 'package:featgg/src/features/profile/domain/composed_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ComposedFill', () {
    test('empty is empty and contains nothing', () {
      expect(ComposedFill.empty.isEmpty, isTrue);
      expect(ComposedFill.empty.itemIds, isEmpty);
      expect(ComposedFill.empty.contains('chess.rating'), isFalse);
    });

    test('toggle adds an absent id at the end', () {
      final fill = ComposedFill.empty.toggle('chess.rating');
      expect(fill.isEmpty, isFalse);
      expect(fill.contains('chess.rating'), isTrue);
      expect(fill.itemIds, ['chess.rating']);
    });

    test('toggle removes a present id', () {
      final fill = const ComposedFill([
        'chess.rating',
        'wow_retail.profile',
      ]).toggle('chess.rating');
      expect(fill.contains('chess.rating'), isFalse);
      expect(fill.itemIds, ['wow_retail.profile']);
    });

    test('toggle preserves pick order when adding', () {
      final fill = ComposedFill.empty
          .toggle('chess.rating')
          .toggle('wow_retail.profile')
          .toggle('steam.hours_played');
      expect(fill.itemIds, [
        'chess.rating',
        'wow_retail.profile',
        'steam.hours_played',
      ]);
    });

    test('toggling twice returns to the prior membership', () {
      final once = ComposedFill.empty.toggle('chess.rating');
      final twice = once.toggle('chess.rating');
      expect(twice.contains('chess.rating'), isFalse);
      expect(twice.itemIds, isEmpty);
    });

    test('removing a middle id keeps the order of the rest', () {
      final fill = const ComposedFill(['a', 'b', 'c']).toggle('b');
      expect(fill.itemIds, ['a', 'c']);
    });

    test('equality is by ordered item ids (Equatable)', () {
      expect(const ComposedFill(['a', 'b']), const ComposedFill(['a', 'b']));
      // Order is significant — a different order is not equal.
      expect(
        const ComposedFill(['a', 'b']),
        isNot(const ComposedFill(['b', 'a'])),
      );
    });
  });
}
